import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ai_provider_config.dart';

class ModelDiscoveryService {
  static final ModelDiscoveryService instance = ModelDiscoveryService._();
  ModelDiscoveryService._();

  final Map<AIProvider, _CacheEntry> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 30);

  /// Clears in-memory model cache for a given provider or all providers.
  void clearCache([AIProvider? provider]) {
    if (provider != null) {
      _cache.remove(provider);
    } else {
      _cache.clear();
    }
  }

  /// Fetches available models from the provider's API.
  /// Falls back to curated static presets if offline, timed out, or on error.
  Future<List<ModelPreset>> getModels({
    required AIProvider provider,
    String? apiKey,
    String? baseUrl,
    bool forceRefresh = false,
    http.Client? client,
  }) async {
    // 1. Check in-memory cache
    if (!forceRefresh && _cache.containsKey(provider)) {
      final entry = _cache[provider]!;
      if (DateTime.now().difference(entry.timestamp) < _cacheTtl &&
          entry.models.isNotEmpty) {
        return entry.models;
      }
    }

    // 2. Fetch live models according to provider
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      List<ModelPreset> fetched = const [];
      switch (provider) {
        case AIProvider.openrouter:
          fetched = await _fetchOpenRouterModels(httpClient, apiKey: apiKey);
        case AIProvider.google:
          if (apiKey != null && apiKey.trim().isNotEmpty) {
            fetched =
                await _fetchGeminiModels(httpClient, apiKey: apiKey.trim());
          }
        case AIProvider.commandcode:
        case AIProvider.opencode:
          final endpoint = baseUrl?.isNotEmpty == true
              ? baseUrl!
              : kAIProviders[provider]?.defaultBaseUrl;
          if (endpoint != null && endpoint.isNotEmpty) {
            fetched = await _fetchOpenAiShapeModels(
              httpClient,
              baseUrl: endpoint,
              apiKey: apiKey,
              provider: provider,
            );
          }
        case AIProvider.local:
          fetched = const [];
      }

      if (fetched.isNotEmpty) {
        _cache[provider] = _CacheEntry(
          models: fetched,
          timestamp: DateTime.now(),
        );
        return fetched;
      }
    } catch (e) {
      debugPrint(
          '[ModelDiscoveryService] Error fetching models for $provider: $e');
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }

    // Fallback to static presets if network fetch yields nothing or fails
    final fallback = presetsFor(provider);
    return fallback;
  }

  Future<List<ModelPreset>> _fetchOpenRouterModels(
    http.Client client, {
    String? apiKey,
  }) async {
    final headers = <String, String>{
      'HTTP-Referer': 'https://kaban.ph',
      'X-Title': 'Kaban Finance Tracker',
    };
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }

    final uri = Uri.parse('https://openrouter.ai/api/v1/models');
    final res = await client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) {
      throw Exception('OpenRouter models API returned ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as List?;
    if (data == null || data.isEmpty) return const [];

    final list = <ModelPreset>[];
    for (final raw in data) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final id = m['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final name = m['name']?.toString() ?? id;
      final desc = m['description']?.toString() ?? '';
      final pricing = m['pricing'] as Map?;

      // Check if model is free:
      // Either ends with ':free' or has 0 cost for prompt and completion
      final idLower = id.toLowerCase();
      final isFree = idLower.endsWith(':free') ||
          (pricing != null &&
              pricing['prompt']?.toString() == '0' &&
              pricing['completion']?.toString() == '0');

      // Check if model supports vision / photo analysis:
      final arch = m['architecture'] as Map?;
      final inputModalities = (arch?['input_modalities'] as List?)
          ?.map((e) => e.toString().toLowerCase())
          .toList();
      final modalityStr = arch?['modality']?.toString().toLowerCase() ?? '';

      final supportsVision =
          (inputModalities != null && inputModalities.contains('image')) ||
              modalityStr.contains('image') ||
              idLower.contains('vision') ||
              idLower.contains('vl') ||
              idLower.contains('flash') ||
              idLower.contains('4o') ||
              idLower.contains('gemini');

      // Family from prefix before '/'
      final parts = id.split('/');
      final family = parts.length > 1
          ? _capitalize(parts[0].replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' '))
          : 'Other';

      list.add(ModelPreset(
        id: id,
        name: name,
        tagline: desc.isNotEmpty ? desc : (isFree ? 'Free model' : id),
        family: family,
        isFree: isFree,
        supportsVision: supportsVision,
      ));
    }

    // Sort order:
    // 1. Free models first
    // 2. Multimodal / Vision models second
    // 3. Alphabetical by name
    list.sort((a, b) {
      if (a.isFree != b.isFree) {
        return a.isFree ? -1 : 1;
      }
      if (a.supportsVision != b.supportsVision) {
        return a.supportsVision ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return list;
  }

  Future<List<ModelPreset>> _fetchGeminiModels(
    http.Client client, {
    required String apiKey,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
    );
    final res = await client.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('Gemini models API returned ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final rawModels = json['models'] as List?;
    if (rawModels == null || rawModels.isEmpty) return const [];

    final list = <ModelPreset>[];
    for (final raw in rawModels) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final rawName = m['name']?.toString() ?? '';
      final id = rawName.startsWith('models/')
          ? rawName.substring('models/'.length)
          : rawName;
      if (id.isEmpty) continue;

      // Filter: only models that support 'generateContent'
      final methods = (m['supportedGenerationMethods'] as List?)
          ?.map((e) => e.toString())
          .toList();
      if (methods != null && !methods.contains('generateContent')) {
        continue;
      }

      // Exclude embedding, text-bison, or specialized non-chat models
      final idLower = id.toLowerCase();
      if (idLower.contains('embedding') ||
          idLower.contains('aqa') ||
          idLower.contains('imagen') ||
          idLower.contains('veo')) {
        continue;
      }

      final displayName = m['displayName']?.toString() ?? id;
      final description = m['description']?.toString() ?? '';

      // All modern Gemini models support vision
      final supportsVision = idLower.contains('gemini');

      // Flash and lite models fall under free tier RPM/RPD limits
      final isFree = idLower.contains('flash') || idLower.contains('lite');

      list.add(ModelPreset(
        id: id,
        name: displayName,
        tagline: description.isNotEmpty ? description : 'Google Gemini model',
        family: 'Google',
        isFree: isFree,
        supportsVision: supportsVision,
      ));
    }

    // Sort order:
    // Flash models first, then Pro, then others
    list.sort((a, b) {
      if (a.isFree != b.isFree) return a.isFree ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return list;
  }

  Future<List<ModelPreset>> _fetchOpenAiShapeModels(
    http.Client client, {
    required String baseUrl,
    String? apiKey,
    required AIProvider provider,
  }) async {
    final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$cleanBase/models');
    final headers = <String, String>{};
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }

    final res = await client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception(
          'OpenAI-compatible models API returned ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as List?;
    if (data == null || data.isEmpty) return const [];

    final list = <ModelPreset>[];
    for (final raw in data) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final id = m['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final idLower = id.toLowerCase();
      final supportsVision = idLower.contains('vision') ||
          idLower.contains('vl') ||
          idLower.contains('flash') ||
          idLower.contains('4o') ||
          idLower.contains('gemini');

      final isFree = idLower.endsWith(':free');

      list.add(ModelPreset(
        id: id,
        name: id,
        tagline: isFree ? 'Free model' : id,
        family: kAIProviders[provider]?.displayName ?? 'Custom',
        isFree: isFree,
        supportsVision: supportsVision,
      ));
    }

    list.sort((a, b) {
      if (a.supportsVision != b.supportsVision) {
        return a.supportsVision ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return list;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }
}

class _CacheEntry {
  final List<ModelPreset> models;
  final DateTime timestamp;
  const _CacheEntry({required this.models, required this.timestamp});
}
