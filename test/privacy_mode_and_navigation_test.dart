import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finance_tracker/models/app_settings.dart';
import 'package:finance_tracker/models/debt.dart';
import 'package:finance_tracker/screens/debts/widgets/debt_tile.dart';
import 'package:finance_tracker/services/ai/ai_provider_config.dart';
import 'package:finance_tracker/services/ai/coach_service.dart';
import 'package:finance_tracker/services/ai/local_coach.dart';
import 'package:finance_tracker/services/ai/remote_coach.dart';
import 'package:finance_tracker/router/app_router.dart';
import 'package:finance_tracker/screens/dashboard/widgets/debt_progress.dart';
import 'package:finance_tracker/screens/dashboard/widgets/summary_card.dart';
import 'package:finance_tracker/theme/app_theme.dart';

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

  group('Adaptive Theming & Layout Constraints', () {
    test('AppTheme light and dark bottomSheetTheme enforces 560dp maxWidth',
        () {
      final lightTheme = AppTheme.light();
      final darkTheme = AppTheme.dark();

      expect(lightTheme.bottomSheetTheme.constraints?.maxWidth, 560);
      expect(darkTheme.bottomSheetTheme.constraints?.maxWidth, 560);
    });
  });

  group('Delight & Celebratory States', () {
    testWidgets(
        'DebtTile renders PAID OFF badge and celebration text when paid off',
        (tester) async {
      const settledDebt = Debt(
        id: 'd1',
        name: 'BDO Visa Card',
        balance: 0,
        apr: 24.0,
        minPayment: 1500,
        strategy: DebtStrategy.avalanche,
        paidOff: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DebtTile(
              debt: settledDebt,
              monthsToPayoff: 0,
              interestPaid: 0,
            ),
          ),
        ),
      );

      expect(find.text('PAID OFF'), findsOneWidget);
      expect(find.text('Fully settled · Debt-free!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });

  group('Quiet Motion & Accessibility', () {
    testWidgets('SummaryCard uses AnimatedSwitcher for privacy crossfade',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              income: 25000,
              expense: 12000,
              obscure: false,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedSwitcher), findsNWidgets(2));
      expect(find.text('₱25,000'), findsOneWidget);
      expect(find.text('₱12,000'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              income: 25000,
              expense: 12000,
              obscure: true,
            ),
          ),
        ),
      );

      // Verify crossfade animation starts
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(FadeTransition), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('₱••••'), findsNWidgets(2));
    });

    testWidgets(
        'DebtProgressCard animates progress bar with TweenAnimationBuilder',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DebtProgressCard(
              totalDebt: 5000,
              startingTotalDebt: 10000,
              monthsRemaining: 5,
              wallets: [],
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('50% paid off'), findsOneWidget);
    });

    testWidgets(
        'SummaryCard respects disableAnimations setting with zero duration',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: SummaryCard(
                income: 25000,
                expense: 12000,
                obscure: false,
              ),
            ),
          ),
        ),
      );

      final switchers =
          tester.widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
      for (final switcher in switchers) {
        expect(switcher.duration, Duration.zero);
      }
    });
  });
}
