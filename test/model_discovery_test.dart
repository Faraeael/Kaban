import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:finance_tracker/services/ai/ai_provider_config.dart';
import 'package:finance_tracker/services/ai/model_discovery_service.dart';

void main() {
  group('ModelDiscoveryService', () {
    setUp(() {
      ModelDiscoveryService.instance.clearCache();
    });

    test('parses OpenRouter models detecting :free and image modality',
        () async {
      final mockOpenRouterPayload = jsonEncode({
        'data': [
          {
            'id': 'anthropic/claude-3.5-sonnet',
            'name': 'Claude 3.5 Sonnet',
            'description': 'Smart proprietary model.',
            'pricing': {'prompt': '0.000003', 'completion': '0.000015'},
            'architecture': {
              'modality': 'text+image->text',
              'input_modalities': ['text', 'image'],
            },
          },
          {
            'id': 'meta-llama/llama-3.3-70b-instruct:free',
            'name': 'Llama 3.3 70B (free)',
            'description': 'Open weights free tier.',
            'pricing': {'prompt': '0', 'completion': '0'},
            'architecture': {
              'modality': 'text->text',
              'input_modalities': ['text'],
            },
          },
          {
            'id': 'qwen/qwen-2.5-vl-72b-instruct:free',
            'name': 'Qwen 2.5 VL 72B (free)',
            'description': 'Vision-language model.',
            'pricing': {'prompt': '0', 'completion': '0'},
            'architecture': {
              'modality': 'text+image->text',
              'input_modalities': ['text', 'image'],
            },
          },
        ],
      });

      final mockClient = MockClient((request) async {
        if (request.url.host == 'openrouter.ai') {
          return http.Response(mockOpenRouterPayload, 200, headers: {
            'content-type': 'application/json',
          });
        }
        return http.Response('Not found', 404);
      });

      final models = await ModelDiscoveryService.instance.getModels(
        provider: AIProvider.openrouter,
        client: mockClient,
        forceRefresh: true,
      );

      expect(models.length, equals(3));

      // Check Qwen VL free model
      final qwenVl = models
          .firstWhere((m) => m.id == 'qwen/qwen-2.5-vl-72b-instruct:free');
      expect(qwenVl.isFree, isTrue);
      expect(qwenVl.supportsVision, isTrue);

      // Check Llama free model (text only)
      final llama = models
          .firstWhere((m) => m.id == 'meta-llama/llama-3.3-70b-instruct:free');
      expect(llama.isFree, isTrue);
      expect(llama.supportsVision, isFalse);

      // Check Claude paid vision model
      final claude =
          models.firstWhere((m) => m.id == 'anthropic/claude-3.5-sonnet');
      expect(claude.isFree, isFalse);
      expect(claude.supportsVision, isTrue);

      // Free models are sorted first
      expect(models[0].isFree, isTrue);
      expect(models[1].isFree, isTrue);
      expect(models[2].isFree, isFalse);
    });

    test('parses Google Gemini models and strips models/ prefix', () async {
      final mockGeminiPayload = jsonEncode({
        'models': [
          {
            'name': 'models/gemini-1.5-flash',
            'displayName': 'Gemini 1.5 Flash',
            'description': 'Fast and versatile multimodal model.',
            'supportedGenerationMethods': ['generateContent', 'countTokens'],
          },
          {
            'name': 'models/gemini-1.5-pro',
            'displayName': 'Gemini 1.5 Pro',
            'description': 'Complex reasoning multimodal model.',
            'supportedGenerationMethods': ['generateContent', 'countTokens'],
          },
          {
            'name': 'models/text-embedding-004',
            'displayName': 'Text Embedding 004',
            'description': 'Embedding only.',
            'supportedGenerationMethods': ['embedContent'],
          },
        ],
      });

      final mockClient = MockClient((request) async {
        if (request.url.host == 'generativelanguage.googleapis.com') {
          return http.Response(mockGeminiPayload, 200, headers: {
            'content-type': 'application/json',
          });
        }
        return http.Response('Not found', 404);
      });

      final models = await ModelDiscoveryService.instance.getModels(
        provider: AIProvider.google,
        apiKey: 'test-api-key',
        client: mockClient,
        forceRefresh: true,
      );

      // text-embedding-004 should be omitted because it doesn't support generateContent
      expect(models.length, equals(2));

      final flash = models.firstWhere((m) => m.id == 'gemini-1.5-flash');
      expect(flash.name, equals('Gemini 1.5 Flash'));
      expect(flash.supportsVision, isTrue);
      expect(flash.isFree, isTrue); // Flash has free quota

      final pro = models.firstWhere((m) => m.id == 'gemini-1.5-pro');
      expect(pro.name, equals('Gemini 1.5 Pro'));
      expect(pro.supportsVision, isTrue);
    });

    test('falls back to curated presets when network request fails', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final models = await ModelDiscoveryService.instance.getModels(
        provider: AIProvider.openrouter,
        client: mockClient,
        forceRefresh: true,
      );

      expect(models, isNotEmpty);
      expect(models.length,
          equals(kModelPresetsByProvider[AIProvider.openrouter]!.length));
      expect(models.any((m) => m.id == 'minimax/minimax-m3:free'), isTrue);
    });

    test('caches results and reuses them on subsequent non-force calls',
        () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'test/model:free',
                'name': 'Test Model Free',
                'pricing': {'prompt': '0', 'completion': '0'},
                'architecture': {
                  'input_modalities': ['text', 'image']
                },
              }
            ]
          }),
          200,
        );
      });

      // First call -> network request
      final first = await ModelDiscoveryService.instance.getModels(
        provider: AIProvider.openrouter,
        client: mockClient,
      );
      expect(requestCount, equals(1));
      expect(first.first.id, equals('test/model:free'));

      // Second call without forceRefresh -> from cache
      final second = await ModelDiscoveryService.instance.getModels(
        provider: AIProvider.openrouter,
        client: mockClient,
      );
      expect(requestCount, equals(1));
      expect(second.first.id, equals('test/model:free'));

      // Third call with forceRefresh -> triggers new request
      await ModelDiscoveryService.instance.getModels(
        provider: AIProvider.openrouter,
        client: mockClient,
        forceRefresh: true,
      );
      expect(requestCount, equals(2));
    });
  });
}
