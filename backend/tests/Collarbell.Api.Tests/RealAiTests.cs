using System.Text.Encodings.Web;
using System.Text.Json;
using Collarbell.Api.Modules.Ai;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Pets;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;
using SkiaSharp;

namespace Collarbell.Api.Tests;

/// <summary>
/// The regression set (spec 5.5), read by the real Gemini models: synthetic pages drawn here, and photos of real
/// passports and chip stickers kept on this Mac only (tests/ai-samples, see its README: they show personal data, so
/// not in git). They need the key in the AppHost's user secrets and run only on request, so a normal test run stays
/// offline:
/// <code>COLLARBELL_REAL_AI=1 dotnet test -- --filter-trait "Category=RealAi"</code>
/// Run them after changing a prompt (<see cref="PassportScanPrompt.Version"/>, <see cref="IdentifierScanPrompt.Version"/>)
/// or the models.
/// </summary>
[Trait("Category", "RealAi")]
public sealed class RealAiTests
{
    private const string AppHostUserSecretsId = "415c6505-9355-4c9f-9e87-3b8dabfb7e8c";

    /// <summary>The folder in tests/ai-samples with photos for the chip scan; not a passport scan of its own.</summary>
    private const string ChipSamples = "chips";

    private static readonly string[] Models = ["gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.5-flash-lite"];
    private static readonly DateOnly Today = DateOnly.FromDateTime(DateTime.UtcNow);
    private static readonly SavedPetData Nothing = new([], new HashSet<string>(), null, null, null);

    /// <summary>For draft.json: indented, and Cyrillic left readable.</summary>
    private static readonly JsonSerializerOptions Readable = new(AiRunner.Json)
    {
        WriteIndented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    [Fact]
    public async Task Section_V_rabies_vaccination()
    {
        var draft = await ReadPageAsync(
            "V. VACCINATION AGAINST RABIES",
            "Manufacturer and name of vaccine: Nobivac Rabies, MSD",
            "Batch number: A123B45",
            "Date of vaccination: 12/03/2025",
            "Valid from: 02/04/2025   Valid until: 11/03/2028",
            "Authorised veterinarian: Dr. K. Weber, Berlin");

        var record = Assert.Single(draft.Records);
        Assert.Equal(CareKind.Vaccination, record.Kind);
        Assert.Contains(VaccineTarget.Rabies, record.Targets);
        Assert.Equal(new DateOnly(2025, 3, 12), record.PerformedOn); // day first, as in EU passports
        Assert.Equal(new DateOnly(2028, 3, 11), record.ValidUntil);
        Assert.Equal("A123B45", record.BatchNumber);
        Assert.Contains(new DraftWarning("performedOn", DraftIssue.Ambiguous), record.Warnings); // 12/03 could swap
    }

    [Fact]
    public async Task Section_VIII_deworming()
    {
        var draft = await ReadPageAsync(
            "VIII. ANTI-PARASITE TREATMENT",
            "Name of product: Milbemax, Elanco",
            "Date: 15.05.2025",
            "Veterinarian: Dr. K. Weber");

        var record = Assert.Single(draft.Records);
        Assert.Equal(CareKind.Deworming, record.Kind);
        Assert.Equal(new DateOnly(2025, 5, 15), record.PerformedOn);
        Assert.Contains("Milbemax", record.Product, StringComparison.OrdinalIgnoreCase);
        Assert.Empty(record.Warnings);
    }

    [Fact]
    public async Task A_russian_page()
    {
        var draft = await ReadPageAsync(
            "Вакцинация против бешенства",
            "Вакцина: Нобивак Рабиес",
            "Серия: 123456",
            "Дата вакцинации: 20.06.2025",
            "Действительна до: 19.06.2026",
            "Ветврач: Иванова А. С.");

        var record = Assert.Single(draft.Records);
        Assert.Equal(CareKind.Vaccination, record.Kind);
        Assert.Contains(VaccineTarget.Rabies, record.Targets);
        Assert.Equal(new DateOnly(2025, 6, 20), record.PerformedOn);
        Assert.Equal(new DateOnly(2026, 6, 19), record.ValidUntil);
    }

    [Fact]
    public async Task Titles_come_in_the_users_language()
    {
        var page = Page([
            "V. VACCINATION AGAINST RABIES",
            "Manufacturer and name of vaccine: Nobivac Rabies, MSD",
            "Date of vaccination: 12/03/2025   Valid until: 11/03/2028",
        ]);
        var draft = (await ReadAsync([(page, "image/jpeg")], AiImportSource.PassportPages, locale: "ru")).Draft;

        var title = Assert.Single(draft.Records).Title;
        Assert.NotNull(title);
        Assert.Matches("[А-Яа-яЁё]", title);
    }

    [Fact]
    public async Task Section_III_microchip()
    {
        var draft = await ReadPageAsync(
            "III. IDENTIFICATION OF THE ANIMAL",
            "Transponder alphanumeric code: 276098100123456",
            "Date of application: 14/08/2021",
            "Location of the transponder: left side of the neck");

        var chip = Assert.Single(draft.Identifiers);
        Assert.Equal(IdentifierType.IsoChip, chip.Type);
        Assert.Equal("276098100123456", chip.Code);
        Assert.True(chip.Selected);
    }

    [Fact]
    public async Task A_vet_certificate()
    {
        var draft = await ReadPageAsync(AiImportSource.VetDocument,
            "CERTIFICATE OF VACCINATION — Tierarztpraxis Weber, Berlin",
            "Patient: Murka, cat, microchip 276098100123456",
            "Vaccine: Purevax RCP (Boehringer Ingelheim), lot L4521",
            "Given on 05/06/2025, next booster due 05/06/2026",
            "Signed: Dr. K. Weber");

        var record = Assert.Single(draft.Records);
        Assert.Equal(CareKind.Vaccination, record.Kind);
        Assert.Equal(new DateOnly(2025, 6, 5), record.PerformedOn);
        Assert.Contains("Purevax", record.Product, StringComparison.OrdinalIgnoreCase);
        Assert.Equal("276098100123456", Assert.Single(draft.Identifiers).Code);
        Assert.Null(draft.Passport);
    }

    [Fact]
    public async Task A_vet_report_notes_the_weight_on_the_check_up()
    {
        var draft = await ReadPageAsync(AiImportSource.VetDocument,
            "Tierarztpraxis Weber, Berlin — Treatment report",
            "Patient: Murka, cat",
            "12/08/2025  General examination: healthy, fit to travel.",
            "Body weight: 4.3 kg",
            "Dr. K. Weber");

        var record = Assert.Single(draft.Records);
        Assert.Equal(CareKind.VetExam, record.Kind);
        Assert.Equal(new DateOnly(2025, 8, 12), record.PerformedOn);
        Assert.Equal(4.3m, record.WeightKg);
    }

    [Fact]
    public async Task A_weight_in_pounds_at_a_check_up_is_read_in_kilograms()
    {
        var draft = await ReadPageAsync(AiImportSource.VetDocument,
            "Riverside Animal Hospital — Invoice",
            "Patient: Rex, dog. Date: 2025-06-05",
            "Wellness exam ........ $60.00",
            "Weight: 22 lb",
            "Thank you for your visit!");

        var checkUp = Assert.Single(draft.Records);
        Assert.Equal(CareKind.VetExam, checkUp.Kind);
        Assert.InRange(checkUp.WeightKg ?? 0, 9.9m, 10.0m); // 22 lb = 9.98 kg
        Assert.Equal(new DateOnly(2025, 6, 5), checkUp.PerformedOn);
    }

    /// <summary>
    /// A weight without an examination is left out: a check-up made up to carry it would count as the "Done" of the
    /// pet's annual check-up plan and move it a year on (found by the review of the weight log).
    /// </summary>
    [Fact]
    public async Task A_weight_at_a_vaccination_doesnt_make_up_a_check_up()
    {
        var draft = await ReadPageAsync(AiImportSource.VetDocument,
            "Riverside Animal Hospital — Invoice",
            "Patient: Rex, dog. Date: 2025-06-05",
            "Vaccine DHPP (Nobivac), lot 88123 ........ $45.00",
            "Weight: 22 lb",
            "Thank you for your visit!");

        var vaccination = Assert.Single(draft.Records);
        Assert.Equal(CareKind.Vaccination, vaccination.Kind);
        Assert.Null(vaccination.WeightKg);
        // The weight becomes a weighing of the log instead.
        var weight = Assert.Single(draft.Weights);
        Assert.InRange(weight.WeightKg ?? 0, 9.9m, 10.0m);
        Assert.Equal(new DateOnly(2025, 6, 5), weight.MeasuredOn);
    }

    /// <summary>A Wednesday: "yesterday" and "on Monday" have one right answer.</summary>
    private static readonly DateOnly NoteDay = new(2026, 10, 7);

    [Fact]
    public async Task A_note_in_russian_with_yesterday_and_a_weight()
    {
        var draft = await ReadNoteAsync("ru", "Мурка", Species.Cat, "вчера сделали прививку от бешенства, нобивак. весит 4,2 кг");

        var record = Assert.Single(draft.Records);
        Assert.Equal(CareKind.Vaccination, record.Kind);
        Assert.Contains(VaccineTarget.Rabies, record.Targets);
        Assert.Equal(NoteDay.AddDays(-1), record.PerformedOn);
        var weight = Assert.Single(draft.Weights);
        Assert.Equal(4.2m, weight.WeightKg);
        // "Весит" right after yesterday's visit: today, or weighed at that visit. Either reads the note fairly; the
        // user sees the date before saving.
        Assert.Contains(weight.MeasuredOn, new DateOnly?[] { NoteDay, NoteDay.AddDays(-1) });
    }

    [Fact]
    public async Task A_note_with_a_weekday_and_a_plan_for_later()
    {
        var draft = await ReadNoteAsync("en", "Rex", Species.Dog,
            "Gave Rex his Milbemax on Monday. Next vet visit is in two weeks, and Luna the cat needs one too.");

        var record = Assert.Single(draft.Records);
        Assert.Equal(CareKind.Deworming, record.Kind);
        Assert.Equal(new DateOnly(2026, 10, 5), record.PerformedOn);
        Assert.Empty(draft.Weights);
    }

    /// <summary>
    /// Each folder in tests/ai-samples is one scan: its photos are read as the app reads them, the result is kept
    /// in draft.json, and compared with expected.json once the user has checked one against the paper.
    /// </summary>
    [Fact]
    public async Task Real_passport_photos_read_as_expected()
    {
        var samples = SamplesFolder();
        var scans = samples is null ? [] : Directory.GetDirectories(samples).Where(d => Path.GetFileName(d) != ChipSamples).Order().ToList();
        Assert.SkipWhen(scans.Count == 0, "No photos in tests/ai-samples yet (see its README).");

        var report = new List<string> { $"# AI regression: {PassportScanPrompt.Version}, {DateTime.Now:yyyy-MM-dd HH:mm}, thinking: {ThinkingName}", "" };
        var spent = new List<Spend>();
        var failed = 0;
        foreach (var scan in scans)
        {
            var name = Path.GetFileName(scan);
            // The same preparation as an upload: turned upright, at most 2048 px, JPEG.
            var photos = Directory.GetFiles(scan)
                .Where(IsPhoto)
                .Order()
                .Select(f => FilePreparation.Prepare(File.ReadAllBytes(f)))
                .OfType<PreparedFile>()
                .Select(p => (p.Content, p.ContentType))
                .ToList();
            if (photos.Count == 0)
            {
                continue;
            }

            var (draft, model, spend) = await ReadAsync(photos, AiImportSource.PassportPages);
            spent.Add(spend);
            await File.WriteAllTextAsync(Path.Combine(scan, "draft.json"), JsonSerializer.Serialize(draft, Readable), Ct);
            var expectedFile = Path.Combine(scan, "expected.json");
            if (!File.Exists(expectedFile))
            {
                report.Add($"- **{name}** ({model}, {spend}): no expected.json yet. Check draft.json against the paper and save it as expected.json.");
                continue;
            }

            var expected = JsonSerializer.Deserialize<ImportDraft>(await File.ReadAllTextAsync(expectedFile, Ct), AiRunner.Json)!;
            var problems = Compare(expected, draft);
            failed += problems.Count > 0 ? 1 : 0;
            report.Add(problems.Count == 0
                ? $"- **{name}** ({model}, {spend}): as expected."
                : $"- **{name}** ({model}, {spend}):\n" + string.Join("\n", problems.Select(p => $"  - {p}")));
        }

        report.AddRange(["", $"All: {Spend.Total(spent)}"]);
        await File.WriteAllLinesAsync(Path.Combine(samples!, "report.md"), report, Ct);
        Assert.True(failed == 0, string.Join("\n", report));
    }

    /// <summary>
    /// Photos in tests/ai-samples/chips, each named after the microchip number on it: <c>643094100000001.jpg</c>.
    /// The chip scan must read that number; what it read, the place and the date included, is kept next to the photo
    /// (<c>643094100000001.json</c>) to check against the paper.
    /// </summary>
    [Fact]
    public async Task Chip_photos_give_the_number_they_are_named_after()
    {
        var folder = SamplesFolder() is { } samples ? Path.Combine(samples, ChipSamples) : null;
        var photos = folder is not null && Directory.Exists(folder) ? Directory.GetFiles(folder).Where(IsPhoto).Order().ToList() : [];
        Assert.SkipWhen(photos.Count == 0, "No chip photos in tests/ai-samples/chips yet (see its README).");

        var missed = new List<string>();
        var report = new List<string> { $"# Chip scan: {IdentifierScanPrompt.Version}, {DateTime.Now:yyyy-MM-dd HH:mm}, thinking: {ThinkingName}", "" };
        var spent = new List<Spend>();
        foreach (var photo in photos)
        {
            // The same preparation as an upload: turned upright, at most 2048 px, JPEG.
            if (FilePreparation.Prepare(File.ReadAllBytes(photo)) is not { } prepared)
            {
                continue;
            }

            var (scan, model, spend) = await AskAsync<IdentifierScan>(IdentifierScanPrompt.Text, [(prepared.Content, prepared.ContentType)]);
            spent.Add(spend);
            var readings = IdentifierReadings.From(scan, Today);
            await File.WriteAllTextAsync(Path.ChangeExtension(photo, ".json"), JsonSerializer.Serialize(new { model, readings }, Readable), Ct);
            var number = Path.GetFileNameWithoutExtension(photo);
            var read = readings.Any(r => r.Code == number);
            if (!read)
            {
                missed.Add($"{number} ({model}): read {string.Join(", ", readings.Select(r => r.Code))}");
            }

            report.Add($"- **{number}** ({model}, {spend}): {(read ? "read" : "missed")}.");
        }

        report.AddRange(["", $"All: {Spend.Total(spent)}"]);
        await File.WriteAllLinesAsync(Path.Combine(folder!, "report.md"), report, Ct);
        Assert.True(missed.Count == 0, string.Join("\n", missed));
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private static bool IsPhoto(string path) => Path.GetExtension(path).ToLowerInvariant() is ".jpg" or ".jpeg" or ".png" or ".webp";

    /// <summary>Draws the lines as a passport page and reads it.</summary>
    private static Task<ImportDraft> ReadPageAsync(params string[] lines) => ReadPageAsync(AiImportSource.PassportPages, lines);

    /// <summary>Reads a note like the app's "write it in words", on <see cref="NoteDay"/>.</summary>
    private static async Task<ImportDraft> ReadNoteAsync(string locale, string petName, Species species, string text)
    {
        var (scan, _, _) = await AskAsync<PassportScan>(TextEntryPrompt.For(locale, NoteDay, petName, species, text), []);
        return ImportDrafts.Build(scan, Nothing, NoteDay);
    }

    private static async Task<ImportDraft> ReadPageAsync(AiImportSource source, params string[] lines) =>
        (await ReadAsync([(Page(lines), "image/jpeg")], source)).Draft;

    /// <summary>Reads the photos like the app: the same prompt, time limit and "try the next model" rule.</summary>
    private static async Task<(ImportDraft Draft, string Model, Spend Spend)> ReadAsync(
        List<(byte[] Content, string ContentType)> photos, AiImportSource source, string locale = "en")
    {
        var (scan, model, spend) = await AskAsync<PassportScan>(PassportScanPrompt.For(locale, source), photos);
        return (ImportDrafts.Build(scan, Nothing, Today), model, spend);
    }

    /// <summary>
    /// How much the models think, as the setting <c>Ai:Thinking</c> would make them: <c>COLLARBELL_AI_THINKING=Low</c>
    /// (or Medium, High). Unset leaves it to each model, as the app does today.
    /// </summary>
    private static ReasoningEffort? Thinking =>
        Environment.GetEnvironmentVariable("COLLARBELL_AI_THINKING") is { Length: > 0 } level ? Enum.Parse<ReasoningEffort>(level, ignoreCase: true) : null;

    private static string ThinkingName => Thinking?.ToString() ?? "model default";

    /// <summary>Asks the models in turn for an answer of <typeparamref name="T"/>'s schema, with the app's time limit.</summary>
    private static async Task<(T Answer, string Model, Spend Spend)> AskAsync<T>(string prompt, List<(byte[] Content, string ContentType)> photos)
    {
        var key = new ConfigurationBuilder().AddUserSecrets(AppHostUserSecretsId).Build()["Parameters:gemini-api-key"];
        Assert.SkipWhen(Environment.GetEnvironmentVariable("COLLARBELL_REAL_AI") != "1", "Set COLLARBELL_REAL_AI=1 to call the real models.");
        Assert.SkipWhen(string.IsNullOrWhiteSpace(key), "No Gemini key in the AppHost user secrets.");

        var options = new AiOptions { Gemini = { ApiKey = key }, Thinking = Thinking };
        var factory = new AiChatClientFactory(Options.Create(options));
        ChatMessage[] messages =
        [
            new(ChatRole.User,
            [
                new TextContent(prompt),
                .. photos.Select(p => (AIContent)new DataContent(p.Content, p.ContentType)),
            ]),
        ];
        var problems = new List<string>();
        foreach (var model in Models)
        {
            using var attempt = CancellationTokenSource.CreateLinkedTokenSource(Ct);
            attempt.CancelAfter(AiRunner.AttemptTimeout(options, messages));
            try
            {
                var modelRef = new AiModelRef { Provider = AiProvider.Gemini, Model = model };
                var response = await factory.Create(modelRef)
                    .GetResponseAsync<T>(messages, AiRunner.Json, AiRunner.ChatOptionsFor(options), cancellationToken: attempt.Token);
                if (response.TryGetResult(out var answer) && answer is not null)
                {
                    var usage = new AiUsage(Guid.Empty, "regression", modelRef, DateTimeOffset.UtcNow);
                    usage.Count(response.Usage);
                    var spend = new Spend(photos.Count, usage.InputTokens ?? 0, usage.OutputTokens ?? 0, usage.ReasoningTokens ?? 0);
                    var line = $"- {DateTime.Now:yyyy-MM-dd HH:mm} {TestContext.Current.TestMethod?.MethodName}, {model}, thinking {ThinkingName}: {spend}";
                    if (SamplesFolder() is { } samples)
                    {
                        await File.AppendAllLinesAsync(Path.Combine(samples, "spend.md"), [line], Ct);
                    }

                    return (answer, model, spend);
                }

                problems.Add($"{model}: no usable answer");
            }
            catch (Exception e) when (e is OperationCanceledException || AiRunner.WorthTryingTheNextModel(e))
            {
                problems.Add($"{model}: {e.Message}");
            }
        }

        throw new InvalidOperationException("No model answered: " + string.Join("; ", problems));
    }

    /// <summary>
    /// What one answer used, and its price on the paid gemini-3.8-flash from 2027: $1.50 per million tokens in and $7.50
    /// out, thinking included (product-research, "LLM providers"). Other models cost less, so this is the ceiling.
    /// </summary>
    private sealed record Spend(int Photos, long Input, long Output, long Thinking)
    {
        public decimal Dollars => ((Input * 1.50m) + (Output * 7.50m)) / 1_000_000m;

        public static Spend Total(IReadOnlyCollection<Spend> all) =>
            new(all.Sum(s => s.Photos), all.Sum(s => s.Input), all.Sum(s => s.Output), all.Sum(s => s.Thinking));

        public override string ToString() =>
            $"{Photos} photo(s), {Input} tokens in, {Output} out of which {Thinking} thinking, " +
            $"${Dollars:0.0000}, ${Dollars / Math.Max(Photos, 1):0.0000} a photo";
    }

    /// <summary>What differs from the checked result. Fields left out of expected.json aren't checked.</summary>
    private static List<string> Compare(ImportDraft expected, ImportDraft actual)
    {
        var problems = new List<string>();
        var unmatched = actual.Records.ToList();
        foreach (var want in expected.Records ?? [])
        {
            var label = $"{want.Kind} {want.PerformedOn:yyyy-MM-dd}";
            var got = unmatched.FirstOrDefault(r => r.Kind == want.Kind && r.PerformedOn == want.PerformedOn);
            if (got is null)
            {
                problems.Add($"missing {label}");
                continue;
            }

            unmatched.Remove(got);
            Check(problems, label, "product", want.Product, got.Product);
            Check(problems, label, "batchNumber", want.BatchNumber, got.BatchNumber);
            Check(problems, label, "validFrom", want.ValidFrom, got.ValidFrom);
            Check(problems, label, "validUntil", want.ValidUntil, got.ValidUntil);
            if (want.Targets is { Count: > 0 } targets && !targets.ToHashSet().SetEquals(got.Targets))
            {
                problems.Add($"{label}: targets {string.Join(", ", got.Targets)} instead of {string.Join(", ", targets)}");
            }
        }

        problems.AddRange(unmatched.Select(r => $"extra {r.Kind} {r.PerformedOn:yyyy-MM-dd} ({r.Product})"));

        var codes = actual.Identifiers.Select(i => i.Code).ToHashSet();
        foreach (var want in expected.Identifiers ?? [])
        {
            if (!codes.Remove(want.Code))
            {
                problems.Add($"missing identifier {want.Code}");
            }
        }

        problems.AddRange(codes.Select(c => $"extra identifier {c}"));

        if (expected.Passport is { } passport)
        {
            Check(problems, "passport", "number", passport.PassportNumber, actual.Passport?.PassportNumber);
            Check(problems, "passport", "country", passport.IssuingCountry, actual.Passport?.IssuingCountry);
            Check(problems, "passport", "issuedOn", passport.IssuedOn, actual.Passport?.IssuedOn);
        }

        return problems;
    }

    /// <summary>Text is compared by letters and digits only: "Nobivac® Rabies" is "NOBIVAC RABIES".</summary>
    private static void Check(List<string> problems, string label, string field, string? want, string? got)
    {
        static string Letters(string? text) => string.Concat((text ?? "").Where(char.IsLetterOrDigit)).ToUpperInvariant();
        if (want is not null && Letters(want) != Letters(got))
        {
            problems.Add($"{label}: {field} \"{got}\" instead of \"{want}\"");
        }
    }

    private static void Check(List<string> problems, string label, string field, DateOnly? want, DateOnly? got)
    {
        if (want is not null && want != got)
        {
            problems.Add($"{label}: {field} {got:yyyy-MM-dd} instead of {want:yyyy-MM-dd}");
        }
    }

    /// <summary>backend/tests/ai-samples, found from the test's bin folder.</summary>
    private static string? SamplesFolder()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
        {
            if (File.Exists(Path.Combine(dir.FullName, "Collarbell.slnx")))
            {
                var samples = Path.Combine(dir.FullName, "tests", "ai-samples");
                return Directory.Exists(samples) ? samples : null;
            }
        }

        return null;
    }

    private static byte[] Page(string[] lines)
    {
        using var bitmap = new SKBitmap(1400, 220 + (lines.Length * 90));
        using (var canvas = new SKCanvas(bitmap))
        {
            canvas.Clear(new SKColor(0xF4, 0xEF, 0xE1)); // passport paper
            using var font = new SKFont(SKTypeface.Default, 36);
            using var paint = new SKPaint { Color = new SKColor(0x22, 0x22, 0x55), IsAntialias = true };
            for (var i = 0; i < lines.Length; i++)
            {
                canvas.DrawText(lines[i], 60, 120 + (i * 90), SKTextAlign.Left, font, paint);
            }
        }

        using var image = SKImage.FromBitmap(bitmap);
        using var jpeg = image.Encode(SKEncodedImageFormat.Jpeg, 85);
        return jpeg.ToArray();
    }
}
