import 'package:flutter/material.dart';
import '../models/debt.dart';
import '../models/salary_plan.dart';
import '../services/ai/ai_provider_config.dart';

/// Per-provider credential + endpoint override. The `Local` slot is always
/// empty by convention — the coach short-circuits to the offline engine
/// before any slot lookup.
class ProviderSlot {
  final String apiKey;
  final String baseUrl;
  final String model;

  const ProviderSlot({
    this.apiKey = '',
    this.baseUrl = '',
    this.model = '',
  });

  bool get isEmpty => apiKey.isEmpty && baseUrl.isEmpty && model.isEmpty;

  Map<String, dynamic> toJson() => {
        'apiKey': apiKey,
        'baseUrl': baseUrl,
        'model': model,
      };

  static ProviderSlot fromJson(Map<String, dynamic>? m) {
    if (m == null) return const ProviderSlot();
    return ProviderSlot(
      apiKey: m['apiKey'] as String? ?? '',
      baseUrl: m['baseUrl'] as String? ?? '',
      model: m['model'] as String? ?? '',
    );
  }

  ProviderSlot copyWith({String? apiKey, String? baseUrl, String? model}) =>
      ProviderSlot(
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
      );
}

class AppSettings {
  final AIProvider aiProvider;
  final Map<AIProvider, ProviderSlot> aiSlotsByProvider;
  final bool allowRemoteAI;
  final bool anonymizeBalances;
  final bool autoCaptureEnabled;
  final Set<String> autoCapturePackages;
  final DebtStrategy defaultStrategy;
  final ThemeMode themeMode;
  final bool onboardingComplete;
  final bool biometricLock;
  final bool autoRecurring;
  final bool privacyMode;
  final bool autoBackupOnLaunch;
  final SalaryPlan? salaryPlan;

  const AppSettings({
    this.aiProvider = AIProvider.local,
    this.aiSlotsByProvider = const {},
    this.allowRemoteAI = false,
    this.anonymizeBalances = true,
    this.autoCaptureEnabled = false,
    this.autoCapturePackages = const {},
    this.defaultStrategy = DebtStrategy.avalanche,
    this.themeMode = ThemeMode.system,
    this.onboardingComplete = false,
    this.biometricLock = false,
    this.autoRecurring = true,
    this.privacyMode = false,
    this.autoBackupOnLaunch = false,
    this.salaryPlan,
  });

  /// Returns the saved slot for [p], or an empty slot if nothing was stored.
  ProviderSlot slotFor(AIProvider p) =>
      aiSlotsByProvider[p] ?? const ProviderSlot();

  /// Returns a new AppSettings with [p]'s slot replaced by [slot]. Other
  /// slots are untouched.
  AppSettings withSlot(AIProvider p, ProviderSlot slot) {
    final next = Map<AIProvider, ProviderSlot>.from(aiSlotsByProvider);
    next[p] = slot;
    return copyWith(aiSlotsByProvider: next);
  }

  AppSettings copyWith({
    AIProvider? aiProvider,
    Map<AIProvider, ProviderSlot>? aiSlotsByProvider,
    bool? allowRemoteAI,
    bool? anonymizeBalances,
    bool? autoCaptureEnabled,
    Set<String>? autoCapturePackages,
    DebtStrategy? defaultStrategy,
    ThemeMode? themeMode,
    bool? onboardingComplete,
    bool? biometricLock,
    bool? autoRecurring,
    bool? privacyMode,
    bool? autoBackupOnLaunch,
    SalaryPlan? salaryPlan,
    bool clearSalaryPlan = false,
  }) =>
      AppSettings(
        aiProvider: aiProvider ?? this.aiProvider,
        aiSlotsByProvider: aiSlotsByProvider ?? this.aiSlotsByProvider,
        allowRemoteAI: allowRemoteAI ?? this.allowRemoteAI,
        anonymizeBalances: anonymizeBalances ?? this.anonymizeBalances,
        autoCaptureEnabled: autoCaptureEnabled ?? this.autoCaptureEnabled,
        autoCapturePackages: autoCapturePackages ?? this.autoCapturePackages,
        defaultStrategy: defaultStrategy ?? this.defaultStrategy,
        themeMode: themeMode ?? this.themeMode,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        biometricLock: biometricLock ?? this.biometricLock,
        autoRecurring: autoRecurring ?? this.autoRecurring,
        privacyMode: privacyMode ?? this.privacyMode,
        autoBackupOnLaunch: autoBackupOnLaunch ?? this.autoBackupOnLaunch,
        salaryPlan: clearSalaryPlan ? null : (salaryPlan ?? this.salaryPlan),
      );
}
