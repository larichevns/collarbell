using System.Data.Common;
using Amazon.Runtime;
using Amazon.S3;
using Amazon.S3.Model;
using Microsoft.Extensions.Options;

namespace Collarbell.Api.Infrastructure.Storage;

/// <summary>
/// Object storage settings. The endpoint and keys come from the connection string <c>storage</c>
/// (<c>Endpoint=…;AccessKey=…;SecretKey=…</c>): SeaweedFS from the AppHost locally, Cloudflare R2 in production.
/// </summary>
public sealed class StorageOptions
{
    public const string ConnectionStringName = "storage";

    public string Bucket { get; set; } = "collarbell";

    /// <summary>Region used to sign requests; R2 expects <c>auto</c>.</summary>
    public string Region { get; set; } = "us-east-1";

    /// <summary>
    /// The address phones download files from, when it differs from the endpoint the API uses
    /// (for example the Mac's LAN address when a real phone runs the app in development).
    /// </summary>
    public string? PublicEndpoint { get; set; }

    /// <summary>How long download links stay valid.</summary>
    public TimeSpan LinkLifetime { get; set; } = TimeSpan.FromMinutes(15);

    /// <summary>How often removed files are deleted from storage; zero turns the background cleanup off.</summary>
    public TimeSpan CleanupInterval { get; set; } = TimeSpan.FromMinutes(1);
}

/// <summary>
/// S3-compatible storage with one private bucket. The API uploads and deletes objects;
/// phones download them through short-lived signed links.
/// </summary>
public sealed class ObjectStorage : IDisposable
{
    private readonly StorageOptions _options;
    private readonly TimeProvider _clock;
    private readonly AmazonS3Client _client;
    private readonly AmazonS3Client _linkSigner;
    private readonly Protocol _linkProtocol;

    public ObjectStorage(IConfiguration config, IOptions<StorageOptions> options, TimeProvider clock)
    {
        _options = options.Value;
        _clock = clock;

        var connectionString = config.GetConnectionString(StorageOptions.ConnectionStringName)
            ?? throw new InvalidOperationException(
                $"Object storage is not configured: set the connection string '{StorageOptions.ConnectionStringName}'.");
        var parts = new DbConnectionStringBuilder { ConnectionString = connectionString };
        var endpoint = Required(parts, "Endpoint");
        var credentials = new BasicAWSCredentials(Required(parts, "AccessKey"), Required(parts, "SecretKey"));

        _client = new AmazonS3Client(credentials, CreateConfig(endpoint));

        // Links are signed for the address the phone uses. Signing happens locally, without a request.
        var publicEndpoint = _options.PublicEndpoint ?? endpoint;
        _linkSigner = new AmazonS3Client(credentials, CreateConfig(publicEndpoint));
        _linkProtocol = publicEndpoint.StartsWith("https://", StringComparison.OrdinalIgnoreCase) ? Protocol.HTTPS : Protocol.HTTP;
    }

    public static bool IsConfigured(IConfiguration config) =>
        !string.IsNullOrWhiteSpace(config.GetConnectionString(StorageOptions.ConnectionStringName));

    public async Task PutAsync(string key, byte[] content, string contentType, CancellationToken ct)
    {
        using var stream = new MemoryStream(content, writable: false);
        await _client.PutObjectAsync(new PutObjectRequest
        {
            BucketName = _options.Bucket,
            Key = key,
            InputStream = stream,
            ContentType = contentType,
            // Plain signed upload: chunked uploads aren't supported by every S3-compatible store.
            UseChunkEncoding = false,
        }, ct);
    }

    public async Task<byte[]> GetAsync(string key, CancellationToken ct) =>
        await TryGetAsync(key, ct) ?? throw new FileNotFoundException($"Storage object {key} is missing.");

    /// <summary>The object's bytes, or null when the object is gone.</summary>
    public async Task<byte[]?> TryGetAsync(string key, CancellationToken ct)
    {
        try
        {
            using var response = await _client.GetObjectAsync(_options.Bucket, key, ct);
            using var content = new MemoryStream();
            await response.ResponseStream.CopyToAsync(content, ct);
            return content.ToArray();
        }
        catch (AmazonS3Exception e) when (e.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    /// <summary>Deletes an object. Deleting a missing object is not an error.</summary>
    public Task DeleteAsync(string key, CancellationToken ct) =>
        _client.DeleteObjectAsync(_options.Bucket, key, ct);

    /// <summary>A link that lets anyone holding it download the object until it expires.</summary>
    public (string Url, DateTimeOffset ExpiresAt) GetDownloadLink(string key)
    {
        var expiresAt = _clock.GetUtcNow() + _options.LinkLifetime;
        var url = _linkSigner.GetPreSignedURL(new GetPreSignedUrlRequest
        {
            BucketName = _options.Bucket,
            Key = key,
            Verb = HttpVerb.GET,
            Expires = expiresAt.UtcDateTime,
            Protocol = _linkProtocol,
        });
        return (url, expiresAt);
    }

    /// <summary>Creates the bucket if it doesn't exist (local and test storage). Waits for storage that is still starting.</summary>
    public async Task EnsureBucketAsync(CancellationToken ct)
    {
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                await _client.PutBucketAsync(new PutBucketRequest { BucketName = _options.Bucket }, ct);
                return;
            }
            catch (AmazonS3Exception e) when (e.ErrorCode is "BucketAlreadyOwnedByYou" or "BucketAlreadyExists")
            {
                return;
            }
            catch (Exception e) when (attempt < 30 && e is not OperationCanceledException)
            {
                await Task.Delay(TimeSpan.FromSeconds(1), ct);
            }
        }
    }

    public void Dispose()
    {
        _client.Dispose();
        _linkSigner.Dispose();
    }

    private AmazonS3Config CreateConfig(string serviceUrl) => new()
    {
        ServiceURL = serviceUrl,
        ForcePathStyle = true,
        AuthenticationRegion = _options.Region,
        // SeaweedFS and R2 don't support all checksums the SDK sends by default.
        RequestChecksumCalculation = RequestChecksumCalculation.WHEN_REQUIRED,
        ResponseChecksumValidation = ResponseChecksumValidation.WHEN_REQUIRED,
    };

    private static string Required(DbConnectionStringBuilder parts, string key) =>
        parts.TryGetValue(key, out var value) && value is string { Length: > 0 } text
            ? text
            : throw new InvalidOperationException($"The storage connection string has no {key}.");
}

public static class StorageSetup
{
    public static IServiceCollection AddObjectStorage(this IServiceCollection services, IConfiguration config)
    {
        services.Configure<StorageOptions>(config.GetSection("Storage"));
        services.AddSingleton<ObjectStorage>();
        return services;
    }
}
