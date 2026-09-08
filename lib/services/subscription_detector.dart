import '../models/transaction.dart';

class SubscriptionSuggestion {
  final String merchant;
  final double amount;
  final TransactionType type;
  final String category;
  final int occurrences;
  final double variance;
  final int avgDayOfMonth;

  const SubscriptionSuggestion({
    required this.merchant,
    required this.amount,
    required this.type,
    required this.category,
    required this.occurrences,
    required this.variance,
    required this.avgDayOfMonth,
  });
}

class SubscriptionDetector {
  List<SubscriptionSuggestion> detect(List<Transaction> txns,
      {int windowDays = 90}) {
    final cutoff = DateTime.now().subtract(Duration(days: windowDays));
    final recent = txns
        .where(
            (t) => t.date.isAfter(cutoff) && t.type != TransactionType.transfer)
        .toList();

    final byMerchant = <String, List<Transaction>>{};
    for (final t in recent) {
      final key =
          t.category == 'Subscriptions' ? t.category : t.note ?? t.category;
      byMerchant.putIfAbsent(key, () => []).add(t);
    }

    final suggestions = <SubscriptionSuggestion>[];
    byMerchant.forEach((merchant, list) {
      if (list.length < 3) return;
      list.sort((a, b) => a.date.compareTo(b.date));

      final gaps = <int>[];
      for (var i = 1; i < list.length; i++) {
        gaps.add(list[i].date.difference(list[i - 1].date).inDays);
      }
      if (gaps.isEmpty) return;
      final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;

      final isRecurring = avgGap >= 25 && avgGap <= 35;
      if (!isRecurring) return;

      final amounts = list.map((t) => t.amount).toList();
      final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
      final variance = _variance(amounts, avgAmount);
      if (variance / avgAmount > 0.25) return;

      final daySum = list.map((t) => t.date.day).reduce((a, b) => a + b);
      final avgDay = (daySum / list.length).round();

      suggestions.add(SubscriptionSuggestion(
        merchant: merchant,
        amount: avgAmount,
        type: list.first.type,
        category: list.first.category,
        occurrences: list.length,
        variance: variance,
        avgDayOfMonth: avgDay,
      ));
    });

    suggestions.sort((a, b) => b.occurrences.compareTo(a.occurrences));
    return suggestions;
  }

  double _variance(List<double> values, double mean) {
    if (values.isEmpty) return 0;
    final sumSq =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b);
    return sumSq / values.length;
  }
}
