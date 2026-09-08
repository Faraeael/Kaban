import '../models/transaction.dart';
import '../models/wallet.dart';

class SpendingInsight {
  final String title;
  final String detail;
  final InsightSeverity severity;

  const SpendingInsight({
    required this.title,
    required this.detail,
    required this.severity,
  });
}

enum InsightSeverity { info, warn, alert }

class SpendingAnalyzer {
  SpendingInsight? overspendCheck(
      List<Transaction> txns, String category, double budget) {
    final month = DateTime.now();
    final start = DateTime(month.year, month.month, 1);
    final spent = txns
        .where((t) =>
            t.category == category &&
            t.type == TransactionType.expense &&
            !t.date.isBefore(start))
        .fold<double>(0, (s, t) => s + t.amount);
    if (budget <= 0) return null;
    final ratio = spent / budget;
    if (ratio >= 1.0) {
      return SpendingInsight(
        title: '$category budget exceeded',
        detail:
            'You spent ₱${spent.toStringAsFixed(0)} of a ₱${budget.toStringAsFixed(0)} budget.',
        severity: InsightSeverity.alert,
      );
    }
    if (ratio >= 0.8) {
      return SpendingInsight(
        title: '$category nearing budget',
        detail:
            'You\'ve used ${(ratio * 100).toStringAsFixed(0)}% of your $category budget.',
        severity: InsightSeverity.warn,
      );
    }
    return null;
  }

  ({TransactionType type, double total}) monthTotals(List<Transaction> txns) {
    final month = DateTime.now();
    final start = DateTime(month.year, month.month, 1);
    final filtered = txns
        .where((t) =>
            !t.date.isBefore(start) && t.type != TransactionType.transfer)
        .toList();
    final income = filtered
        .where((t) => t.type == TransactionType.income)
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = filtered
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);
    return (type: TransactionType.income, total: income - expense);
  }

  ({String category, double total})? topExpenseCategory(
      List<Transaction> txns) {
    final month = DateTime.now();
    final start = DateTime(month.year, month.month, 1);
    final expenses = txns.where(
        (t) => t.type == TransactionType.expense && !t.date.isBefore(start));
    if (expenses.isEmpty) return null;
    final totals = <String, double>{};
    for (final t in expenses) {
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return (category: sorted.first.key, total: sorted.first.value);
  }

  List<({Wallet wallet, double balance})> negativeBalances(
    Map<Wallet, double> walletBalances,
  ) {
    return walletBalances.entries
        .where((e) => e.value < 0 && e.key.type != WalletType.credit)
        .map((e) => (wallet: e.key, balance: e.value))
        .toList();
  }
}
