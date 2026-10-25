using System.Buffers;
using System.IO.Compression;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Json.Serialization.Metadata;
using Collarbell.Api.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Identity;

/// <summary>One JSON file of the export: named sections, in the order they were added.</summary>
public abstract class ExportFile
{
    private readonly List<(string Name, object? Data)> _sections = [];

    internal IReadOnlyList<(string Name, object? Data)> Sections => _sections;

    /// <summary>
    /// Adds a section. Records and the modules' own entities go as they are, minus the fields that mean nothing outside the
    /// server (<see cref="AccountExport.Internal"/>).
    /// </summary>
    public void Add(string name, object? data) => _sections.Add((name, data));
}

/// <summary>account.json: the person's own things.</summary>
public sealed class PersonalExport(Guid userId) : ExportFile
{
    public Guid UserId => userId;
}

/// <summary>A household's household.json, and the files that go next to it.</summary>
/// <param name="Role">The exporting person's role there.</param>
public sealed class HouseholdExport(Guid householdId, Guid userId, HouseholdRole role) : ExportFile
{
    private readonly List<(string Path, Func<CancellationToken, Task<byte[]?>> Read)> _files = [];

    public Guid HouseholdId => householdId;

    public Guid UserId => userId;

    public HouseholdRole Role => role;

    internal IReadOnlyList<(string Path, Func<CancellationToken, Task<byte[]?>> Read)> Files => _files;

    /// <summary>
    /// A file for the archive, at <paramref name="path"/> inside the household's folder (e.g. <c>files/….jpg</c>). It is read
    /// when its turn comes, one at a time; <paramref name="read"/> returns null when the file is gone from storage.
    /// </summary>
    public void AddFile(string path, Func<CancellationToken, Task<byte[]?>> read) => _files.Add((path, read));
}

/// <summary>A module's part of account.json (notification settings, phones, the activity log).</summary>
public interface IPersonalExportSource
{
    Task ExportAsync(PersonalExport export, CancellationToken ct);
}

/// <summary>A module's part of a household's household.json (pets, records, supplies…) and its files.</summary>
public interface IHouseholdExportSource
{
    Task ExportAsync(HouseholdExport export, CancellationToken ct);
}

/// <summary>A person of the household as the export names them; <c>doneBy</c>, <c>createdBy</c> and the like are their ids.</summary>
/// <param name="Email">Null where the app doesn't show it: a helper sees the others' names only.</param>
public sealed record ExportedPerson(Guid Id, string? Name, string? Email, HouseholdRole Role, DateTimeOffset JoinedAt, bool IsYou);

/// <summary>
/// "Download my data" (spec, "Выгрузка данных"; GDPR art. 15 and 20): a ZIP with README.txt, account.json and, for each
/// household the person is in, <c>households/N-name/household.json</c> with the household's photos and scans next to it.
/// The modules say what is theirs (<see cref="IPersonalExportSource"/>, <see cref="IHouseholdExportSource"/>); Identity
/// doesn't know them. The archive goes out while it is being made, so a big one starts downloading at once.
/// </summary>
public sealed class AccountExport(
    AppDbContext db,
    IEnumerable<IPersonalExportSource> personalSources,
    IEnumerable<IHouseholdExportSource> householdSources,
    TimeProvider clock,
    ILogger<AccountExport> log)
{
    public const string Format = "collarbell-export";

    /// <summary>The format's version: a reader can tell a newer layout.</summary>
    public const int Version = 1;

    /// <summary>The rate limit of exports (Program.cs): each one reads every file of the person's households.</summary>
    public const string RateLimit = "export";

    /// <summary>
    /// Fields that mean nothing outside the server: storage paths and checksums, the app's retry keys, phones' push
    /// addresses, and the household id every row of a household.json would repeat.
    /// </summary>
    internal static readonly IReadOnlySet<string> Internal = new HashSet<string>
    {
        "householdId", "clientRequestId", "token", "storageKey", "thumbnailKey", "sha256",
    };

    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true,
        // Names in Cyrillic stay readable in the file. It is a file to read, not a web page.
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
        Converters = { new JsonStringEnumConverter() },
        TypeInfoResolver = new DefaultJsonTypeInfoResolver { Modifiers = { LeaveOutInternal } },
    };

    /// <summary>The archive's name, e.g. <c>collarbell-export-2026-10-06.zip</c>.</summary>
    public static string FileName(DateTimeOffset now) => $"collarbell-export-{now:yyyy-MM-dd}.zip";

    public async Task WriteAsync(Guid userId, Stream output, CancellationToken ct)
    {
        var user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == userId, ct);
        var households = await (from m in db.HouseholdMembers
                                where m.UserId == userId
                                join h in db.Households on m.HouseholdId equals h.Id
                                orderby m.JoinedAt
                                select new { h.Id, h.Name, h.TimeZone, h.CreatedAt, m.Role, m.JoinedAt })
            .ToListAsync(ct);
        var folders = households.Select((h, i) => $"households/{i + 1}-{FolderName(h.Name)}").ToList();

        // Each entry is made in memory and then passed on: the ZIP classes still write parts of an entry synchronously,
        // and a server response allows no blocking writes. So at most one file is in memory at a time.
        var archive = new PassOnStream(output);
        await using (var zip = new ZipArchive(archive, ZipArchiveMode.Create, leaveOpen: true))
        {
            async Task AddAsync(string path, byte[] content, CompressionLevel level)
            {
                var entry = zip.CreateEntry(path, level);
                await using (var stream = entry.Open())
                {
                    await stream.WriteAsync(content, ct);
                }

                await archive.PassOnAsync(ct);
            }

            await AddAsync("README.txt", Encoding.UTF8.GetBytes(Readme(user.Locale)), CompressionLevel.Optimal);

            var account = new PersonalExport(userId);
            account.Add("format", Format);
            account.Add("version", Version);
            account.Add("exportedAt", clock.GetUtcNow());
            account.Add("account", new { user.Id, user.Email, user.DisplayName, user.Locale, user.TimeZone, user.CreatedAt });
            account.Add("households", households.Select((h, i) => new { h.Id, h.Name, h.Role, h.JoinedAt, Folder = folders[i] }).ToList());
            foreach (var source in personalSources)
            {
                await source.ExportAsync(account, ct);
            }

            await AddAsync("account.json", ToJson(account), CompressionLevel.Optimal);

            for (var i = 0; i < households.Count; i++)
            {
                var household = households[i];
                var export = new HouseholdExport(household.Id, userId, household.Role);
                export.Add("household", new { household.Id, household.Name, household.TimeZone, household.CreatedAt, YourRole = household.Role });
                export.Add("people", await PeopleAsync(household.Id, userId, household.Role, ct));

                // Who was invited when, as owners see it in the app. Without the codes: an open one still lets anyone in,
                // and an exported file is easily passed on.
                if (household.Role == HouseholdRole.Owner)
                {
                    export.Add("invites", await db.HouseholdInvites.AsNoTracking()
                        .Where(i => i.HouseholdId == household.Id)
                        .OrderBy(i => i.CreatedAt)
                        .Select(i => new { i.Id, i.Role, i.CreatedBy, i.CreatedAt, i.ExpiresAt, i.AcceptedBy, i.AcceptedAt, i.RevokedAt })
                        .ToListAsync(ct));
                }
                foreach (var source in householdSources)
                {
                    await source.ExportAsync(export, ct);
                }

                await AddAsync($"{folders[i]}/household.json", ToJson(export), CompressionLevel.Optimal);

                // Photos and scans are compressed already. A file storage can't give now doesn't cut the archive short:
                // the others go on, and files-missing.txt names it (household.json lists it anyway).
                var missing = new List<string>();
                foreach (var (path, read) in export.Files)
                {
                    byte[]? content;
                    try
                    {
                        content = await read(ct);
                    }
                    catch (Exception e) when (!ct.IsCancellationRequested)
                    {
                        log.LogWarning(e, "A file of household {HouseholdId} couldn't be read for an export.", household.Id);
                        content = null;
                    }

                    if (content is null)
                    {
                        missing.Add(path);
                        continue;
                    }

                    await AddAsync($"{folders[i]}/{path}", content, CompressionLevel.NoCompression);
                }

                if (missing.Count > 0)
                {
                    await AddAsync($"{folders[i]}/files-missing.txt", Encoding.UTF8.GetBytes(string.Join('\n', missing) + '\n'),
                        CompressionLevel.Optimal);
                }
            }
        }

        // The table of contents, written as the archive closes.
        await archive.PassOnAsync(ct);
    }

    private async Task<List<ExportedPerson>> PeopleAsync(Guid householdId, Guid userId, HouseholdRole role, CancellationToken ct) =>
        [.. (await (from m in db.HouseholdMembers
                    where m.HouseholdId == householdId
                    join u in db.Users on m.UserId equals u.Id
                    orderby m.JoinedAt
                    select new { u.Id, u.DisplayName, u.Email, m.Role, m.JoinedAt })
                .ToListAsync(ct))
            .Select(p => new ExportedPerson(p.Id, p.DisplayName,
                p.Id == userId || role != HouseholdRole.Helper ? p.Email : null, p.Role, p.JoinedAt, p.Id == userId))];

    /// <summary>The file's sections as one JSON object, in their order. Made in memory: the archive is written asynchronously.</summary>
    private static byte[] ToJson(ExportFile file)
    {
        var buffer = new ArrayBufferWriter<byte>();
        using (var writer = new Utf8JsonWriter(buffer, new JsonWriterOptions { Indented = true, Encoder = Json.Encoder }))
        {
            writer.WriteStartObject();
            foreach (var (name, data) in file.Sections)
            {
                writer.WritePropertyName(name);
                JsonSerializer.Serialize(writer, data, data?.GetType() ?? typeof(object), Json);
            }

            writer.WriteEndObject();
        }

        return buffer.WrittenSpan.ToArray();
    }

    private static void LeaveOutInternal(JsonTypeInfo info)
    {
        if (info.Kind != JsonTypeInfoKind.Object)
        {
            return;
        }

        foreach (var property in info.Properties.Where(p => Internal.Contains(p.Name)).ToList())
        {
            info.Properties.Remove(property);
        }
    }

    /// <summary>A household's name as a folder name: letters and digits, the rest becomes "-"; "household" when nothing is left.</summary>
    internal static string FolderName(string name)
    {
        var folder = new StringBuilder();
        foreach (var c in name.Trim())
        {
            if (char.IsLetterOrDigit(c))
            {
                folder.Append(c);
            }
            else if (folder.Length > 0 && folder[^1] != '-')
            {
                folder.Append('-');
            }
        }

        var result = folder.ToString().TrimEnd('-');
        return result.Length == 0 ? "household" : result[..Math.Min(result.Length, 40)].TrimEnd('-');
    }

    /// <summary>
    /// Takes the archive's writes into memory, then <see cref="PassOnAsync"/> sends them on asynchronously. It can't be
    /// read or wound back, so the archive writes each entry once, with its sizes after the data.
    /// </summary>
    private sealed class PassOnStream(Stream output) : Stream
    {
        private readonly MemoryStream _pending = new();
        private long _written;

        public override bool CanRead => false;

        public override bool CanSeek => false;

        public override bool CanWrite => true;

        public override long Length => throw new NotSupportedException();

        public override long Position
        {
            get => _written;
            set => throw new NotSupportedException();
        }

        public override void Write(byte[] buffer, int offset, int count) => Write(buffer.AsSpan(offset, count));

        public override void Write(ReadOnlySpan<byte> buffer)
        {
            _pending.Write(buffer);
            _written += buffer.Length;
        }

        public override Task WriteAsync(byte[] buffer, int offset, int count, CancellationToken ct)
        {
            Write(buffer.AsSpan(offset, count));
            return Task.CompletedTask;
        }

        public override ValueTask WriteAsync(ReadOnlyMemory<byte> buffer, CancellationToken ct = default)
        {
            Write(buffer.Span);
            return ValueTask.CompletedTask;
        }

        /// <summary>Sends what has been written so far on to the output.</summary>
        public async Task PassOnAsync(CancellationToken ct)
        {
            if (_pending.Length == 0)
            {
                return;
            }

            await output.WriteAsync(_pending.GetBuffer().AsMemory(0, (int)_pending.Length), ct);
            _pending.SetLength(0);
        }

        public override void Flush()
        {
        }

        public override Task FlushAsync(CancellationToken ct) => Task.CompletedTask;

        public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException();

        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();

        public override void SetLength(long value) => throw new NotSupportedException();
    }

    private static string Readme(string locale) => locale == Locales.Russian ? ReadmeRu : ReadmeEn;

    private const string ReadmeEn = """
        Your Collarbell data

        account.json — your account: e-mail, name, language, time zone, notification settings, your phones (without
        their push addresses), the AI photos you used, and your activity of the last 7 days: the requests your apps made
        and what they reported about themselves (screens, actions, errors).

        households/ — a folder for each household you are in:
          household.json — the household, its people and their roles (and its invites, if you are an owner), the pets
          with their passport details and weighings, care plans and records, vet visits, feeding schedules and marks,
          supplies and purchases, documents, AI scans;
          files/ — the photos and scans: pet photos, document pages, files of records, photos of scans. household.json
          lists them under "files"; one with "attachedAt": null isn't used anywhere yet (a scan not saved, an upload
          given up halfway). files-missing.txt, if there is one, names the files that couldn't be read just now.

        The .json files are text (UTF-8): a text editor opens them, other programs can read them. Ids link the records:
        "doneBy" or "createdBy" is the id of a person under "people" (someone who has left isn't listed), "fileId" is a
        file under "files", "petId" a pet under "pets".
        """;

    private const string ReadmeRu = """
        Ваши данные Collarbell

        account.json — ваш аккаунт: почта, имя, язык, часовой пояс, настройки уведомлений, ваши телефоны (без адресов
        для пушей), потраченные вами AI-фото и ваша активность за последние 7 дней: запросы ваших приложений и то, что
        они сообщали о себе (экраны, действия, ошибки).

        households/ — папка на каждую вашу группу:
          household.json — группа, её люди и их роли (и приглашения, если вы владелец), питомцы с данными паспорта
          и взвешиваниями, планы ухода и записи, визиты к ветеринару, расписания кормления и отметки, запасы и покупки,
          документы, AI-сканы;
          files/ — фото и сканы: фото питомцев, страницы документов, файлы записей, фото сканов. В household.json они
          перечислены в разделе "files"; файл с "attachedAt": null пока нигде не используется (несохранённый скан,
          брошенная загрузка). files-missing.txt, если он есть, называет файлы, которые сейчас не удалось прочитать.

        Файлы .json — это текст (UTF-8): их открывает любой текстовый редактор и читают другие программы. Записи связаны
        через id: "doneBy" или "createdBy" — id человека из раздела "people" (кто ушёл из группы, там не указан),
        "fileId" — файл из раздела "files", "petId" — питомец из раздела "pets".
        """;
}
