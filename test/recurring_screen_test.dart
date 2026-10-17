import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/models/recurring_transaction.dart';
import 'package:finance_tracker/models/subscription.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/models/wallet.dart';
import 'package:finance_tracker/screens/recurring/recurring_screen.dart';
import 'package:finance_tracker/screens/subscriptions/subscriptions_screen.dart';
import 'package:finance_tracker/state/data_providers.dart';

class FakeRecurringNotifier extends StateNotifier<List<RecurringTransaction>>
    implements RecurringListNotifier {
  FakeRecurringNotifier([super.state = const []]);
  @override
  Future<void> load() async {}
  @override
  Future<void> add(RecurringTransaction r) async {
    state = [...state, r];
  }

  @override
  Future<void> update(RecurringTransaction r) async {}
  @override
  Future<void> delete(String id) async {}
}

class FakeSubscriptionNotifier extends StateNotifier<List<Subscription>>
    implements SubscriptionListNotifier {
  final FakeTransactionNotifier? txnNotifier;
  FakeSubscriptionNotifier([super.state = const [], this.txnNotifier]);
  @override
  Future<void> load() async {}
  @override
  Future<void> add(Subscription s) async {
    state = [...state, s];
  }

  @override
  Future<void> update(Subscription s) async {
    state = [
      for (final sub in state)
        if (sub.id == s.id) s else sub,
    ];
  }
  @override
  Future<Subscription> recordPayment({
    required Subscription subscription,
    required String walletId,
    required DateTime nextDate,
    DateTime? date,
    String? transactionId,
  }) async {
    final updated = subscription.copyWith(
      nextBillingDate: nextDate,
      walletId: walletId,
    );
    await update(updated);
    if (txnNotifier != null) {
      await txnNotifier!.add(
        Transaction(
          id: transactionId ?? 'sub-txn-test',
          amount: subscription.amount,
          type: TransactionType.expense,
          category: subscription.category,
          note: '${subscription.name} subscription',
          date: date ?? DateTime.now(),
          walletId: walletId,
        ),
      );
    }
    return updated;
  }
  @override
  Future<void> delete(String id) async {
    state = state.where((s) => s.id != id).toList();
  }
}

class FakeWalletNotifier extends StateNotifier<List<Wallet>>
    implements WalletListNotifier {
  FakeWalletNotifier([super.state = const []]);
  @override
  Future<void> load() async {}
  @override
  Future<void> add(Wallet w) async {}
  @override
  Future<void> update(Wallet w) async {}
  @override
  Future<void> delete(String id) async {}
}

class FakeTransactionNotifier extends StateNotifier<List<Transaction>>
    implements TransactionListNotifier {
  FakeTransactionNotifier([super.state = const []]);
  @override
  Future<void> load() async {}
  @override
  Future<void> add(Transaction t) async {
    state = [...state, t];
  }
  @override
  Future<void> addMany(List<Transaction> ts) async {
    state = [...state, ...ts];
  }
  @override
  Future<void> delete(String id) async {
    state = state.where((t) => t.id != id).toList();
  }
  @override
  Future<void> deleteTransferPair(String pairId) async {
    state = state.where((t) => t.transferPairId != pairId).toList();
  }
}

Widget buildTestWidget({required Widget child}) {
  return ProviderScope(
    overrides: [
      recurringListProvider.overrideWith((ref) => FakeRecurringNotifier()),
      subscriptionListProvider
          .overrideWith((ref) => FakeSubscriptionNotifier()),
      walletListProvider.overrideWith((ref) => FakeWalletNotifier()),
      transactionListProvider.overrideWith((ref) => FakeTransactionNotifier()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  testWidgets('RecurringScreen renders Tab 0 Recurring Bills by default',
      (tester) async {
    await tester.pumpWidget(
      buildTestWidget(child: const RecurringScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recurring & Subscriptions'), findsOneWidget);
    expect(find.text('Recurring Bills'), findsOneWidget);
    expect(find.text('Subscriptions'), findsOneWidget);
    expect(find.text('Add recurring'), findsAtLeastNWidgets(1));
    expect(find.text('No recurring transactions'), findsOneWidget);
  });

  testWidgets(
      'RecurringScreen renders Tab 1 Subscriptions when initialTab is 1',
      (tester) async {
    await tester.pumpWidget(
      buildTestWidget(child: const RecurringScreen(initialTab: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recurring & Subscriptions'), findsOneWidget);
    expect(find.text('Add subscription'), findsAtLeastNWidgets(1));
    expect(find.text('No subscriptions tracked yet'), findsOneWidget);
  });

  testWidgets(
      'SubscriptionsScreen delegates to RecurringScreen with initialTab 1',
      (tester) async {
    await tester.pumpWidget(
      buildTestWidget(child: const SubscriptionsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recurring & Subscriptions'), findsOneWidget);
    expect(find.text('Add subscription'), findsAtLeastNWidgets(1));
    expect(find.text('No subscriptions tracked yet'), findsOneWidget);
  });

  testWidgets(
      'Mark paid button logs expense and advances subscription next billing date',
      (tester) async {
    const wallet = Wallet(
      id: 'w-sub',
      name: 'Maya',
      type: WalletType.ewallet,
      startingBalance: 2000,
      currency: 'PHP',
      colorValue: 0xFF00D632,
      logoAsset: 'assets/logos/maya.svg',
    );

    final initialDate = DateTime(2026, 10, 15);
    final sub = Subscription(
      id: 's-netflix',
      name: 'Netflix',
      amount: 549,
      cadence: Cadence.monthly,
      nextBillingDate: initialDate,
      category: 'Entertainment',
      walletId: 'w-sub',
    );

    final txnNotifier = FakeTransactionNotifier();
    final subNotifier = FakeSubscriptionNotifier([sub], txnNotifier);
    final walletNotifier = FakeWalletNotifier([wallet]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recurringListProvider.overrideWith((ref) => FakeRecurringNotifier()),
          subscriptionListProvider.overrideWith((ref) => subNotifier),
          walletListProvider.overrideWith((ref) => walletNotifier),
          transactionListProvider.overrideWith((ref) => txnNotifier),
        ],
        child: const MaterialApp(
          home: RecurringScreen(initialTab: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('₱549.00'), findsAtLeastNWidgets(1));

    // Tap "Mark paid" icon button
    final markPaidBtn = find.byTooltip('Mark paid');
    expect(markPaidBtn, findsOneWidget);
    await tester.tap(markPaidBtn);
    await tester.pumpAndSettle();

    // Confirm Dialog opens
    expect(find.text('Log Netflix payment?'), findsOneWidget);
    expect(find.text('Confirm & Log'), findsOneWidget);

    // Confirm
    await tester.tap(find.text('Confirm & Log'));
    await tester.pumpAndSettle();

    // Verify transaction was logged
    expect(txnNotifier.state, hasLength(1));
    final loggedTxn = txnNotifier.state.first;
    expect(loggedTxn.amount, 549);
    expect(loggedTxn.type, TransactionType.expense);
    expect(loggedTxn.walletId, 'w-sub');
    expect(loggedTxn.note, 'Netflix subscription');

    // Verify subscription nextBillingDate rolled 1 month
    final updatedSub = subNotifier.state.first;
    expect(updatedSub.nextBillingDate, DateTime(2026, 11, 15));
  });

  testWidgets(
      'Mark paid dialog safely falls back to active wallet when linked wallet is archived',
      (tester) async {
    const activeWallet = Wallet(
      id: 'w-active',
      name: 'Cash',
      type: WalletType.cash,
      startingBalance: 500,
      currency: 'PHP',
      colorValue: 0xFF75EEA5,
      logoAsset: 'assets/logos/cash.svg',
    );

    // Subscription points to an archived wallet ID 'w-archived':
    final sub = Subscription(
      id: 's-disney',
      name: 'Disney+',
      amount: 369,
      cadence: Cadence.monthly,
      nextBillingDate: DateTime(2026, 1, 31),
      category: 'Entertainment',
      walletId: 'w-archived',
    );

    final txnNotifier = FakeTransactionNotifier();
    final subNotifier = FakeSubscriptionNotifier([sub], txnNotifier);
    final walletNotifier = FakeWalletNotifier([activeWallet]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recurringListProvider.overrideWith((ref) => FakeRecurringNotifier()),
          subscriptionListProvider.overrideWith((ref) => subNotifier),
          walletListProvider.overrideWith((ref) => walletNotifier),
          transactionListProvider.overrideWith((ref) => txnNotifier),
        ],
        child: const MaterialApp(
          home: RecurringScreen(initialTab: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Mark paid" - must not throw assertion error from DropdownButtonFormField:
    await tester.tap(find.byTooltip('Mark paid'));
    await tester.pumpAndSettle();

    expect(find.text('Log Disney+ payment?'), findsOneWidget);
    // Month-end Jan 31 clamps to Feb 28 in non-leap year (2026):
    expect(find.textContaining('2026-02-28'), findsOneWidget);

    await tester.tap(find.text('Confirm & Log'));
    await tester.pumpAndSettle();

    expect(txnNotifier.state.first.walletId, 'w-active');
    expect(subNotifier.state.first.nextBillingDate, DateTime(2026, 2, 28));
  });
}
