using System.Text.Json;
using Amazon.Runtime;
using Amazon.S3;
using Amazon.S3.Model;
using Collarbell.Api.Infrastructure.Auth;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Ai;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Observe;
using Collarbell.Api.Modules.Supplies;
using DotNet.Testcontainers.Builders;
using DotNet.Testcontainers.Containers;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Testcontainers.PostgreSql;

namespace Collarbell.Api.Tests;

/// <summary>Runs the API in the Testing environment against throwaway Postgres and SeaweedFS (S3) containers.</summary>
public sealed class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private const int S3Port = 8333;
    private const int MasterPort = 9333;
    private const string AccessKey = "tests";
    private const string SecretKey = "tests-secret";

    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:17-alpine").Build();

    // The same image and S3 identity setup as the AppHost's SeaweedFS integration.
    private readonly IContainer _storage = new ContainerBuilder("chrislusf/seaweedfs:4.46")
        .WithEntrypoint("sh")
        .WithCommand("-c", $$"""
            cat > /tmp/s3.json <<'EOF'
            {"identities":[{"name":"tests","credentials":[{"accessKey":"{{AccessKey}}","secretKey":"{{SecretKey}}"}],"actions":["Admin","Read","Write","List","Tagging"]}]}
            EOF
            exec weed server -dir=/data -filer -s3 -s3.config=/tmp/s3.json
            """)
        .WithPortBinding(S3Port, assignRandomHostPort: true)
        .WithPortBinding(MasterPort, assignRandomHostPort: true)
        .WithWaitStrategy(Wait.ForUnixContainer().UntilHttpRequestIsSucceeded(r => r
            .ForPort(MasterPort)
            .ForPath("/dir/status")
            .ForResponseMessageMatching(HasVolumesAsync)))
        .Build();

    /// <summary>Downloads through signed links, like a phone does: straight from storage, not through the API.</summary>
    public HttpClient Storage { get; } = new();

    public async ValueTask InitializeAsync() => await Task.WhenAll(_postgres.StartAsync(), _storage.StartAsync());

    public override async ValueTask DisposeAsync()
    {
        await base.DisposeAsync();
        Storage.Dispose();
        await _postgres.DisposeAsync();
        await _storage.DisposeAsync();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:collarbelldb", _postgres.GetConnectionString());
        builder.UseSetting("ConnectionStrings:storage",
            $"Endpoint=http://{_storage.Hostname}:{_storage.GetMappedPublicPort(S3Port)};AccessKey={AccessKey};SecretKey={SecretKey}");
        builder.UseSetting("Auth:DevUsers:Enabled", "true");
        // Tests run the cleanup themselves (RunStorageCleanupAsync), so the timer is off.
        builder.UseSetting("Storage:CleanupInterval", "00:00:00");
        // Bad requests throw as in Development, so the tests also cover how they are turned into responses.
        builder.ConfigureServices(services => services.Configure<RouteHandlerOptions>(o => o.ThrowOnBadRequest = true));

        // AI: three fake models in the chain; FakeAi decides what each answers. A model that hangs is given up
        // on after two seconds.
        for (var i = 0; i < 3; i++)
        {
            builder.UseSetting($"Ai:Profiles:extraction:{i}:Provider", "Gemini");
            builder.UseSetting($"Ai:Profiles:extraction:{i}:Model", $"fake-{(char)('a' + i)}");
        }

        builder.UseSetting("Ai:AttemptTimeout", "00:00:02");
        builder.UseSetting("Ai:AttemptTimeoutPerImage", "00:00:00");

        builder.ConfigureServices(services => services.AddSingleton<IAiChatClientFactory>(Ai));

        // Product databases: fakes instead of Open Pet Food Facts and UPCitemdb, in the same order.
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<IProductDatabase>();
            services.AddSingleton<IProductDatabase>(OpenPetFoodFacts);
            services.AddSingleton<IProductDatabase>(UpcItemDb);
        });

        // Reminders: the tests plan and send them themselves, at the moments they choose; Firebase is a fake.
        builder.UseSetting("Notifications:DispatchInterval", "00:00:00");
        builder.UseSetting("Notifications:PlanInterval", "00:00:00");
        builder.ConfigureServices(services => services.AddSingleton<IPushSender>(Push));

        // Deleted accounts: Firebase Authentication is a fake, and the cleanup runs when a test says so.
        builder.UseSetting("AccountCleanup:Interval", "00:00:00");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<ISignInAccounts>();
            services.AddSingleton<ISignInAccounts>(SignIns);
        });

        // The request log, its cleanup and the self-checks run when a test says so; Telegram is a fake.
        builder.UseSetting("Observe:FlushInterval", "00:00:00");
        builder.UseSetting("Observe:CleanupInterval", "00:00:00");
        builder.UseSetting("Alerts:CheckInterval", "00:00:00");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<IAlertSender>();
            services.AddSingleton<IAlertSender>(Alerts);
        });
    }

    public FakeAlerts Alerts { get; } = new();

    public FakeSignIns SignIns { get; } = new();

    /// <summary>Tries again the sign-in accounts Firebase didn't delete, and forgets old deleted accounts.</summary>
    public async Task RunAccountCleanupAsync()
    {
        await using var scope = Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<AccountCleanup>().RunOnceAsync(CancellationToken.None);
    }

    /// <summary>Writes the requests noted so far, as the background writer does every few seconds.</summary>
    public async Task FlushRequestLogAsync()
    {
        await using var scope = Services.CreateAsyncScope();
        await Services.GetRequiredService<RequestLogQueue>()
            .DrainAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), CancellationToken.None);
    }

    /// <summary>Runs the server's self-checks at <paramref name="now"/>; the kinds of trouble found.</summary>
    public async Task<List<string>> RunAlertChecksAsync(DateTimeOffset now)
    {
        await using var scope = Services.CreateAsyncScope();
        return [.. (await scope.ServiceProvider.GetRequiredService<AlertChecks>().RunOnceAsync(now, CancellationToken.None)).Select(f => f.Kind)];
    }

    /// <summary>Deletes what the log keeps no longer, as of <paramref name="now"/>.</summary>
    public async Task<int> RunObserveRetentionAsync(DateTimeOffset now)
    {
        await using var scope = Services.CreateAsyncScope();
        return await scope.ServiceProvider.GetRequiredService<ObserveRetention>().RunOnceAsync(now, CancellationToken.None);
    }

    public FakeAi Ai { get; } = new();

    public FakePush Push { get; } = new();

    public FakeProductDatabase OpenPetFoodFacts { get; } = new(ProductLookupSource.OpenPetFoodFacts);

    public FakeProductDatabase UpcItemDb { get; } = new(ProductLookupSource.UpcItemDb);

    /// <summary>Sends what is due at <paramref name="now"/>, as the dispatcher does every few seconds.</summary>
    public async Task<int> SendRemindersAsync(DateTimeOffset now)
    {
        await using var scope = Services.CreateAsyncScope();
        return await scope.ServiceProvider.GetRequiredService<ReminderDispatcher>().RunOnceAsync(now, CancellationToken.None);
    }

    /// <summary>Plans every household's reminders at <paramref name="now"/>, as the background run does.</summary>
    public async Task PlanAllRemindersAsync(DateTimeOffset now)
    {
        await using var scope = Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<ReminderSchedule>().PlanAllAsync(now, CancellationToken.None);
    }

    /// <summary>The household's reminders straight from the database, soonest first.</summary>
    public async Task<List<Reminder>> RemindersOfAsync(Guid householdId)
    {
        await using var scope = Services.CreateAsyncScope();
        return await scope.ServiceProvider.GetRequiredService<AppDbContext>().Reminders.AsNoTracking()
            .Where(r => r.HouseholdId == householdId)
            .OrderBy(r => r.FireAt)
            .ThenBy(r => r.Key)
            .ToListAsync();
    }

    /// <summary>Runs <paramref name="change"/> on the database directly, e.g. to make a state the API wouldn't.</summary>
    public async Task ChangeDatabaseAsync(Func<AppDbContext, Task> change)
    {
        await using var scope = Services.CreateAsyncScope();
        await change(scope.ServiceProvider.GetRequiredService<AppDbContext>());
    }

    /// <summary>A client signed in as a dev user; each uid is a separate person with their own household.</summary>
    public HttpClient ClientFor(string uid, string? email = null)
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Add(DevUserAuthenticationHandler.UserHeader, uid);
        if (email is not null)
        {
            client.DefaultRequestHeaders.Add(DevUserAuthenticationHandler.EmailHeader, email);
        }

        return client;
    }

    /// <summary>The keys in storage under <paramref name="prefix"/> (a household's files are under "&lt;household id&gt;/").</summary>
    public async Task<List<string>> StorageKeysAsync(string prefix)
    {
        using var s3 = new AmazonS3Client(new BasicAWSCredentials(AccessKey, SecretKey), new AmazonS3Config
        {
            ServiceURL = $"http://{_storage.Hostname}:{_storage.GetMappedPublicPort(S3Port)}",
            ForcePathStyle = true,
            AuthenticationRegion = "us-east-1",
            RequestChecksumCalculation = RequestChecksumCalculation.WHEN_REQUIRED,
            ResponseChecksumValidation = ResponseChecksumValidation.WHEN_REQUIRED,
        });
        var listed = await s3.ListObjectsV2Async(new ListObjectsV2Request { BucketName = "collarbell", Prefix = prefix });
        return [.. (listed.S3Objects ?? []).Select(o => o.Key)];
    }

    public async Task RunStorageCleanupAsync()
    {
        await using var scope = Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<StorageCleanup>().RunOnceAsync(CancellationToken.None);
    }

    /// <summary>SeaweedFS is ready once its master sees a volume server.</summary>
    private static async Task<bool> HasVolumesAsync(HttpResponseMessage response)
    {
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return json.RootElement.TryGetProperty("Topology", out var topology)
            && topology.TryGetProperty("Max", out var max)
            && max.GetInt64() > 0;
    }
}

[CollectionDefinition(Name)]
public sealed class ApiCollection : ICollectionFixture<ApiFactory>
{
    public const string Name = "api";
}
