import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_provider_config.dart';

class CoachTestResult {
  final bool ok;
  final String message;
  final int? statusCode;
  final int? durationMs;

  const CoachTestResult.success(this.message, {required this.durationMs})
      : ok = true,
        statusCode = 200;

  const CoachTestResult.failure(
    this.message, {
    this.statusCode,
    required this.durationMs,
  }) : ok = false;
}

/// Minimal connectivity test for a remote AI coach endpoint.
/// Branches on `config.responseShape` so the same test works for
/// OpenAI-shape providers (CommandCode, OpenRouter, OpenCode) and Gemini.
class CoachTester {
  Future<CoachTestResult> ping({
    required AIProviderConfig config,
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    final started = DateTime.now();
    if (baseUrl.trim().isEmpty) {
      return const CoachTestResult.failure(
        'Base URL is empty.',
        durationMs: 0,
      );
    }
    if (apiKey.trim().isEmpty) {
      return const CoachTestResult.failure(
        'API key is empty.',
        durationMs: 0,
      );
    }
    if (model.trim().isEmpty) {
      return const CoachTestResult.failure(
        'Model is empty.',
        durationMs: 0,
      );
    }

    final isGemini = config.responseShape == ResponseShape.gemini;
    final uri = isGemini
        ? Uri.parse(
            '$baseUrl/models/${Uri.encodeComponent(model)}:generateContent?key=$apiKey')
        : Uri.parse('$baseUrl/chat/completions');

    final body = isGemini
        ? {
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {
                    'text':
                        'You are a connectivity test. Reply with the single word OK.\n\nping'
                  }
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.0,
              // Gemini 2.5+ "thinking" models burn output tokens on
              // reasoning; disable thinking unless the model requires it,
              // and leave room for the reply token.
              if (!model.toLowerCase().contains('thinking'))
                'thinkingConfig': {'thinkingBudget': 0},
              'maxOutputTokens': 64,
            },
          }
        : {
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are a connectivity test. Reply with the single word OK.',
              },
              {'role': 'user', 'content': 'ping'},
            ],
            'temperature': 0.0,
            'max_tokens': 4,
          };

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (config.authKind == AuthKind.bearerHeader && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    try {
      final response = await http
          .post(uri, headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 15));

      final ms = DateTime.now().difference(started).inMilliseconds;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final content = isGemini
            ? _extractGeminiText(decoded)
            : (decoded['choices']?[0]?['message']?['content'] as String?);
        if (content == null) {
          return CoachTestResult.failure(
            '200 OK but no message in response. If this is a Gemini '
            '"thinking" model, it likely spent its whole response budget on '
            'reasoning. Pick a non-thinking model (e.g. '
            '${kAIProviders[AIProvider.google]!.defaultModel}).',
            statusCode: 200,
            durationMs: ms,
          );
        }
        return CoachTestResult.success(
          'Connected (${ms}ms). Model replied: ${content.trim()}',
          durationMs: ms,
        );
      }

      String detail = response.body;
      if (detail.length > 200) detail = '${detail.substring(0, 200)}…';
      return CoachTestResult.failure(
        '${response.statusCode}: $detail',
        statusCode: response.statusCode,
        durationMs: ms,
      );
    } on Exception catch (e) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      return CoachTestResult.failure(
        'Network error: $e',
        durationMs: ms,
      );
    }
  }

  static String? _extractGeminiText(dynamic decoded) {
    try {
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final first = candidates.first as Map<String, dynamic>;
      final content = first['content'] as Map<String, dynamic>?;
      if (content == null) return null;
      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      final texts = <String>[];
      for (final p in parts) {
        final t = (p as Map<String, dynamic>)['text'] as String?;
        if (t != null) texts.add(t);
      }
      return texts.isEmpty ? null : texts.join();
    } catch (_) {
      return null;
    }
  }
}
