using System.ClientModel;
using System.Collections.Concurrent;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Options;
using OllamaSharp;
using OpenAI;

namespace Collarbell.Api.Modules.Ai;

/// <summary>Makes a chat client for one model. All providers look the same afterwards: <see cref="IChatClient"/>.</summary>
public interface IAiChatClientFactory
{
    /// <summary>Whether the provider has what it needs (a key, an address) to be tried at all.</summary>
    bool IsConfigured(AiModelRef model);

    IChatClient Create(AiModelRef model);
}

/// <summary>The real factory. Clients are kept per model: each holds its own HTTP connections.</summary>
public sealed class AiChatClientFactory(IOptions<AiOptions> options) : IAiChatClientFactory, IDisposable
{
    /// <summary>
    /// The SDKs give up after 100 seconds by default. <see cref="AiRunner"/> sets the limit for each attempt
    /// itself, so theirs is only a backstop.
    /// </summary>
    private static readonly TimeSpan ProviderTimeout = TimeSpan.FromMinutes(10);

    private readonly ConcurrentDictionary<string, IChatClient> _clients = new();

    public bool IsConfigured(AiModelRef model) => model.Provider switch
    {
        AiProvider.Gemini => !string.IsNullOrWhiteSpace(options.Value.Gemini.ApiKey),
        AiProvider.OpenAICompatible => Uri.IsWellFormedUriString(options.Value.OpenAICompatible.Endpoint, UriKind.Absolute),
        AiProvider.Ollama => Uri.IsWellFormedUriString(options.Value.Ollama.Endpoint, UriKind.Absolute),
        _ => false,
    };

    public IChatClient Create(AiModelRef model) =>
        _clients.GetOrAdd(model.ToString(), _ => model.Provider switch
        {
            AiProvider.Gemini =>
                new Google.GenAI.Client(
                        apiKey: options.Value.Gemini.ApiKey,
                        httpOptions: new Google.GenAI.Types.HttpOptions { Timeout = (int)ProviderTimeout.TotalMilliseconds })
                    .AsIChatClient(model.Model),
            AiProvider.OpenAICompatible =>
                new OpenAIClient(
                        new ApiKeyCredential(options.Value.OpenAICompatible.ApiKey ?? "not-needed"),
                        new OpenAIClientOptions
                        {
                            Endpoint = new Uri(options.Value.OpenAICompatible.Endpoint!),
                            NetworkTimeout = ProviderTimeout,
                        })
                    .GetChatClient(model.Model)
                    .AsIChatClient(),
            AiProvider.Ollama =>
                new OllamaApiClient(
                    new HttpClient { BaseAddress = new Uri(options.Value.Ollama.Endpoint!), Timeout = ProviderTimeout },
                    model.Model),
            _ => throw new ArgumentOutOfRangeException(nameof(model), model.Provider, "Unknown AI provider."),
        });

    public void Dispose()
    {
        foreach (var client in _clients.Values)
        {
            client.Dispose();
        }
    }
}
