import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/services/ai/ai_provider_config.dart';

void main() {
  group('AIProviderConfig — Google (Gemini)', () {
    test('google entry exists and uses query-param auth + Gemini shape', () {
      final config = kAIProviders[AIProvider.google];
      expect(config, isNotNull, reason: 'AIProvider.google must be configured');
      expect(config!.displayName, contains('Gemini'));
      expect(config.authKind, AuthKind.apiKeyQuery,
          reason: 'Google needs the key on the URL, not a Bearer header');
      expect(config.responseShape, ResponseShape.gemini,
          reason: 'Google needs native Gemini request/response parsing');
      expect(config.defaultBaseUrl, contains('generativelanguage'));
      expect(config.defaultModel, isNotEmpty);
      expect(config.defaultModel!.startsWith('gemini-'), isTrue);
    });

    test('presetsFor(google) returns current free Gemini models', () {
      final presets = presetsFor(AIProvider.google);
      expect(presets, isNotEmpty);
      expect(presets.any((p) => p.id == 'gemini-3.5-flash'), isTrue,
          reason: 'Default model must be present');
      // The new Gemini 3 Flash preview is the user's most-asked-about model.
      expect(presets.any((p) => p.id == 'gemini-3-flash-preview'), isTrue,
          reason: 'Gemini 3 Flash preview must be offered as a free option');
      expect(presets.every((p) => p.family == 'Google'), isTrue);
    });

    test('non-Google providers keep OpenAI-shape defaults', () {
      for (final p in [AIProvider.commandcode, AIProvider.opencode, AIProvider.openrouter]) {
        final c = kAIProviders[p]!;
        expect(c.authKind, AuthKind.bearerHeader, reason: '$p auth');
        expect(c.responseShape, ResponseShape.openaiChat, reason: '$p shape');
      }
    });
  });

  group('AIProviderConfig — OpenRouter free models are real', () {
    // IDs verified against openrouter.ai/api/v1/models on 2026-09-03.
    // Anything not on this list shipped in older audits has been removed.
    test('every OpenRouter preset exists on the live catalog', () {
      final presets = presetsFor(AIProvider.openrouter);
      expect(presets, isNotEmpty);
      final liveFree = <String>{
        'minimax/minimax-m3:free',
        'qwen/qwen3.8-flash',
        'qwen/qwen3.7-flash',
        'nvidia/nemotron-3-ultra-550b-a55b:free',
        'nvidia/nemotron-3.5-lightning:free',
        'z-ai/glm-5.2:free',
        'thinkingmachines/inkling:free',
        'poolside/laguna-s-2.1:free',
        'liquid/lfm-2.5-2.6b:free',
      };
      for (final p in presets) {
        expect(liveFree.contains(p.id), isTrue,
            reason:
                'OpenRouter preset "${p.id}" is not on the live catalog; remove it.');
      }
    });

    test("the user's working default is preserved (minimax-m3:free)", () {
      final presets = presetsFor(AIProvider.openrouter);
      expect(presets.first.id, 'minimax/minimax-m3:free',
          reason: 'Default OpenRouter model must remain the one that works');
    });
  });

  group('AIProviderConfig — CommandCode entries all exist', () {
    // ID set pulled from commandcode.ai/docs/reference/cli/models on 2026-09-03.
    // We check that every preset is in the verified CommandCode catalog.
    test('every CommandCode preset is on the official catalog', () {
      final liveCommandCode = <String>{
        // Qwen
        'Qwen/Qwen3.6-Max-Preview',
        'Qwen/Qwen3.6-Plus',
        'Qwen/Qwen3.7-Flash',
        'Qwen/Qwen3.7-Max',
        'Qwen/Qwen3.7-Plus',
        'Qwen/Qwen3.8-27B',
        'Qwen/Qwen3.8-Flash',
        'Qwen/Qwen3.8-Max',
        'Qwen/Qwen3.8-Max-0902',
        // DeepSeek
        'deepseek/deepseek-v4-flash',
        'deepseek/deepseek-v4-flash-fast',
        'deepseek/deepseek-v4-flash-vision-exp',
        'deepseek/deepseek-v4-pro',
        // Gemini
        'google/gemini-3.1-flash-lite',
        'google/gemini-3.5-flash',
        'google/gemini-3.5-flash-lite',
        'google/gemini-3.6-flash',
        'google/gemini-3.7-flash',
        'google/gemini-3.8-flash',
        // MiniMax
        'MiniMaxAI/MiniMax-M2.5',
        'MiniMaxAI/MiniMax-M2.7',
        'MiniMaxAI/MiniMax-M3',
        // OpenAI
        'gpt-5.3-codex',
        'gpt-5.4',
        'gpt-5.4-mini',
        'gpt-5.5',
        'gpt-5.6-luna',
        'gpt-5.6-sol',
        'gpt-5.6-terra',
      };
      final presets = presetsFor(AIProvider.commandcode);
      expect(presets, isNotEmpty);
      for (final p in presets) {
        expect(liveCommandCode.contains(p.id), isTrue,
            reason:
                'CommandCode preset "${p.id}" is not on the live catalog; remove it.');
      }
    });
  });
}
