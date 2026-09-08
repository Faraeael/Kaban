import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../services/ai/ai_provider_config.dart';
import '../models/debt.dart';

class SettingsService {
  static const _key = 'app_settings_v1';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      return AppSettings(
        aiProvider:
            AIProvider.values.byName(m['aiProvider'] as String? ?? 'local'),
        aiApiKey: m['aiApiKey'] as String? ?? '',
        aiBaseUrl: m['aiBaseUrl'] as String? ?? '',
        aiModel: m['aiModel'] as String? ?? '',
        allowRemoteAI: m['allowRemoteAI'] as bool? ?? false,
        anonymizeBalances: m['anonymizeBalances'] as bool? ?? true,
        autoCaptureEnabled: m['autoCaptureEnabled'] as bool? ?? false,
        autoCapturePackages:
            ((m['autoCapturePackages'] as List?)?.cast<String>() ?? const [])
                .toSet(),
        defaultStrategy: DebtStrategy.values
            .byName(m['defaultStrategy'] as String? ?? 'avalanche'),
        themeMode:
            ThemeMode.values.byName(m['themeMode'] as String? ?? 'system'),
        onboardingComplete: m['onboardingComplete'] as bool? ?? false,
        biometricLock: m['biometricLock'] as bool? ?? false,
        autoRecurring: m['autoRecurring'] as bool? ?? true,
        privacyMode: m['privacyMode'] as bool? ?? false,
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    final m = {
      'aiProvider': s.aiProvider.name,
      'aiApiKey': s.aiApiKey,
      'aiBaseUrl': s.aiBaseUrl,
      'aiModel': s.aiModel,
      'allowRemoteAI': s.allowRemoteAI,
      'anonymizeBalances': s.anonymizeBalances,
      'autoCaptureEnabled': s.autoCaptureEnabled,
      'autoCapturePackages': s.autoCapturePackages.toList(),
      'defaultStrategy': s.defaultStrategy.name,
      'themeMode': s.themeMode.name,
      'onboardingComplete': s.onboardingComplete,
      'biometricLock': s.biometricLock,
      'autoRecurring': s.autoRecurring,
      'privacyMode': s.privacyMode,
    };
    await prefs.setString(_key, json.encode(m));
  }
}
