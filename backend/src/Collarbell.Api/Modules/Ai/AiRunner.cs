using System.ClientModel;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Json.Serialization.Metadata;
using Collarbell.Api.Infrastructure.Persistence;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Options;

namespace Collarbell.Api.Modules.Ai;

/// <summary>What an AI call returned and which model answered.</summary>
public sealed record AiResult<T>(T Value, AiModelRef Model);

/// <summary>No model could answer: none is set up, or all of them are busy or out of quota right now.</summary>
public sealed class AiUnavailableException(string message, Exception? inner = null) : Exception(message, inner)
{
    public bool NotConfigured { get; init; }
}

/// <summary>The provider refused the request itself (a wrong key, a request it can't handle): retrying won't help.</summary>
public sealed class AiRejectedException(string message, Exception inner) : Exception(message, inner);

/// <summary>One AI call (or one attempt of a chain), for the monthly usage on the AI screen.</summary>
public sealed class AiUsage
{
    private AiUsage()
    {
    }

    public AiUsage(Guid householdId, string feature, AiModelRef model, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        Feature = feature;
        Provider = model.Provider;
        Model = model.Model;
        CreatedAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public string Feature { get; private set; } = null!;

    public AiProvider Provider { get; private set; }

    public string Model { get; private set; } = null!;

    public long? InputTokens { get; private set; }

    /// <summary>Billed as output: the answer and the model's thinking. Gemini's thinking is in it since 2026-10-14.</summary>
    public long? OutputTokens { get; private set; }

    /// <summary>The part of <see cref="OutputTokens"/> the model spent thinking before it answered.</summary>
    public long? ReasoningTokens { get; private set; }

    public int LatencyMs { get; set; }

    public bool Success { get; set; }

    public DateTimeOffset CreatedAt { get; private set; }

    /// <summary>
    /// Notes what the call used. Gemini's SDK reports the thinking apart from the answer, though Google bills it as
    /// output; OpenAI-style APIs count it in the output already.
    /// </summary>
    public void Count(UsageDetails? usage)
    {
        InputTokens = usage?.InputTokenCount;
        ReasoningTokens = usage?.ReasoningTokenCount;
        OutputTokens = Provider == AiProvider.Gemini && usage?.ReasoningTokenCount is { } thinking
            ? usage.OutputTokenCount.GetValueOrDefault() + thinking
            : usage?.OutputTokenCount;
    }
}

/// <summary>
/// Runs one structured AI request through a profile's chain of models: the first model that answers wins.
/// The answer must match <typeparamref name="T"/>'s JSON schema, which is sent along with the request.
/// </summary>
public sealed class AiRunner(
    IAiChatClientFactory clients,
    IOptions<AiOptions> options,
    AppDbContext db,
    TimeProvider clock,
    ILogger<AiRunner> log)
{
    /// <summary>Generous: "thinking" counts as output too, and a cut-off answer is broken JSON (spec 5.5).</summary>
    private const int MaxOutputTokens = 16384;

    /// <summary>Enums as their names, so the schema lists the allowed values and the model must pick one.</summary>
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() },
        TypeInfoResolver = new DefaultJsonTypeInfoResolver(),
    };

    /// <summary>The options of every request: room for a long answer, and as much thinking as the settings ask for.</summary>
    public static ChatOptions ChatOptionsFor(AiOptions options) => new()
    {
        MaxOutputTokens = MaxOutputTokens,
        Reasoning = options.Thinking is { } effort ? new ReasoningOptions { Effort = effort } : null,
    };

    public IReadOnlyList<AiModelRef> Models(string profile) =>
        options.Value.Profiles.TryGetValue(profile, out var models) ? models : [];

    public bool IsConfigured(string profile) => Models(profile).Any(clients.IsConfigured);

    public async Task<AiResult<T>> RunAsync<T>(
        string profile, string feature, Guid householdId, IList<ChatMessage> messages, CancellationToken ct)
    {
        Exception? lastProblem = null;
        var timeout = AttemptTimeout(options.Value, messages);
        foreach (var model in Models(profile).Where(clients.IsConfigured))
        {
            var usage = new AiUsage(householdId, feature, model, clock.GetUtcNow());
            db.AiUsage.Add(usage);
            var watch = Stopwatch.StartNew();
            using var attempt = CancellationTokenSource.CreateLinkedTokenSource(ct);
            attempt.CancelAfter(timeout);
            try
            {
                var response = await clients.Create(model).GetResponseAsync<T>(
                    messages, Json, ChatOptionsFor(options.Value), cancellationToken: attempt.Token);
                usage.Count(response.Usage);
                if (response.TryGetResult(out var value) && value is not null)
                {
                    usage.Success = true;
                    return new AiResult<T>(value, model);
                }

                lastProblem = new InvalidDataException($"{model} gave no usable answer (finish reason: {response.FinishReason}).");
            }
            catch (OperationCanceledException e) when (!ct.IsCancellationRequested)
            {
                lastProblem = new TimeoutException($"{model} didn't answer within {timeout.TotalSeconds:0} seconds.", e);
            }
            catch (Exception e) when (!ct.IsCancellationRequested && WorthTryingTheNextModel(e))
            {
                lastProblem = e;
            }
            catch (Exception e) when (!ct.IsCancellationRequested)
            {
                throw new AiRejectedException($"{model} refused the request: {e.Message}", e);
            }
            finally
            {
                usage.LatencyMs = (int)watch.ElapsedMilliseconds;
                await db.SaveChangesAsync(CancellationToken.None);
            }

            log.LogWarning(lastProblem, "AI model {Model} didn't answer; trying the next one.", model);
        }

        throw lastProblem is null
            ? new AiUnavailableException("No AI model is set up.") { NotConfigured = true }
            : new AiUnavailableException("All AI models are busy or out of quota right now.", lastProblem);
    }

    /// <summary>How long one model may take with these messages (more photos take longer to read).</summary>
    internal static TimeSpan AttemptTimeout(AiOptions options, IEnumerable<ChatMessage> messages) =>
        options.AttemptTimeout + (options.AttemptTimeoutPerImage * messages.Sum(m => m.Contents.Count(c => c is DataContent)));

    /// <summary>
    /// Busy (5xx), out of quota (429), gone (404), unreachable, timed out or a broken answer: another model may do
    /// better. A wrong key or a bad request (400, 401, 403) fails the same way everywhere, so the chain stops.
    /// </summary>
    internal static bool WorthTryingTheNextModel(Exception e) => e switch
    {
        // The OpenAI SDK retries by itself and then wraps the failures ("Retry failed after 4 tries").
        AggregateException all => all.InnerExceptions.Any(WorthTryingTheNextModel),
        Google.GenAI.ApiException api => IsTransient(api.StatusCode),
        // Status 0: no answer at all (connection refused or reset).
        ClientResultException openAi => openAi.Status == 0 || IsTransient(openAi.Status),
        HttpRequestException http => http.StatusCode is not { } status || IsTransient((int)status),
        IOException or SocketException or TimeoutException => true,
        JsonException or InvalidDataException => true,
        _ => false,
    };

    private static bool IsTransient(int status) =>
        status is (int)HttpStatusCode.NotFound or (int)HttpStatusCode.RequestTimeout or (int)HttpStatusCode.TooManyRequests or >= 500;
}
