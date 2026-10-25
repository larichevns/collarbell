using System.ClientModel;
using System.Net;
using Collarbell.Api.Modules.Ai;
using Microsoft.Extensions.AI;

namespace Collarbell.Api.Tests;

/// <summary>Which provider failures hand over to the next model, and which stop the chain.</summary>
public sealed class AiRunnerTests
{
    public static TheoryData<Exception, bool> Failures => new()
    {
        { new HttpRequestException("busy", null, HttpStatusCode.ServiceUnavailable), true },
        { new HttpRequestException("out of quota", null, HttpStatusCode.TooManyRequests), true },
        { new HttpRequestException("no such model", null, HttpStatusCode.NotFound), true },
        { new HttpRequestException("connection refused"), true },
        { new HttpRequestException("API key not valid", null, HttpStatusCode.Unauthorized), false },
        { new HttpRequestException("bad request", null, HttpStatusCode.BadRequest), false },
        // The OpenAI SDK after its own retries: "Retry failed after 4 tries", no HTTP answer at all.
        { new AggregateException("Retry failed after 4 tries.", new ClientResultException("Connection refused")), true },
        { new AggregateException(new ClientResultException("Connection refused"), new IOException("reset")), true },
        { new IOException("connection reset"), true },
        { new TimeoutException(), true },
        { new System.Text.Json.JsonException("broken answer"), true },
        { new InvalidOperationException("a bug"), false },
    };

    [Theory]
    [MemberData(nameof(Failures))]
    public void Busy_unreachable_or_broken_moves_on_and_a_refusal_stops(Exception failure, bool tryNext)
    {
        Assert.Equal(tryNext, AiRunner.WorthTryingTheNextModel(failure));
    }

    /// <summary>Thinking is billed as output: Gemini's SDK reports it apart, OpenAI-style APIs inside the output.</summary>
    [Theory]
    [InlineData(AiProvider.Gemini, 1400)]
    [InlineData(AiProvider.OpenAICompatible, 300)]
    public void The_output_counts_the_thinking_once(AiProvider provider, long billed)
    {
        var usage = new AiUsage(Guid.NewGuid(), "passport-scan", new AiModelRef { Provider = provider, Model = "m" }, DateTimeOffset.UtcNow);

        usage.Count(new UsageDetails { InputTokenCount = 1250, OutputTokenCount = 300, ReasoningTokenCount = 1100 });

        Assert.Equal(1250, usage.InputTokens);
        Assert.Equal(billed, usage.OutputTokens);
        Assert.Equal(1100, usage.ReasoningTokens);
    }

    [Fact]
    public void Thinking_is_left_to_the_model_unless_set()
    {
        Assert.Null(AiRunner.ChatOptionsFor(new AiOptions()).Reasoning);
        Assert.Equal(ReasoningEffort.Low, AiRunner.ChatOptionsFor(new AiOptions { Thinking = ReasoningEffort.Low }).Reasoning?.Effort);
    }
}
