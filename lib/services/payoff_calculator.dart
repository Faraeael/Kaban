import '../models/debt.dart';

class DebtPayoffResult {
  final List<DebtPayoffEntry> entries;
  final int totalMonths;
  final double totalInterestPaid;

  const DebtPayoffResult({
    required this.entries,
    required this.totalMonths,
    required this.totalInterestPaid,
  });
}

class DebtPayoffEntry {
  final Debt debt;
  final int monthsToPayoff;
  final double interestPaid;

  const DebtPayoffEntry({
    required this.debt,
    required this.monthsToPayoff,
    required this.interestPaid,
  });
}

class PayoffCalculator {
  static const int _maxMonths = 600; // 50-year safety cap

  DebtPayoffResult simulate({
    required List<Debt> debts,
    required double extraMonthlyPayment,
    required DebtStrategy strategy,
  }) {
    if (debts.isEmpty) {
      return const DebtPayoffResult(
          entries: [], totalMonths: 0, totalInterestPaid: 0);
    }

    final ordered = [...debts];
    switch (strategy) {
      case DebtStrategy.avalanche:
        ordered.sort((a, b) => b.apr.compareTo(a.apr));
        break;
      case DebtStrategy.snowball:
        ordered.sort((a, b) => a.balance.compareTo(b.balance));
        break;
    }

    final balances = <String, double>{
      for (final d in ordered) d.id: d.balance,
    };
    final interest = <String, double>{
      for (final d in ordered) d.id: 0.0,
    };
    final payoffMonth = <String, int>{};

    int month = 0;
    while (month < _maxMonths) {
      final stillActive = balances.values.any((b) => b > 0.005);
      if (!stillActive) break;
      month++;

      for (final d in ordered) {
        final bal = balances[d.id]!;
        if (bal <= 0) continue;
        final monthlyRate = d.apr / 100.0 / 12.0;
        final interestThisMonth = bal * monthlyRate;
        balances[d.id] = bal + interestThisMonth;
        interest[d.id] = (interest[d.id] ?? 0) + interestThisMonth;
      }

      double availableCash = extraMonthlyPayment;
      for (final d in ordered) {
        if (balances[d.id]! <= 0) continue;
        final baseMinPayment = d.minPayment > 0
            ? d.minPayment
            : (d.schedule == DebtSchedule.fixed &&
                    d.remainingPayments != null &&
                    d.remainingPayments! > 0
                ? d.balance / d.remainingPayments!
                : 0.0);
        final minPay = baseMinPayment.clamp(0.0, balances[d.id]!);
        balances[d.id] = balances[d.id]! - minPay;
        availableCash += (baseMinPayment - minPay);
      }

      for (final d in ordered) {
        if (balances[d.id]! <= 0) continue;
        if (availableCash <= 0) break;
        final pay = availableCash.clamp(0, balances[d.id]!);
        balances[d.id] = balances[d.id]! - pay;
        availableCash -= pay;
      }

      for (final d in ordered) {
        if (balances[d.id]! <= 0.005 && !payoffMonth.containsKey(d.id)) {
          balances[d.id] = 0;
          payoffMonth[d.id] = month;
        }
      }
    }

    final entries = ordered.map((d) {
      return DebtPayoffEntry(
        debt: d,
        monthsToPayoff: payoffMonth[d.id] ?? month,
        interestPaid: interest[d.id] ?? 0,
      );
    }).toList();

    final totalMonths = entries.isEmpty
        ? 0
        : entries.map((e) => e.monthsToPayoff).reduce((a, b) => a > b ? a : b);

    final totalInterest =
        entries.fold<double>(0, (sum, e) => sum + e.interestPaid);

    return DebtPayoffResult(
      entries: entries,
      totalMonths: totalMonths,
      totalInterestPaid: totalInterest,
    );
  }

  double totalMinimumPayment(List<Debt> debts) =>
      debts.fold(0, (s, d) => s + d.minPayment);
}
