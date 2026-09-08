import '../models/transaction.dart';
import '../models/wallet.dart';

class BalanceRecalculator {
  double compute(Wallet wallet, List<Transaction> txns) {
    double bal = wallet.startingBalance;
    for (final t in txns) {
      if (t.walletId != wallet.id) continue;
      switch (t.type) {
        case TransactionType.income:
          bal += t.amount;
          break;
        case TransactionType.expense:
          bal -= t.amount;
          break;
        case TransactionType.transfer:
          if (t.category == 'Transfer In') {
            bal += t.amount;
          } else {
            bal -= t.amount;
          }
          break;
      }
    }
    return bal;
  }

  double netWorth(Map<String, double> balances, double totalDebt) {
    final assets = balances.values.fold<double>(0, (s, b) => s + b);
    return assets - totalDebt;
  }
}
