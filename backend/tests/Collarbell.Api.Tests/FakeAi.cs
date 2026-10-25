using Collarbell.Api.Modules.Ai;
using Microsoft.Extensions.AI;

namespace Collarbell.Api.Tests;

/// <summary>
/// Stands in for the AI providers in tests: each test says what the "model" answers, or throws. Tests in the
/// API collection run one after another, so they can share it.
/// </summary>
public sealed class FakeAi : IAiChatClientFactory
{
    public const string EmptyScan = """{"records":[],"identifiers":[],"passport":null}""";

    public bool Configured { get; set; } = true;

    /// <summary>What the model with this name answers (JSON), or an exception to throw.</summary>
    public Func<string, string> Answer { get; set; } = _ => EmptyScan;

    /// <summary>Models that never answer, like a busy one that hangs instead of saying so.</summary>
    public Func<string, bool> Hangs { get; set; } = _ => false;

    /// <summary>The models asked, in order.</summary>
    public List<string> Asked { get; } = [];

    /// <summary>The text of each request's messages, in order: what the model was told.</summary>
    public List<string> Prompts { get; } = [];

    public void Reset()
    {
        Configured = true;
        Answer = _ => EmptyScan;
        Hangs = _ => false;
        Asked.Clear();
        Prompts.Clear();
    }

    public bool IsConfigured(AiModelRef model) => Configured;

    public IChatClient Create(AiModelRef model) => new Client(this, model.Model);

    private sealed class Client(FakeAi owner, string model) : IChatClient
    {
        public async Task<ChatResponse> GetResponseAsync(
            IEnumerable<ChatMessage> messages, ChatOptions? options = null, CancellationToken cancellationToken = default)
        {
            owner.Asked.Add(model);
            owner.Prompts.Add(string.Join("\n", messages.SelectMany(m => m.Contents).OfType<TextContent>().Select(t => t.Text)));
            if (owner.Hangs(model))
            {
                await Task.Delay(Timeout.Infinite, cancellationToken);
            }

            var json = owner.Answer(model);
            return new ChatResponse(new ChatMessage(ChatRole.Assistant, json))
            {
                FinishReason = ChatFinishReason.Stop,
                Usage = new UsageDetails { InputTokenCount = 1000, OutputTokenCount = 100 },
            };
        }

        public IAsyncEnumerable<ChatResponseUpdate> GetStreamingResponseAsync(
            IEnumerable<ChatMessage> messages, ChatOptions? options = null, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public object? GetService(Type serviceType, object? serviceKey = null) => null;

        public void Dispose()
        {
        }
    }
}
