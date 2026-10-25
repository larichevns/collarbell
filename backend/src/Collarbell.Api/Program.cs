using System.Globalization;
using System.Reflection;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Collarbell.Api.Infrastructure.Auth;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Storage;
using Collarbell.Api.Modules.Admin;
using Collarbell.Api.Modules.Ai;
using Collarbell.Api.Modules.Appointments;
using Collarbell.Api.Modules.Billing;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Observe;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Routines;
using Collarbell.Api.Modules.Supplies;
using Collarbell.Api.Modules.Today;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.EntityFrameworkCore;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// The build runs the app once to write contracts/openapi.json; that run has no database.
var isOpenApiGeneration = Assembly.GetEntryAssembly()?.GetName().Name == "GetDocument.Insider";

builder.AddServiceDefaults();

if (isOpenApiGeneration)
{
    builder.Services.AddDbContext<AppDbContext>(o => o.UseNpgsql("Host=localhost").UseSnakeCaseNamingConvention());
}
else
{
    builder.AddNpgsqlDbContext<AppDbContext>("collarbelldb",
        configureDbContextOptions: o => o.UseSnakeCaseNamingConvention());
}

builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.Converters.Add(new JsonStringEnumConverter());
    // Numbers are JSON numbers, never strings: the contract then says "integer", not "integer or string".
    o.SerializerOptions.NumberHandling = JsonNumberHandling.Strict;
});
builder.Services.AddProblemDetails();
// A request the API can't read (broken JSON, a time where a date belongs) is the client's mistake: 400, not 500.
// Development throws these as exceptions to log the details; this keeps their status code.
builder.Services.Configure<ExceptionHandlerOptions>(o =>
    o.StatusCodeSelector = e => e is BadHttpRequestException bad ? bad.StatusCode : StatusCodes.Status500InternalServerError);
builder.Services.AddOpenApi();
builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddCollarbellAuth(builder.Configuration, builder.Environment);
builder.Services.AddScoped<CurrentUserAccessor>();
builder.Services.AddScoped<HouseholdCalendar>();

// Invite codes are looked up and accepted at most 10 times in 10 minutes per person: guessing one would take ages.
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.OnRejected = (context, _) =>
    {
        if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
        {
            context.HttpContext.Response.Headers.RetryAfter = ((int)Math.Ceiling(retryAfter.TotalSeconds)).ToString(CultureInfo.InvariantCulture);
        }

        return ValueTask.CompletedTask;
    };
    o.AddPolicy(HouseholdsEndpoints.InviteRateLimit, context => RateLimitPartition.GetFixedWindowLimiter(
        context.User.GetSubject() ?? "anonymous",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(10) }));
    // The app reports in batches every half a minute or so; a runaway loop can't fill the log.
    o.AddPolicy(AppEventsEndpoints.RateLimit, context => RateLimitPartition.GetFixedWindowLimiter(
        context.User.GetSubject() ?? "anonymous",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 6, Window = TimeSpan.FromMinutes(1) }));
    // Reading photos with AI: a person scans one thing at a time; many requests at once can't outrun the monthly limit.
    o.AddPolicy(AiEndpoints.RateLimit, context => RateLimitPartition.GetFixedWindowLimiter(
        context.User.GetSubject() ?? "anonymous",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1) }));
    // "Download my data" reads every file of the person's households: a few tries an hour are plenty.
    o.AddPolicy(AccountExport.RateLimit, context => RateLimitPartition.GetFixedWindowLimiter(
        context.User.GetSubject() ?? "anonymous",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 5, Window = TimeSpan.FromHours(1) }));
});

// Deleting an account and "Download my data" (Identity/AccountDeletion.cs, AccountExport.cs): the modules hook in with
// what is theirs, as with pet deletion; the sign-in account is deleted in Firebase.
builder.Services.Configure<AccountCleanupOptions>(builder.Configuration.GetSection("AccountCleanup"));
builder.Services.AddSingleton<ISignInAccounts, FirebaseSignInAccounts>();
builder.Services.AddScoped<AccountDeletion>();
builder.Services.AddScoped<AccountCleanup>();
builder.Services.AddScoped<AccountExport>();
builder.Services.AddScoped<IHouseholdDeletionHandler, HouseholdFiles>();
builder.Services.AddScoped<IAccountDeletionHandler, ObserveAccountDeletion>();
builder.Services.AddScoped<IPersonalExportSource, NotificationsExport>();
builder.Services.AddScoped<IPersonalExportSource, AiPhotosExport>();
builder.Services.AddScoped<IPersonalExportSource, ObserveExport>();
// In this order in household.json.
builder.Services.AddScoped<IHouseholdExportSource, PlanExport>();
builder.Services.AddScoped<IHouseholdExportSource, PetsExport>();
builder.Services.AddScoped<IHouseholdExportSource, CareExport>();
builder.Services.AddScoped<IHouseholdExportSource, AppointmentsExport>();
builder.Services.AddScoped<IHouseholdExportSource, RoutinesExport>();
builder.Services.AddScoped<IHouseholdExportSource, SuppliesExport>();
builder.Services.AddScoped<IHouseholdExportSource, AiImportsExport>();
builder.Services.AddScoped<IHouseholdExportSource, DocumentsExport>();

// The admin's "визор" and the server's self-checks: the request log, the app's events, alerts to Telegram.
builder.Services.Configure<ObserveOptions>(builder.Configuration.GetSection("Observe"));
builder.Services.Configure<AlertsOptions>(builder.Configuration.GetSection("Alerts"));
builder.Services.AddSingleton<RequestLogQueue>();
builder.Services.AddScoped<ObserveRetention>();
builder.Services.AddScoped<AlertChecks>();
// No logging of this client: its addresses hold the bot's token.
builder.Services.AddHttpClient<IAlertSender, TelegramAlertSender>().RemoveAllLoggers();

// Live updates: the household's open screens hear what changed (Modules/Live). Apps send nothing but the handshake
// and pings, so their messages stay small.
builder.Services.AddSignalR(o => o.MaximumReceiveMessageSize = 4 * 1024);
builder.Services.AddSingleton<LiveChanges>();

// Files: S3-compatible storage (SeaweedFS locally, R2 in production) and the modules' public services.
var storageConfigured = ObjectStorage.IsConfigured(builder.Configuration);
builder.Services.AddObjectStorage(builder.Configuration);
builder.Services.AddScoped<Files>();
builder.Services.AddScoped<PetDocuments>();
builder.Services.AddScoped<IPetDeletionHandler>(sp => sp.GetRequiredService<PetDocuments>());
builder.Services.AddScoped<IPetDeletionHandler, CareRecordFiles>();
// The pet's weight log shows the weights vets noted at check-ups too.
builder.Services.AddScoped<IPetWeightSource, CareRecordWeights>();
builder.Services.AddScoped<PetWeights>();
builder.Services.AddScoped<PetDirectory>();
builder.Services.AddScoped<PetIdentityWriter>();
builder.Services.AddScoped<CarePlanDirectory>();
builder.Services.AddScoped<CareRecordsWriter>();

// AI: one chat-client interface over Gemini, OpenAI-compatible providers and Ollama; scans run in the background.
builder.Services.Configure<AiOptions>(builder.Configuration.GetSection("Ai"));
builder.Services.AddSingleton<IAiChatClientFactory, AiChatClientFactory>();
builder.Services.AddScoped<AiRunner>();

// Plans: Free or Premium per household, and what each allows (AI photos a month).
builder.Services.Configure<PlansOptions>(builder.Configuration.GetSection("Plans"));
builder.Services.AddScoped<Plans>();
builder.Services.AddSingleton<AiImportQueue>();
builder.Services.AddScoped<AiImportProcessor>();
builder.Services.AddScoped<AiDrafts>();
builder.Services.AddScoped<IUploadKeeper, AiImportUploads>();
if (!isOpenApiGeneration)
{
    builder.Services.AddHostedService<AiImportWorker>();
}
builder.Services.AddScoped<StorageCleanup>();
if (storageConfigured && !isOpenApiGeneration)
{
    builder.Services.AddHostedService<StorageCleanupWorker>();
}

// Reminders: modules plan them from their data, the dispatcher pushes them through Firebase when they are due.
builder.Services.Configure<NotificationsOptions>(builder.Configuration.GetSection("Notifications"));
builder.Services.AddSingleton<IPushSender, FcmPushSender>();
builder.Services.AddScoped<ReminderSchedule>();
builder.Services.AddScoped<IHouseholdChangeHandler>(sp => sp.GetRequiredService<ReminderSchedule>());
builder.Services.AddScoped<ReminderDispatcher>();
builder.Services.AddScoped<IReminderSource, CarePlanReminders>();
builder.Services.AddScoped<IReminderSource, FeedingReminders>();
builder.Services.AddScoped<IReminderSource, AppointmentReminders>();
builder.Services.AddScoped<IReminderSource, SupplyReminders>();
builder.Services.AddScoped<FeedingDirectory>();
builder.Services.AddScoped<FeedingMarkPush>();
builder.Services.AddScoped<FeedingSupplies>();
builder.Services.AddScoped<AppointmentDirectory>();

// Supplies: the stock estimate, and products found by barcode in our catalog, Open Pet Food Facts and UPCitemdb.
builder.Services.AddScoped<SupplyStock>();
builder.Services.AddScoped<SupplyDirectory>();
builder.Services.AddScoped<ProductLookup>();
builder.Services.AddProductDatabases(builder.Configuration);

if (!isOpenApiGeneration)
{
    builder.Services.AddHostedService<ReminderPlanner>();
    builder.Services.AddHostedService<ReminderDispatcherWorker>();
    builder.Services.AddHostedService<RequestLogWriter>();
    builder.Services.AddHostedService<ObserveRetentionWorker>();
    builder.Services.AddHostedService<AlertWorker>();
    builder.Services.AddHostedService<AccountCleanupWorker>();
}

var app = builder.Build();

// First, so it sees every answer as it went out: 401, 429 and the exception handler's 500 included.
app.UseMiddleware<RequestLogMiddleware>();
app.UseExceptionHandler();
app.UseStatusCodePages();
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

app.MapDefaultEndpoints();
app.MapOpenApi();
if (app.Environment.IsDevelopment())
{
    app.MapScalarApiReference();
}

// Every endpoint runs in one of the user's households, with their role there (HouseholdAccess); the household hears
// the changes it makes (LiveChanges).
var api = app.MapGroup("/api/v1")
    .RequireAuthorization()
    .AddEndpointFilter<HouseholdAccessFilter>()
    .AddEndpointFilter<LiveChangesFilter>();
api.MapMeEndpoints();
api.MapHouseholdsEndpoints();
api.MapPetsEndpoints();
api.MapWeightsEndpoints();
api.MapPassportEndpoints();
api.MapFilesEndpoints();
api.MapDocumentsEndpoints();
api.MapCarePlansEndpoints();
api.MapCareRecordsEndpoints();
api.MapTodayEndpoints();
api.MapAiEndpoints();
api.MapAiImportsEndpoints();
api.MapRoutinesEndpoints();
api.MapAppointmentsEndpoints();
api.MapNotificationsEndpoints();
api.MapSuppliesEndpoints();
api.MapIdentifierScanEndpoints();
api.MapAppEventsEndpoints();
api.MapPlanEndpoints();
api.MapLiveTicketsEndpoints();
app.MapAdminEndpoints();

// WebSockets only: the app connects straight to it, with no "negotiate" request first (the proxies pass WebSockets on:
// deploy/nginx.conf).
app.MapHub<HouseholdHub>(HouseholdHub.Path, o => o.Transports = HttpTransportType.WebSockets).RequireAuthorization();

// "dotnet Collarbell.Api.dll migrate": the deploy script (deploy/release.sh) brings the database and the bucket up
// to the new version before it replaces the running one, then this run ends. Locally and in tests it happens at start.
var migrateOnly = args.Contains("migrate");
if (!isOpenApiGeneration && (migrateOnly || app.Environment.IsDevelopment() || app.Environment.IsEnvironment("Testing")))
{
    await using var scope = app.Services.CreateAsyncScope();
    await scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.MigrateAsync();

    // Local, test and server storage start empty: the bucket is created on the first run.
    if (storageConfigured)
    {
        await scope.ServiceProvider.GetRequiredService<ObjectStorage>().EnsureBucketAsync(CancellationToken.None);
    }
    else
    {
        app.Logger.LogWarning("Object storage is not configured: file uploads will fail. Run the API through the AppHost.");
    }
}

// "dotnet Collarbell.Api.dll make-admin <e-mail>": opens the admin (/admin) to that user. On the server only, so no
// e-mail of an admin is in the repository. The user has to have signed in to the app once.
if (args is ["make-admin", ..])
{
    if (args is not ["make-admin", var adminEmail])
    {
        Console.Error.WriteLine("Usage: make-admin <e-mail>");
        Environment.ExitCode = 2;
        return;
    }

    await using var scope = app.Services.CreateAsyncScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    var email = adminEmail.Trim().ToLowerInvariant();
    var found = await db.Users.Where(u => u.Email != null && u.Email.ToLower() == email).ToListAsync();
    if (found is not [var admin])
    {
        // None (they haven't signed in yet), or several: then nobody is changed, the ids say whom to look at.
        Console.Error.WriteLine(found.Count == 0
            ? "No user with this e-mail: they have to sign in to the app once first."
            : $"{found.Count} users have this e-mail ({string.Join(", ", found.Select(u => u.Id))}); nobody was changed.");
        Environment.ExitCode = 1;
        return;
    }

    admin.IsAdmin = true;
    await db.SaveChangesAsync();
    Console.WriteLine($"Admin now: {admin.Id}, signed up {admin.CreatedAt:yyyy-MM-dd}.");
    return;
}

// "dotnet Collarbell.Api.dll delete-account <e-mail>": what deleting that account would do; with "--yes" at the end it
// deletes it, as "Delete account" in the app does. For a deletion asked for by e-mail (landing, "Delete your account").
if (args is ["delete-account", ..])
{
    if (args is not (["delete-account", _] or ["delete-account", _, "--yes"]))
    {
        Console.Error.WriteLine("Usage: delete-account <e-mail> [--yes]");
        Environment.ExitCode = 2;
        return;
    }

    await using var scope = app.Services.CreateAsyncScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    var email = args[1].Trim().ToLowerInvariant();
    var found = await db.Users.Where(u => u.Email != null && u.Email.ToLower() == email).ToListAsync();
    if (found is not [var user])
    {
        Console.Error.WriteLine(found.Count == 0
            ? "No user with this e-mail."
            : $"{found.Count} users have this e-mail ({string.Join(", ", found.Select(u => u.Id))}); nobody was deleted.");
        Environment.ExitCode = 1;
        return;
    }

    var deletion = scope.ServiceProvider.GetRequiredService<AccountDeletion>();
    var outcomes = args is [.., "--yes"]
        ? (await deletion.DeleteAsync(user.Id, confirmedPlan: null, CancellationToken.None)).Households
        : (await deletion.PreviewAsync(user.Id, CancellationToken.None)).Households;
    Console.WriteLine($"User {user.Id}, signed up {user.CreatedAt:yyyy-MM-dd}.");
    foreach (var h in outcomes)
    {
        Console.WriteLine($"  {h.Name} ({h.Role}, {h.Pets} pets, {h.Others} others): {h.Fate}{(h.NewOwner is null ? "" : $" to {h.NewOwner}")}");
    }

    if (args is [.., "--yes"])
    {
        var signIn = await db.DeletedAccounts.AsNoTracking().SingleAsync(d => d.AuthSubject == user.AuthSubject);
        Console.WriteLine(signIn.SignInDeletedAt is null
            ? "Deleted. The Firebase sign-in account couldn't be deleted now: the server tries again every 10 minutes."
            : "Deleted, with the Firebase sign-in account.");
    }
    else
    {
        Console.WriteLine("Nothing deleted yet: run it again with --yes at the end.");
    }

    return;
}

if (migrateOnly)
{
    return;
}

await app.RunAsync();

public partial class Program;
