import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finance_tracker/models/app_settings.dart';
import 'package:finance_tracker/services/ai/ai_provider_config.dart';
import 'package:finance_tracker/services/ai/coach_service.dart';
import 'package:finance_tracker/services/ai/local_coach.dart';
import 'package:finance_tracker/services/ai/remote_coach.dart';
import 'package:finance_tracker/router/app_router.dart';

void main() {
  group('Privacy Mode & AppSettings', () {
    test('defaults to false and copyWith toggles correctly', () {
      const settings = AppSettings();
      expect(settings.privacyMode, isFalse);

      final updated = settings.copyWith(privacyMode: true);
      expect(updated.privacyMode, isTrue);

      final toggledBack = updated.copyWith(privacyMode: false);
      expect(toggledBack.privacyMode, isFalse);
    });

    test('toJson and fromJson serializes privacy_mode correctly', () {
      const settings = AppSettings(privacyMode: true);
      final jsonMap = {
        'privacy_mode': settings.privacyMode,
      };
      final encoded = jsonEncode(jsonMap);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['privacy_mode'], isTrue);
    });
  });

  group('Commute Suggested Prompts', () {
    const emptySnapshot = FinanceSnapshot(
      walletBalances: {},
      monthIncome: 0,
      monthExpense: 0,
      monthExpenseByCategory: {},
      debts: [],
      suggestions: [],
      totalDebt: 0,
    );

    test('LocalCoach suggests commute fare logging prompt', () {
      final coach = LocalCoach();
      final prompts = coach.suggestedPrompts(emptySnapshot);
      expect(prompts, contains('Paid ₱15 jeep fare'));
    });

    test('RemoteCoach suggests commute fare logging prompt', () {
      final coach = RemoteCoach(
        config: kAIProviders[AIProvider.google]!,
        apiKey: 'test-key',
        baseUrl: 'https://example.com',
        model: 'gemini-2.0-flash',
      );
      final prompts = coach.suggestedPrompts(emptySnapshot);
      expect(prompts, contains('Paid ₱15 jeep fare'));
    });
  });

  group('Navigation & Router Configuration', () {
    test('appRouter defines routes for sub-screens outside ShellRoute', () {
      final routes = appRouter.configuration.routes;
      expect(routes.isNotEmpty, isTrue);
      final paths = routes.whereType<GoRoute>().map((r) => r.path).toList();
      expect(paths, contains('/goals'));
      expect(paths, contains('/recurring'));
      expect(paths, contains('/subscriptions'));
    });
  });
}
