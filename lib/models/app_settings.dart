import 'package:flutter/material.dart';
import '../models/debt.dart';
import '../services/ai/ai_provider_config.dart';

class AppSettings {
  final AIProvider aiProvider;
  final String aiApiKey;
  final String aiBaseUrl;
  final String aiModel;
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

  const AppSettings({
    this.aiProvider = AIProvider.local,
    this.aiApiKey = '',
    this.aiBaseUrl = '',
    this.aiModel = '',
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
  });

  AppSettings copyWith({
    AIProvider? aiProvider,
    String? aiApiKey,
    String? aiBaseUrl,
    String? aiModel,
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
  }) =>
      AppSettings(
        aiProvider: aiProvider ?? this.aiProvider,
        aiApiKey: aiApiKey ?? this.aiApiKey,
        aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
        aiModel: aiModel ?? this.aiModel,
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
      );
}
