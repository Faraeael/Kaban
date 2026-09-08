enum AIProvider { local, commandcode, opencode, openrouter, google }

/// How the API key travels with each request.
enum AuthKind {
  /// Send `Authorization: Bearer <key>` header (OpenAI-shape providers).
  bearerHeader,

  /// Send `<key>` as a query-param on the URL (Google Gemini).
  apiKeyQuery,
}

/// How requests and responses are shaped. OpenAI-shape providers share a
/// single implementation; Gemini gets its own because its body, URL
/// structure, and response parsing are all different.
enum ResponseShape { openaiChat, gemini }

class AIProviderConfig {
  final AIProvider provider;
  final String displayName;
  final String? defaultBaseUrl;
  final String? defaultModel;
  final String docsHint;
  final AuthKind authKind;
  final ResponseShape responseShape;

  const AIProviderConfig({
    required this.provider,
    required this.displayName,
    this.defaultBaseUrl,
    this.defaultModel,
    required this.docsHint,
    this.authKind = AuthKind.bearerHeader,
    this.responseShape = ResponseShape.openaiChat,
  });
}

const Map<AIProvider, AIProviderConfig> kAIProviders = {
  AIProvider.local: AIProviderConfig(
    provider: AIProvider.local,
    displayName: 'Local (offline)',
    docsHint: 'No setup needed. Uses on-device rules. Works fully offline.',
  ),
  AIProvider.commandcode: AIProviderConfig(
    provider: AIProvider.commandcode,
    displayName: 'CommandCode',
    defaultBaseUrl: 'https://api.commandcode.ai/provider/v1',
    defaultModel: 'gpt-5.4-mini',
    docsHint:
        'OpenAI-compatible chat completions. Requires Provider plan or higher '
        '(api.commandcode.ai/billing). Default model: gpt-5.4-mini.',
  ),
  AIProvider.opencode: AIProviderConfig(
    provider: AIProvider.opencode,
    displayName: 'OpenCode',
    docsHint:
        "Uses OpenCode's OpenAI-compatible API. Paste your OpenCode API key below. Base URL and model can be customized if needed.",
  ),
  AIProvider.openrouter: AIProviderConfig(
    provider: AIProvider.openrouter,
    displayName: 'OpenRouter',
    defaultBaseUrl: 'https://openrouter.ai/api/v1',
    defaultModel: 'minimax/minimax-m3:free',
    docsHint:
        "Uses OpenRouter's OpenAI-compatible API. Free models tagged ':free' "
        'work without a paid plan. Get an API key at openrouter.ai/keys.',
  ),
  AIProvider.google: AIProviderConfig(
    provider: AIProvider.google,
    displayName: 'Google (Gemini)',
    defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    defaultModel: 'gemini-3.5-flash',
    authKind: AuthKind.apiKeyQuery,
    responseShape: ResponseShape.gemini,
    docsHint:
        "Google's Gemini API. Get a free API key at aistudio.google.com/apikey. "
        "Free tier has rate limits per minute; the app uses Gemini 3.5 Flash by default.",
  ),
};

class ModelPreset {
  final String id;
  final String name;
  final String tagline;
  final String family;
  const ModelPreset({
    required this.id,
    required this.name,
    required this.tagline,
    required this.family,
  });
}

/// Curated models per provider. Anthropic-shape claude-* models are
/// excluded — the app's RemoteCoach uses the OpenAI shape.
const Map<AIProvider, List<ModelPreset>> kModelPresetsByProvider = {
  AIProvider.commandcode: [
    ModelPreset(
      id: 'gpt-5.4-mini',
      name: 'GPT-5.4 Mini',
      tagline: 'Fast, cheap, solid defaults. Best for everyday questions.',
      family: 'OpenAI',
    ),
    ModelPreset(
      id: 'gpt-5.5',
      name: 'GPT-5.5',
      tagline: 'Newer flagship. Better reasoning, slower, pricier.',
      family: 'OpenAI',
    ),
    ModelPreset(
      id: 'gpt-5.4',
      name: 'GPT-5.4',
      tagline: 'Slightly smarter than Mini. Middle ground.',
      family: 'OpenAI',
    ),
    ModelPreset(
      id: 'Qwen/Qwen3.8-Flash',
      name: 'Qwen 3.8 Flash',
      tagline: 'Strong multilingual. Works well with Tagalog / Filipino.',
      family: 'Qwen',
    ),
    ModelPreset(
      id: 'Qwen/Qwen3.7-Flash',
      name: 'Qwen 3.7 Flash',
      tagline: 'Previous generation Qwen. Cheaper, still capable.',
      family: 'Qwen',
    ),
    ModelPreset(
      id: 'deepseek/deepseek-v4-flash',
      name: 'DeepSeek V4 Flash',
      tagline: 'Very strong on math + structured reasoning.',
      family: 'DeepSeek',
    ),
    ModelPreset(
      id: 'MiniMaxAI/MiniMax-M3',
      name: 'MiniMax M3',
      tagline: 'Current flagship. 1M context, strong reasoning.',
      family: 'MiniMax',
    ),
    ModelPreset(
      id: 'MiniMaxAI/MiniMax-M2.7',
      name: 'MiniMax M2.7',
      tagline: 'Previous generation. Cheaper, still capable.',
      family: 'MiniMax',
    ),
    ModelPreset(
      id: 'MiniMaxAI/MiniMax-M2.5',
      name: 'MiniMax M2.5',
      tagline: 'Older generation. Lowest cost of the three.',
      family: 'MiniMax',
    ),
  ],
  AIProvider.openrouter: [
    ModelPreset(
      id: 'minimax/minimax-m3:free',
      name: 'MiniMax M3 (free)',
      tagline: 'Top-tier reasoning. 1M context. Free.',
      family: 'MiniMax',
    ),
    ModelPreset(
      id: 'qwen/qwen3.8-flash',
      name: 'Qwen 3.8 Flash (free)',
      tagline: 'Qwen multimodal reasoning. Fast and capable, free tier.',
      family: 'Qwen',
    ),
    ModelPreset(
      id: 'qwen/qwen3.7-flash',
      name: 'Qwen 3.7 Flash (free)',
      tagline: 'Cheapest free Qwen Flash. Great everyday default.',
      family: 'Qwen',
    ),
    ModelPreset(
      id: 'nvidia/nemotron-3-ultra-550b-a55b:free',
      name: 'Nemotron 3 Ultra (free)',
      tagline: 'NVIDIA flagship. 1M context. Strong reasoning.',
      family: 'NVIDIA',
    ),
    ModelPreset(
      id: 'nvidia/nemotron-3.5-lightning:free',
      name: 'Nemotron 3.5 Lightning (free)',
      tagline: 'Lighter NVIDIA MoE. Fast agentic throughput.',
      family: 'NVIDIA',
    ),
    ModelPreset(
      id: 'z-ai/glm-5.2:free',
      name: 'GLM 5.2 (free)',
      tagline: "Z.ai's flagship. Bilingual EN/CN.",
      family: 'Z.ai',
    ),
    ModelPreset(
      id: 'thinkingmachines/inkling:free',
      name: 'Inkling (free)',
      tagline: "Thinking Machines' open-weights model.",
      family: 'Thinking Machines',
    ),
    ModelPreset(
      id: 'poolside/laguna-s-2.1:free',
      name: 'Laguna S 2.1 (free)',
      tagline: "Poolside's model. Tuned for code + reasoning.",
      family: 'Poolside',
    ),
    ModelPreset(
      id: 'liquid/lfm-2.5-2.6b:free',
      name: 'LFM 2.5 2.6B (free)',
      tagline: 'Tiny model. Fastest responses, basic reasoning.',
      family: 'LiquidAI',
    ),
  ],
  AIProvider.opencode: [],
  AIProvider.google: [
    ModelPreset(
      id: 'gemini-3.5-flash',
      name: 'Gemini 3.5 Flash',
      tagline:
          "Google's free stable Flash. Default — fast multimodal with strong reasoning.",
      family: 'Google',
    ),
    ModelPreset(
      id: 'gemini-3-flash-preview',
      name: 'Gemini 3 Flash (preview)',
      tagline:
          'Newest preview. Free tier but model name may change without notice.',
      family: 'Google',
    ),
    ModelPreset(
      id: 'gemini-3.5-flash-lite',
      name: 'Gemini 3.5 Flash Lite',
      tagline:
          'Cheapest Flash. Fastest responses for short, simple answers.',
      family: 'Google',
    ),
    ModelPreset(
      id: 'gemini-3.1-flash-lite',
      name: 'Gemini 3.1 Flash Lite',
      tagline:
          'Frontier-class perf at lite cost. Free tier, 1M context.',
      family: 'Google',
    ),
  ],
};

final List<ModelPreset> kModelPresets = kModelPresetsByProvider[AIProvider.commandcode]!;

List<ModelPreset> presetsFor(AIProvider provider) =>
    kModelPresetsByProvider[provider] ?? const [];

ModelPreset? findModelPreset(String id) {
  for (final list in kModelPresetsByProvider.values) {
    for (final m in list) {
      if (m.id == id) return m;
    }
  }
  return null;
}
