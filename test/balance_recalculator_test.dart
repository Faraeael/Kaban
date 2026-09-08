import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/models/wallet.dart';
import 'package:finance_tracker/services/balance_recalculator.dart';

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
  });
}
