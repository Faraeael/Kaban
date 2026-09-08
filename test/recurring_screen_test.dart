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
  FakeSubscriptionNotifier([super.state = const []]);
  @override
  Future<void> load() async {}
  @override
  Future<void> add(Subscription s) async {
    state = [...state, s];
  }

  @override
  Future<void> update(Subscription s) async {}
  @override
  Future<void> delete(String id) async {}
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
  Future<void> add(Transaction t) async {}
  @override
  Future<void> addMany(List<Transaction> ts) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteTransferPair(String pairId) async {}
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
}
