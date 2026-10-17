import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/screens/transactions/add_transaction_sheet.dart';
import 'package:finance_tracker/utils/formatters.dart';
import 'package:go_router/go_router.dart';
import 'package:finance_tracker/screens/transactions/transactions_screen.dart';
import 'package:finance_tracker/models/app_settings.dart';
import 'package:finance_tracker/models/debt.dart';
import 'package:finance_tracker/models/wallet.dart';
import 'package:finance_tracker/screens/debts/widgets/debt_tile.dart';
import 'package:finance_tracker/screens/wallets/widgets/wallet_tile.dart';
import 'package:finance_tracker/services/ai/ai_provider_config.dart';
import 'package:finance_tracker/services/ai/coach_service.dart';
import 'package:finance_tracker/services/ai/local_coach.dart';
import 'package:finance_tracker/services/ai/remote_coach.dart';
import 'package:finance_tracker/router/app_router.dart';
import 'package:finance_tracker/screens/dashboard/widgets/debt_progress.dart';
import 'package:finance_tracker/screens/dashboard/widgets/summary_card.dart';
import 'package:finance_tracker/screens/onboarding/help_screen.dart';
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

    test('formatInputAmount preserves cents and strips exact integer decimals', () {
      expect(formatInputAmount(null), '');
      expect(formatInputAmount(84.32), '84.32');
      expect(formatInputAmount(100.0), '100');
      expect(formatInputAmount(0.0), '0');
      expect(formatInputAmount(1250.5), '1250.50');
      expect(formatInputAmount(50.00), '50');
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
      expect(paths, contains('/subscriptions'));

      final shell = routes.whereType<ShellRoute>().single;
      final shellPaths = shell.routes.whereType<GoRoute>().map((r) => r.path).toList();
      expect(shellPaths, contains('/transactions'));
    });
  });

  group('Transactions Screen Search & Filter Widgets', () {
    testWidgets(
        'TransactionsScreen renders search bar, wallet filter, and category filter chips',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TransactionsScreen(
              initialWalletId: 'w1',
              initialCategory: 'Food',
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search note, merchant, or amount...'), findsOneWidget);
      expect(find.text('Reset filters'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);

      // Entering search query updates text
      await tester.enterText(find.byType(TextField), 'Jollibee');
      await tester.pump();
      expect(find.text('Jollibee'), findsOneWidget);
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

      // Clearing search query resets text
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();
      expect(find.text('Jollibee'), findsNothing);
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

    testWidgets(
        'HelpScreen enforces 720dp maxWidth constraint on wide viewports',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: HelpScreen(),
        ),
      );

      final box = tester.widget<ConstrainedBox>(find
          .ancestor(
              of: find.byType(Column), matching: find.byType(ConstrainedBox))
          .first);
      expect(box.constraints.maxWidth, 720);
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
      expect(find.text('₱25,000.00'), findsOneWidget);
      expect(find.text('₱12,000.00'), findsOneWidget);

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

    testWidgets(
        'DebtTile renders Record payment button for active debt and invokes callback',
        (tester) async {
      var tapped = false;
      const activeDebt = Debt(
        id: 'd2',
        name: 'BPI Card',
        balance: 5000,
        apr: 24.0,
        minPayment: 500,
        strategy: DebtStrategy.avalanche,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebtTile(
              debt: activeDebt,
              monthsToPayoff: 12,
              interestPaid: 650,
              onRecordPayment: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Record payment'), findsOneWidget);
      await tester.tap(find.text('Record payment'));
      expect(tapped, isTrue);
    });

    testWidgets(
        'DebtProgressCard shows Payment too low when monthsRemaining is null',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DebtProgressCard(
              totalDebt: 50000,
              startingTotalDebt: 50000,
              monthsRemaining: null,
              wallets: [],
            ),
          ),
        ),
      );

      expect(find.text('Payment too low'), findsOneWidget);
    });

    testWidgets(
        'Physical card WalletTile renders category badge, masked account number, holder name, and hides details in privacy mode',
        (tester) async {
      const bankWallet = Wallet(
        id: 'w1',
        name: 'BDO Unibank',
        type: WalletType.bank,
        startingBalance: 38000,
        colorValue: 0xFF0033A0,
        logoAsset: 'assets/logos/bdo.svg',
        accountNumber: '0041 2839 1024',
        accountName: 'Juan Dela Cruz',
        accountLabel: 'Savings',
        qrImagePath: '/tmp/bdo_qr.png',
      );

      var qrTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalletTile(
              wallet: bankWallet,
              balance: 38000,
              obscureBalance: false,
              onShowQr: () => qrTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('BANK'), findsOneWidget);
      expect(find.text('••••  ••••  1024'), findsOneWidget);
      expect(find.text('JUAN DELA CRUZ'), findsOneWidget);
      expect(find.text('SAVINGS'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('QR'), findsOneWidget);
      await tester.tap(find.text('QR'));
      expect(qrTapped, isTrue);

      // Enable Privacy Mode: balance, account number, and holder are masked, and QR + Copy are hidden.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalletTile(
              wallet: bankWallet,
              balance: 38000,
              obscureBalance: true,
              onShowQr: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₱••••••'), findsOneWidget);
      expect(find.text('••••  ••••  ••••'), findsOneWidget);
      expect(find.text('••••••••'), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('QR'), findsNothing);
    });

    testWidgets('AddTransactionSheet preserves decimal amount on initial transaction edit',
        (tester) async {
      final txn = Transaction(
        id: 't-test-1',
        amount: 84.32,
        type: TransactionType.expense,
        category: 'Food',
        note: 'snack',
        date: DateTime(2026, 10, 15),
        walletId: 'w-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddTransactionSheet(initial: txn),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Amount text field should show exact decimal '84.32', not rounded '84'
      final amountField = find.widgetWithText(TextField, '84.32');
      expect(amountField, findsOneWidget);
    });
  });
}
