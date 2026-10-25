using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Modules.Ai;
using Collarbell.Api.Modules.Billing;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Pets;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>
/// "Write it in words" (spec, "Быстрый ввод текстом"): a note about a pet, read by AI into the same draft as a scan, saved
/// the same way; its weights become weighings.
/// </summary>
[Collection(ApiCollection.Name)]
public sealed class NoteImportsTests : IDisposable
{
    private readonly ApiFactory _api;

    public NoteImportsTests(ApiFactory api)
    {
        _api = api;
        _api.Ai.Reset();
    }

    public void Dispose() => _api.Ai.Reset();

    private static string Iso(DateOnly date) => date.ToString("yyyy-MM-dd");

    /// <summary>What the model makes of "yesterday the rabies shot, Nobivac; she weighs 4.2 kg".</summary>
    private static string NoteAnswer() => $$"""
        {
          "records": [
            { "kind": "Vaccination", "title": "Прививка от бешенства",
              "performedOn": { "raw": "вчера", "iso": "{{Iso(Today.AddDays(-1))}}", "order": "YearMonthDay" },
              "performedTime": null, "product": "Nobivac Rabies", "manufacturer": null, "batchNumber": null,
              "validFrom": null, "validUntil": null, "targets": ["Rabies"], "veterinarian": null, "clinic": null,
              "weightKg": null, "evidence": "вчера прививка от бешенства, нобивак", "page": 1 }
          ],
          "identifiers": [],
          "passport": null,
          "weights": [
            { "measuredOn": { "raw": null, "iso": "{{Iso(Today)}}", "order": "YearMonthDay" }, "weightKg": 4.2,
              "evidence": "весит 4,2", "page": 1 }
          ]
        }
        """;

    private static Task<HttpResponseMessage> WriteAsync(HttpClient client, Guid petId, string? text, List<Guid>? fileIds = null) =>
        client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(petId, AiImportSource.Text, fileIds ?? [], Guid.NewGuid(), text), Json, Ct);

    /// <summary>Polls like the app does, until the background worker has finished.</summary>
    private static async Task<AiImportResponse> WaitUntilDoneAsync(HttpClient client, Guid importId)
    {
        for (var i = 0; i < 100; i++)
        {
            var import = (await client.GetFromJsonAsync<AiImportResponse>($"/api/v1/ai-imports/{importId}", Json, Ct))!;
            if (import.Status is not (AiImportStatus.Queued or AiImportStatus.Processing))
            {
                return import;
            }

            await Task.Delay(100, Ct);
        }

        throw new TimeoutException("The import didn't finish.");
    }

    private static async Task<AiImportResponse> GetAsync(HttpClient client, Guid id) =>
        (await client.GetFromJsonAsync<AiImportResponse>($"/api/v1/ai-imports/{id}", Json, Ct))!;

    private static async Task<IEnumerable<string>> ErrorFieldsAsync(HttpResponseMessage response)
    {
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<ValidationProblemDetails>(Json, Ct))!.Errors.Keys;
    }

    [Fact]
    public async Task A_note_becomes_a_draft_and_its_weight_a_weighing()
    {
        var client = _api.ClientFor($"note-{Guid.NewGuid():N}");
        var murka = await client.CreatePetAsync("Murka");
        _api.Ai.Answer = _ => NoteAnswer();

        var started = await WriteAsync(client, murka.Id, "  вчера прививка от бешенства, нобивак; весит 4,2  ");

        Assert.Equal(HttpStatusCode.Accepted, started.StatusCode);
        var import = (await started.Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!;
        Assert.Equal((AiImportSource.Text, "вчера прививка от бешенства, нобивак; весит 4,2"), (import.Source, import.Text));
        Assert.Empty(import.Pages);
        var ready = await WaitUntilDoneAsync(client, import.Id);
        Assert.Equal(AiImportStatus.Ready, ready.Status);

        // The model was told whose note it is and which day "yesterday" is counted from.
        var prompt = Assert.Single(_api.Ai.Prompts, p => p.Contains("весит 4,2", StringComparison.Ordinal));
        Assert.Contains("cat named \"Murka\"", prompt, StringComparison.Ordinal);
        Assert.Contains($"Today is {Iso(Today)}", prompt, StringComparison.Ordinal);
        Assert.Contains("весит 4,2", prompt, StringComparison.Ordinal);

        var record = Assert.Single(ready.Draft!.Records);
        Assert.Equal((CareKind.Vaccination, Today.AddDays(-1), true), (record.Kind, record.PerformedOn, record.Selected));
        var weight = Assert.Single(ready.Draft.Weights);
        Assert.Equal((Today, 4.2m, true), (weight.MeasuredOn, weight.WeightKg, weight.Selected));

        var applied = await client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply", new ApplyImportRequest(
            [new ImportedRecordRequest(Record(record.Title!, record.Kind, record.PerformedOn!.Value) with
            {
                Product = record.Product,
                Targets = record.Targets,
            }, PlanId: null)],
            Identifiers: null,
            Passport: null,
            KeepPhotos: true, // a note has none: nothing to keep
            Weights: [new ImportedWeightRequest(weight.MeasuredOn!.Value, weight.WeightKg!.Value)]), Json, Ct);

        Assert.Equal(HttpStatusCode.OK, applied.StatusCode);
        var result = (await applied.Content.ReadFromJsonAsync<ApplyImportResponse>(Json, Ct))!;
        Assert.Equal((1, 1, (Guid?)null), (result.RecordIds.Count, result.WeightsAdded, result.DocumentId));
        var log = (await client.GetFromJsonAsync<List<WeightResponse>>($"/api/v1/pets/{murka.Id}/weights", Json, Ct))!;
        Assert.Equal((WeightSource.Weighing, Today, 4.2m), (log[0].Source, log[0].MeasuredOn, log[0].WeightKg));
        // The weighing is in the log now: the draft read again shows it as saved.
        var again = (await client.GetFromJsonAsync<AiImportResponse>($"/api/v1/ai-imports/{import.Id}", Json, Ct))!;
        Assert.Equal(AiImportStatus.Applied, again.Status);
    }

    [Fact]
    public async Task A_note_is_checked()
    {
        var client = _api.ClientFor($"note-check-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var photo = await client.UploadPhotoAsync();

        Assert.Equal(["text"], await ErrorFieldsAsync(await WriteAsync(client, pet.Id, "   ")));
        Assert.Equal(["text"], await ErrorFieldsAsync(await WriteAsync(client, pet.Id, new string('a', 1001))));
        Assert.Equal(["fileIds"], await ErrorFieldsAsync(await WriteAsync(client, pet.Id, "вчера прививка", [photo.Id])));
        Assert.Equal(HttpStatusCode.NotFound, (await WriteAsync(client, Guid.NewGuid(), "вчера прививка")).StatusCode);
    }

    /// <summary>Notes the person had read: charged holds of no photos, <paramref name="hoursAgo"/> ago.</summary>
    private async Task SeedNotesAsync(Guid householdId, Guid userId, int count, double hoursAgo = 1, bool read = true)
    {
        await _api.ChangeDatabaseAsync(async db =>
        {
            for (var i = 0; i < count; i++)
            {
                var at = DateTimeOffset.UtcNow.AddHours(-hoursAgo);
                var hold = new AiPhotoCharge(householdId, userId, PlanKind.Free, photos: 0, Plans.NoteFeature, importId: null, at);
                hold.Settle(answered: read, at);
                db.AiPhotoCharges.Add(hold);
            }

            await db.SaveChangesAsync(Ct);
        });
    }

    private static Exception Busy() => new HttpRequestException("busy", null, HttpStatusCode.ServiceUnavailable);

    [Fact]
    public async Task A_person_has_AI_read_up_to_30_notes_a_day_whatever_they_delete()
    {
        var uid = $"note-limit-{Guid.NewGuid():N}";
        var client = _api.ClientFor(uid);
        var me = await client.MeAsync();
        var throwaway = await client.CreatePetAsync("Throwaway");
        var murka = await client.CreatePetAsync("Murka");
        await SeedNotesAsync(me.Household.Id, me.Id, 29);
        await SeedNotesAsync(me.Household.Id, me.Id, 5, hoursAgo: 25);                // older than a day
        await SeedNotesAsync(me.Household.Id, me.Id, 5, read: false);                  // AI never read them
        _api.Ai.Answer = _ => NoteAnswer();
        await WaitUntilDoneAsync(client, (await (await WriteAsync(client, throwaway.Id, "весит 4,2"))
            .Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id);              // the 30th

        // Deleting the pet the notes were about gives none back.
        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/api/v1/pets/{throwaway.Id}", Ct)).StatusCode);
        var refused = await WriteAsync(client, murka.Id, "вчера прививка");

        Assert.Equal(HttpStatusCode.TooManyRequests, refused.StatusCode);
        var problem = (await refused.Content.ReadFromJsonAsync<ProblemDetails>(Json, Ct))!;
        Assert.Equal(AiImportsEndpoints.TextLimitProblemType, problem.Type);
        Assert.Equal("30", problem.Extensions["limit"]?.ToString()); // the app says the number without knowing it
        // Notes cost no AI photos: a scan still starts.
        var scan = await client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(murka.Id, AiImportSource.PassportPages, [(await client.UploadPhotoAsync()).Id], null), Json, Ct);
        Assert.Equal(HttpStatusCode.Accepted, scan.StatusCode);
        await WaitUntilDoneAsync(client, (await scan.Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id);
    }

    [Fact]
    public async Task Notes_sent_at_once_are_counted_one_after_another()
    {
        var client = _api.ClientFor($"note-race-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        await SeedNotesAsync(me.Household.Id, me.Id, 29);
        _api.Ai.Answer = _ => NoteAnswer();

        var answers = await Task.WhenAll(Enumerable.Range(0, 6).Select(i => WriteAsync(client, pet.Id, $"заметка {i}")));

        var accepted = answers.Where(a => a.StatusCode == HttpStatusCode.Accepted).ToList();
        Assert.Single(accepted);
        Assert.All(answers.Except(accepted), a => Assert.Equal(HttpStatusCode.TooManyRequests, a.StatusCode));
        await WaitUntilDoneAsync(client, (await accepted[0].Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id);
    }

    [Fact]
    public async Task A_note_AI_couldnt_read_gives_its_place_back_and_its_retry_forgets_it()
    {
        var client = _api.ClientFor($"note-failed-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        await SeedNotesAsync(me.Household.Id, me.Id, 29);
        var secret = $"secret-{Guid.NewGuid():N}: the vet said she is too fat";
        _api.Ai.Answer = _ => throw Busy();
        var failed = await WaitUntilDoneAsync(client,
            (await (await WriteAsync(client, pet.Id, secret)).Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id);
        Assert.Equal(AiImportStatus.Failed, failed.Status);

        // "Try again" still fits the day: AI never read the failed one.
        _api.Ai.Answer = _ => FakeAi.EmptyScan;
        var again = await WriteAsync(client, pet.Id, secret);
        Assert.Equal(HttpStatusCode.Accepted, again.StatusCode);
        var retry = await WaitUntilDoneAsync(client, (await again.Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id);
        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/api/v1/ai-imports/{retry.Id}", Ct)).StatusCode);

        // Every reading of the note is thrown away now: its text is gone, also from "Download my data".
        var texts = new List<string?>();
        await _api.ChangeDatabaseAsync(async db => texts = await db.AiImports
            .Where(i => i.Id == failed.Id || i.Id == retry.Id).Select(i => i.Text).ToListAsync(Ct));
        Assert.Equal([null, null], texts);
        var export = await client.GetAsync("/api/v1/me/export", Ct);
        await using var zip = new System.IO.Compression.ZipArchive(new MemoryStream(await export.Content.ReadAsByteArrayAsync(Ct)));
        var household = zip.Entries.Single(e => e.FullName.EndsWith("household.json", StringComparison.Ordinal));
        using var reader = new StreamReader(household.Open());
        Assert.DoesNotContain(secret, await reader.ReadToEndAsync(Ct), StringComparison.Ordinal);
    }

    [Fact]
    public async Task A_note_thrown_away_while_still_waiting_forgets_its_text_and_its_place()
    {
        var client = _api.ClientFor($"note-queued-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        using var gate = new ManualResetEventSlim(false);
        var ct = Ct;
        _api.Ai.Answer = _ =>
        {
            gate.Wait(TimeSpan.FromSeconds(30), ct);
            return FakeAi.EmptyScan;
        };
        Guid? busy = null;
        try
        {
            // The first note keeps the worker busy, so the second one waits in the queue.
            busy = (await (await WriteAsync(client, pet.Id, "first note")).Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id;
            for (var i = 0; i < 100 && (await GetAsync(client, busy.Value)).Status != AiImportStatus.Processing; i++)
            {
                await Task.Delay(50, Ct);
            }

            var waiting = (await (await WriteAsync(client, pet.Id, "secret: she was sick on the carpet"))
                .Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!;
            Assert.Equal(AiImportStatus.Queued, (await GetAsync(client, waiting.Id)).Status);

            Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/api/v1/ai-imports/{waiting.Id}", Ct)).StatusCode);

            (string? Text, AiChargeState? Hold) stored = default;
            await _api.ChangeDatabaseAsync(async db => stored = (
                (await db.AiImports.SingleAsync(i => i.Id == waiting.Id, Ct)).Text,
                (await db.AiPhotoCharges.SingleAsync(c => c.ImportId == waiting.Id, Ct)).State));
            Assert.Equal((null, AiChargeState.Released), stored);
        }
        finally
        {
            gate.Set();
            if (busy is { } id)
            {
                await WaitUntilDoneAsync(client, id);
            }
        }
    }

    [Fact]
    public async Task Yesterday_is_counted_from_the_day_the_note_was_written()
    {
        var client = _api.ClientFor($"note-day-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        var text = $"вчера прививка от бешенства {Guid.NewGuid():N}";
        var writtenAt = DateTimeOffset.UtcNow.AddDays(-2);
        var id = Guid.Empty;
        await _api.ChangeDatabaseAsync(async db =>
        {
            // Written two days ago, read only now (the server was down, or the queue was long).
            var note = new AiImport(me.Household.Id, pet.Id, AiImportSource.Text, [], me.Id, writtenAt) { Text = text };
            db.AiImports.Add(note);
            await db.SaveChangesAsync(Ct);
            id = note.Id;
        });
        _api.Services.GetRequiredService<AiImportQueue>().Enqueue(id);
        await WaitUntilDoneAsync(client, id);

        var prompt = Assert.Single(_api.Ai.Prompts, p => p.Contains(text, StringComparison.Ordinal));
        Assert.Contains($"Today is {Iso(DateOnly.FromDateTime(writtenAt.UtcDateTime))}", prompt, StringComparison.Ordinal);
    }

    [Fact]
    public async Task A_request_id_for_another_pet_and_a_note_of_nothing_are_refused()
    {
        var client = _api.ClientFor($"note-reuse-{Guid.NewGuid():N}");
        var murka = await client.CreatePetAsync("Murka");
        var rex = await client.CreatePetAsync("Rex", Species.Dog);
        var requestId = Guid.NewGuid();
        _api.Ai.Answer = _ => NoteAnswer();
        var first = await client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(murka.Id, AiImportSource.Text, [], requestId, "весит 4,2"), Json, Ct);
        await WaitUntilDoneAsync(client, (await first.Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id);

        var forRex = await client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(rex.Id, AiImportSource.Text, [], requestId, "весит 31"), Json, Ct);

        Assert.Equal(["requestId"], await ErrorFieldsAsync(forRex));
        Assert.Equal(["text"], await ErrorFieldsAsync(await WriteAsync(client, murka.Id, "\u200B\u2060\u0007 \u200B")));
    }

    [Fact]
    public async Task Try_again_leaves_another_persons_failed_note_alone()
    {
        var anna = _api.ClientFor($"note-anna-{Guid.NewGuid():N}");
        var me = await anna.MeAsync();
        var pet = await anna.CreatePetAsync("Murka");
        var theirs = Guid.Empty;
        await _api.ChangeDatabaseAsync(async db =>
        {
            // Someone else's failed note with the same words (a member of the household; the row is all that matters).
            var note = new AiImport(me.Household.Id, pet.Id, AiImportSource.Text, [], Guid.NewGuid(), DateTimeOffset.UtcNow)
            {
                Text = "вчера прививка",
                Status = AiImportStatus.Failed,
            };
            db.AiImports.Add(note);
            await db.SaveChangesAsync(Ct);
            theirs = note.Id;
        });
        _api.Ai.Answer = _ => NoteAnswer();

        await WaitUntilDoneAsync(anna, (await (await WriteAsync(anna, pet.Id, "вчера прививка"))
            .Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id);

        Assert.Equal(AiImportStatus.Failed, (await GetAsync(anna, theirs)).Status);
    }

    [Fact]
    public async Task A_note_read_again_keeps_the_day_it_was_written_and_replaces_the_failed_one_whoever_wrote_it()
    {
        var client = _api.ClientFor($"note-retry-of-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        var text = $"вчера прививка от бешенства {Guid.NewGuid():N}";
        var writtenAt = DateTimeOffset.UtcNow.AddDays(-2);
        var failedId = Guid.Empty;
        await _api.ChangeDatabaseAsync(async db =>
        {
            // Another member's note that AI couldn't read two days ago (its models were busy).
            var failed = new AiImport(me.Household.Id, pet.Id, AiImportSource.Text, [], Guid.NewGuid(), writtenAt)
            {
                Text = text,
                Status = AiImportStatus.Failed,
                Error = AiImportError.Busy,
            };
            db.AiImports.Add(failed);
            await db.SaveChangesAsync(Ct);
            failedId = failed.Id;
        });
        _api.Ai.Answer = _ => NoteAnswer();

        var again = await client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(pet.Id, AiImportSource.Text, [], Guid.NewGuid(), text, RetryOf: failedId), Json, Ct);
        var read = await WaitUntilDoneAsync(client, (await again.Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id);

        Assert.Equal(AiImportStatus.Ready, read.Status);
        Assert.Equal(writtenAt.ToUnixTimeMilliseconds(), read.CreatedAt.ToUnixTimeMilliseconds());
        var prompt = Assert.Single(_api.Ai.Prompts, p => p.Contains(text, StringComparison.Ordinal));
        Assert.Contains($"Today is {Iso(DateOnly.FromDateTime(writtenAt.UtcDateTime))}", prompt, StringComparison.Ordinal);
        var failed = await GetAsync(client, failedId);
        Assert.Equal((AiImportStatus.Discarded, (string?)null), (failed.Status, failed.Text));
    }

    [Fact]
    public async Task A_note_changed_before_it_is_read_again_is_written_now()
    {
        var client = _api.ClientFor($"note-retry-edited-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        var failedId = Guid.Empty;
        await _api.ChangeDatabaseAsync(async db =>
        {
            var failed = new AiImport(me.Household.Id, pet.Id, AiImportSource.Text, [], me.Id, DateTimeOffset.UtcNow.AddDays(-2))
            {
                Text = "вчера прививка",
                Status = AiImportStatus.Failed,
                Error = AiImportError.Busy,
            };
            db.AiImports.Add(failed);
            await db.SaveChangesAsync(Ct);
            failedId = failed.Id;
        });
        _api.Ai.Answer = _ => NoteAnswer();
        var text = $"вчера прививка от бешенства {Guid.NewGuid():N}";

        var again = await client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(pet.Id, AiImportSource.Text, [], Guid.NewGuid(), text, RetryOf: failedId), Json, Ct);
        var read = await WaitUntilDoneAsync(client, (await again.Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id);

        // Its "yesterday" is counted from today, and the failed one still gives way.
        Assert.True(read.CreatedAt > DateTimeOffset.UtcNow.AddHours(-1));
        Assert.Contains($"Today is {Iso(Today)}",
            Assert.Single(_api.Ai.Prompts, p => p.Contains(text, StringComparison.Ordinal)), StringComparison.Ordinal);
        Assert.Equal(AiImportStatus.Discarded, (await GetAsync(client, failedId)).Status);
    }

    [Fact]
    public async Task Notes_and_scans_wait_in_lists_of_their_own()
    {
        var client = _api.ClientFor($"note-lists-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        var scanId = Guid.Empty;
        await _api.ChangeDatabaseAsync(async db =>
        {
            // A scan waiting to be checked, and 21 notes after it.
            var scan = new AiImport(me.Household.Id, pet.Id, AiImportSource.PassportPages, [], me.Id, DateTimeOffset.UtcNow.AddHours(-2))
            {
                Status = AiImportStatus.Ready,
                ScanJson = FakeAi.EmptyScan,
            };
            db.AiImports.Add(scan);
            scanId = scan.Id;
            for (var i = 0; i < 21; i++)
            {
                db.AiImports.Add(new AiImport(me.Household.Id, pet.Id, AiImportSource.Text, [], me.Id, DateTimeOffset.UtcNow.AddMinutes(-i))
                {
                    Text = $"note {i}",
                    Status = AiImportStatus.Ready,
                    ScanJson = FakeAi.EmptyScan,
                });
            }

            await db.SaveChangesAsync(Ct);
        });
        async Task<List<AiImportResponse>> ListAsync(string query) =>
            (await client.GetFromJsonAsync<List<AiImportResponse>>($"/api/v1/pets/{pet.Id}/ai-imports{query}", Json, Ct))!;

        var scans = await ListAsync("?notes=false");
        var notes = await ListAsync("?notes=true");
        var all = await ListAsync("");

        Assert.Equal([scanId], scans.Select(s => s.Id));
        Assert.Equal(20, notes.Count);
        Assert.All(notes, n => Assert.Equal(AiImportSource.Text, n.Source));
        Assert.DoesNotContain(all, i => i.Id == scanId); // an older app's one list: the newest 20 of both
    }

    [Fact]
    public async Task Weights_to_save_are_checked_like_weighings()
    {
        var client = _api.ClientFor($"note-weights-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        _api.Ai.Answer = _ => NoteAnswer();
        var started = await WriteAsync(client, pet.Id, "весит 4,2");
        var import = await WaitUntilDoneAsync(client, (await started.Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id);

        var refused = await client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply", new ApplyImportRequest(
            [], null, null, KeepPhotos: false,
            Weights: [new ImportedWeightRequest(Today.AddDays(3), 4.2m), new ImportedWeightRequest(Today, 0)]), Json, Ct);

        Assert.Equal(["weights[0].measuredOn", "weights[1].weightKg"], (await ErrorFieldsAsync(refused)).Order());
        Assert.Empty((await client.GetFromJsonAsync<List<WeightResponse>>($"/api/v1/pets/{pet.Id}/weights", Json, Ct))!);
    }

    [Fact]
    public async Task A_note_thrown_away_is_forgotten()
    {
        var client = _api.ClientFor($"note-discard-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        _api.Ai.Answer = _ => NoteAnswer();
        var started = await WriteAsync(client, pet.Id, "вчера прививка, весит 4,2");
        var import = await WaitUntilDoneAsync(client, (await started.Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id);

        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/api/v1/ai-imports/{import.Id}", Ct)).StatusCode);

        string? text = "unread";
        await _api.ChangeDatabaseAsync(async db => text = (await db.AiImports.SingleAsync(i => i.Id == import.Id, Ct)).Text);
        Assert.Null(text);
    }
}
