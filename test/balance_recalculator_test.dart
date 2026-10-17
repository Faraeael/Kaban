import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/data/database.dart';
import 'package:finance_tracker/models/budget.dart';
import 'package:finance_tracker/models/debt.dart';
import 'package:finance_tracker/models/goal.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/models/wallet.dart';
import 'package:finance_tracker/screens/goals/goals_screen.dart';
import 'package:finance_tracker/services/balance_recalculator.dart';
import 'package:finance_tracker/state/data_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
void main() {
  group('BalanceRecalculator', () {
    final calc = BalanceRecalculator();

    const bdo = Wallet(
      id: 'w-bdo',
      name: 'BDO',
      type: WalletType.bank,
      startingBalance: 5000,
      currency: 'PHP',
      colorValue: 0xFF0038A8,
      logoAsset: 'assets/logos/bdo.svg',
    );

    const maya = Wallet(
      id: 'w-maya',
      name: 'Maya',
      type: WalletType.ewallet,
      startingBalance: 1000,
      currency: 'PHP',
      colorValue: 0xFF00D632,
      logoAsset: 'assets/logos/maya.svg',
    );

    test('adds income to starting balance', () {
      final txns = [
        Transaction(
          id: 't1',
          amount: 500,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime.now(),
          walletId: 'w-bdo',
        ),
      ];
      final bal = calc.compute(bdo, txns);
      expect(bal, 5500);
    });

    test('deducts expense from starting balance', () {
      final txns = [
        Transaction(
          id: 't1',
          amount: 250,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          walletId: 'w-bdo',
        ),
      ];
      final bal = calc.compute(bdo, txns);
      expect(bal, 4750);
    });

    test('transfer out deducts from source and transfer in adds to destination',
        () {
      const pairId = 'pair-123';
      final now = DateTime.now();

      final outTxn = Transaction(
        id: 't-out',
        amount: 1000,
        type: TransactionType.transfer,
        category: 'Transfer Out',
        date: now,
        walletId: 'w-bdo',
        transferPairId: pairId,
      );

      final inTxn = Transaction(
        id: 't-in',
        amount: 1000,
        type: TransactionType.transfer,
        category: 'Transfer In',
        date: now,
        walletId: 'w-maya',
        transferPairId: pairId,
      );

      final bdoBal = calc.compute(bdo, [outTxn]);
      final mayaBal = calc.compute(maya, [inTxn]);

      expect(bdoBal, 4000);
      expect(mayaBal, 2000);

      // Verify net worth remains neutral
      final initialNetWorth = calc.netWorth({'w-bdo': 5000, 'w-maya': 1000}, 0);
      final postTransferNetWorth =
          calc.netWorth({'w-bdo': bdoBal, 'w-maya': mayaBal}, 0);

      expect(initialNetWorth, 6000);
      expect(postTransferNetWorth, 6000);
    });

    test('archiving a wallet preserves its balance in netWorthProvider',
        () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = AppDatabase.instance;
      db.overridePath = inMemoryDatabasePath;
      await db.close();

      final container = ProviderContainer();
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      await container.read(walletListProvider.notifier).add(bdo);
      await container.read(walletListProvider.notifier).add(maya);
      expect(container.read(netWorthProvider), 6000);

      // Archive Maya (₱1,000 balance) — net worth must remain ₱6,000.
      await container
          .read(walletListProvider.notifier)
          .update(maya.copyWith(archived: true));
      expect(container.read(netWorthProvider), 6000);
    });

    test(
        'Quincena 2 budget window starts on day 16 and excludes first-half expenses',
        () {
      final oct20 = DateTime(2026, 10, 20, 14, 30);
      final q2 = GoalsScreen.budgetWindowFor(oct20, quincenaMode: true);
      expect(q2.start, DateTime(2026, 10, 16));
      expect(q2.end, DateTime(2026, 10, 31, 23, 59, 59));
      expect(q2.limitMultiplier, 0.5);

      final oct10 = DateTime(2026, 10, 10, 9, 0);
      expect(oct10.isBefore(q2.start), isTrue);

      final q1 = GoalsScreen.budgetWindowFor(oct10, quincenaMode: true);
      expect(q1.start, DateTime(2026, 10, 1));
      expect(q1.end, DateTime(2026, 10, 15, 23, 59, 59));
      expect(q1.limitMultiplier, 0.5);
    });

    test('GoalListNotifier and BudgetListNotifier support update and delete',
        () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = AppDatabase.instance;
      db.overridePath = inMemoryDatabasePath;
      await db.close();

      final container = ProviderContainer();
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      const goal = Goal(
        id: 'g1',
        name: 'Emergency Fund',
        target: 50000,
        saved: 10000,
      );
      await container.read(goalListProvider.notifier).add(goal);
      expect(container.read(goalListProvider).single.saved, 10000);

      await container
          .read(goalListProvider.notifier)
          .update(goal.copyWith(saved: 15000));
      expect(container.read(goalListProvider).single.saved, 15000);

      await container.read(goalListProvider.notifier).delete('g1');
      expect(container.read(goalListProvider), isEmpty);

      const budget = Budget(id: 'b1', category: 'Food', monthlyLimit: 8000);
      await container.read(budgetListProvider.notifier).upsert(budget);
      expect(container.read(budgetListProvider).single.monthlyLimit, 8000);

      await container.read(budgetListProvider.notifier).delete('b1');
      expect(container.read(budgetListProvider), isEmpty);
    });

    test(
        'DebtListNotifier.recordPayment atomically logs wallet expense and never marks partial final installment as paidOff',
        () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = AppDatabase.instance;
      db.overridePath = inMemoryDatabasePath;
      await db.close();

      final container = ProviderContainer();
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      await container.read(walletListProvider.notifier).add(bdo);
      const fixedDebt = Debt(
        id: 'd-fixed',
        name: 'MariLoan',
        balance: 3500,
        apr: 12,
        minPayment: 3500,
        strategy: DebtStrategy.avalanche,
        schedule: DebtSchedule.fixed,
        dueDay: 15,
        remainingPayments: 1,
        linkedWalletId: 'w-bdo',
      );
      await container.read(debtListProvider.notifier).add(fixedDebt);

      // 1. Partial payment (₱1,000 of ₱3,500) on the final installment must NOT mark paidOff.
      final afterPartial = await container
          .read(debtListProvider.notifier)
          .recordPayment(debt: fixedDebt, amount: 1000, walletId: 'w-bdo');
      await container.read(transactionListProvider.notifier).load();

      expect(afterPartial.balance, 2500);
      expect(afterPartial.paidOff, isFalse);
      expect(afterPartial.schedule, DebtSchedule.fixed);
      expect(afterPartial.remainingPayments, 1);
      expect(container.read(walletBalancesProvider)['w-bdo'], 4000);

      // 2. Paying the remaining ₱2,500 settles the debt and clears the schedule.
      final afterFull = await container
          .read(debtListProvider.notifier)
          .recordPayment(debt: afterPartial, amount: 2500, walletId: 'w-bdo');
      await container.read(transactionListProvider.notifier).load();

      expect(afterFull.balance, 0);
      expect(afterFull.paidOff, isTrue);
      expect(afterFull.schedule, DebtSchedule.none);
      expect(afterFull.remainingPayments, isNull);
      expect(container.read(walletBalancesProvider)['w-bdo'], 1500);
      expect(container.read(transactionListProvider), hasLength(2));
    });

    test(
        'Wallet v7 account details serialize, mask bank/ewallet/credit numbers, and restrict credit copy',
        () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = AppDatabase.instance;
      db.overridePath = inMemoryDatabasePath;
      await db.close();

      final container = ProviderContainer();
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      const bankWallet = Wallet(
        id: 'w-bdo-card',
        name: 'BDO Unibank',
        type: WalletType.bank,
        startingBalance: 38000,
        colorValue: 0xFF0033A0,
        logoAsset: 'assets/logos/bdo.svg',
        accountNumber: '0041 2839 1024',
        accountName: 'Juan Dela Cruz',
        accountLabel: 'Savings',
      );
      const gcashWallet = Wallet(
        id: 'w-gcash-card',
        name: 'GCash',
        type: WalletType.ewallet,
        startingBalance: 12250,
        colorValue: 0xFF007DFE,
        logoAsset: 'assets/logos/gcash.svg',
        accountNumber: '09171234567',
        accountName: 'Juan Dela Cruz',
      );
      const creditWallet = Wallet(
        id: 'w-cc',
        name: 'BPI Blue',
        type: WalletType.credit,
        startingBalance: 0,
        colorValue: 0xFFE31837,
        logoAsset: 'assets/logos/bpi.svg',
        accountNumber: '1024',
      );

      expect(bankWallet.maskedAccountNumber, '••••  ••••  1024');
      expect(bankWallet.canCopyDetails, isTrue);
      expect(
        bankWallet.copyableDetails,
        'BDO Unibank · (Savings) · 0041 2839 1024 · Juan Dela Cruz',
      );

      expect(gcashWallet.maskedAccountNumber, '0917 ••• 4567');
      expect(gcashWallet.canCopyDetails, isTrue);

      expect(creditWallet.maskedAccountNumber, '••••  ••••  1024');
      expect(creditWallet.canCopyDetails, isFalse);

      await container.read(walletListProvider.notifier).add(bankWallet);
      final stored = container.read(walletListProvider).single;
      expect(stored.accountNumber, '0041 2839 1024');
      expect(stored.accountName, 'Juan Dela Cruz');
      expect(stored.accountLabel, 'Savings');

      // Clearing accountNumber alone while keeping accountName & accountLabel:
      final clearedNumberOnly = stored.copyWith(accountNumber: null);
      await container
          .read(walletListProvider.notifier)
          .update(clearedNumberOnly);
      final afterPartialClear = container.read(walletListProvider).single;
      expect(afterPartialClear.accountNumber, isNull);
      expect(afterPartialClear.accountName, 'Juan Dela Cruz');
      expect(afterPartialClear.accountLabel, 'Savings');

      // Attach QR path and verify persistence + independent clearing:
      final withQr =
          afterPartialClear.copyWith(qrImagePath: '/tmp/bdo_qr.png');
      await container.read(walletListProvider.notifier).update(withQr);
      final storedWithQr = container.read(walletListProvider).single;
      expect(storedWithQr.qrImagePath, '/tmp/bdo_qr.png');
      expect(storedWithQr.hasQrImage, isTrue);

      final clearedQr = storedWithQr.copyWith(qrImagePath: null);
      await container.read(walletListProvider.notifier).update(clearedQr);
      expect(container.read(walletListProvider).single.qrImagePath, isNull);
      expect(container.read(walletListProvider).single.hasQrImage, isFalse);
    });
  });
}
