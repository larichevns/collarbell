using System.Text.Json.Serialization;
using Microsoft.Extensions.AI;

namespace Collarbell.Api.Modules.Ai;

[JsonConverter(typeof(JsonStringEnumConverter<AiProvider>))]
public enum AiProvider
{
    /// <summary>Google Gemini through the official Google.GenAI SDK.</summary>
    Gemini,

    /// <summary>Any provider with an OpenAI-style API: Groq, OpenRouter, Mistral and others.</summary>
    OpenAICompatible,

    /// <summary>A local model on this computer (ollama.com).</summary>
    Ollama,
}

public sealed class AiModelRef
{
    public AiProvider Provider { get; set; }

    public string Model { get; set; } = "";

    public override string ToString() => $"{Provider}/{Model}";
}

/// <summary>
/// The <c>Ai</c> settings section. Keys are never in the repo: the Gemini key comes from the AppHost's secret
/// parameter <c>gemini-api-key</c> (user secrets on the developer's Mac, a secret on the server).
/// </summary>
public sealed class AiOptions
{
    /// <summary>The profile used to read passport pages.</summary>
    public const string Extraction = "extraction";

    /// <summary>
    /// For each task, the models to try in order. When one is busy, out of free quota or gone, the next one
    /// answers instead (spec 5.5).
    /// </summary>
    public Dictionary<string, List<AiModelRef>> Profiles { get; set; } = [];

    /// <summary>
    /// How long one model may take before the next one is asked: this, plus <see cref="AttemptTimeoutPerImage"/>
    /// for each photo sent. A busy model sometimes hangs instead of saying so. Raise both for a slow local model.
    /// </summary>
    public TimeSpan AttemptTimeout { get; set; } = TimeSpan.FromSeconds(40);

    public TimeSpan AttemptTimeoutPerImage { get; set; } = TimeSpan.FromSeconds(10);

    /// <summary>
    /// How much the models think before they answer: <c>Low</c>, <c>Medium</c> or <c>High</c>; unset leaves it to each
    /// model. Thinking is billed as output and can cost more than the answer itself. Every model of every profile must
    /// accept the level: a model that can't think would refuse the request.
    /// </summary>
    public ReasoningEffort? Thinking { get; set; }

    /// <summary>
    /// Notes one person may have AI read in a day. A note costs no AI photos (its tokens are a fraction of a photo's),
    /// but every request goes through the server's key.
    /// </summary>
    public int TextEntriesPerDay { get; set; } = 30;

    public GeminiOptions Gemini { get; set; } = new();

    public OpenAICompatibleOptions OpenAICompatible { get; set; } = new();

    public OllamaOptions Ollama { get; set; } = new();
}

public sealed class GeminiOptions
{
    public string? ApiKey { get; set; }

    /// <summary>
    /// On the free tier Google may use what is sent to improve its products; the app shows a warning.
    /// </summary>
    public bool FreeTier { get; set; } = true;
}

public sealed class OpenAICompatibleOptions
{
    public string? Endpoint { get; set; }

    public string? ApiKey { get; set; }
}

public sealed class OllamaOptions
{
    public string? Endpoint { get; set; }
}
