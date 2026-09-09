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

  DebtPayoffResult? _cachedResult;
  List<Debt>? _cachedDebts;
  double? _cachedExtraMonthlyPayment;
  DebtStrategy? _cachedStrategy;

  DebtPayoffResult simulate({
    required List<Debt> debts,
    required double extraMonthlyPayment,
    required DebtStrategy strategy,
  }) {
    if (debts.isEmpty) {
      return const DebtPayoffResult(
          entries: [], totalMonths: 0, totalInterestPaid: 0);
    }

    if (_cachedResult != null &&
        _cachedExtraMonthlyPayment == extraMonthlyPayment &&
        _cachedStrategy == strategy &&
        (identical(_cachedDebts, debts) || _debtsEqual(_cachedDebts, debts))) {
      return _cachedResult!;
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

    final count = ordered.length;
    final balances = List<double>.generate(count, (i) => ordered[i].balance);
    final interest = List<double>.filled(count, 0.0);
    final payoffMonth = List<int?>.filled(count, null);
    final monthlyRates =
        List<double>.generate(count, (i) => ordered[i].apr / 100.0 / 12.0);
    final baseMinPayments = List<double>.generate(count, (i) {
      final d = ordered[i];
      return d.minPayment > 0
          ? d.minPayment
          : (d.schedule == DebtSchedule.fixed &&
                  d.remainingPayments != null &&
                  d.remainingPayments! > 0
              ? d.balance / d.remainingPayments!
              : 0.0);
    });

    int activeCount = 0;
    for (var i = 0; i < count; i++) {
      if (balances[i] > 0.005) {
        activeCount++;
      }
    }

    if (activeCount == 0) {
      final emptyEntries = List<DebtPayoffEntry>.generate(
        count,
        (i) => DebtPayoffEntry(
          debt: ordered[i],
          monthsToPayoff: 0,
          interestPaid: 0,
        ),
      );
      final emptyResult = DebtPayoffResult(
        entries: emptyEntries,
        totalMonths: 0,
        totalInterestPaid: 0,
      );
      _cachedDebts = debts;
      _cachedExtraMonthlyPayment = extraMonthlyPayment;
      _cachedStrategy = strategy;
      _cachedResult = emptyResult;
      return emptyResult;
    }

    int month = 0;
    while (month < _maxMonths && activeCount > 0) {
      month++;

      // 1. Accrue monthly interest
      for (var i = 0; i < count; i++) {
        final bal = balances[i];
        if (bal <= 0) continue;
        final interestThisMonth = bal * monthlyRates[i];
        balances[i] = bal + interestThisMonth;
        interest[i] += interestThisMonth;
      }

      // 2. Minimum payments
      double availableCash = extraMonthlyPayment;
      for (var i = 0; i < count; i++) {
        final bal = balances[i];
        if (bal <= 0) continue;
        final baseMinPayment = baseMinPayments[i];
        final minPay = baseMinPayment.clamp(0.0, bal);
        balances[i] = bal - minPay;
        availableCash += (baseMinPayment - minPay);
      }

      // 3. Extra payment cascade
      for (var i = 0; i < count; i++) {
        final bal = balances[i];
        if (bal <= 0) continue;
        if (availableCash <= 0) break;
        final pay = availableCash.clamp(0.0, bal);
        balances[i] = bal - pay;
        availableCash -= pay;
      }

      // 4. Payoff check
      for (var i = 0; i < count; i++) {
        if (balances[i] <= 0.005 && payoffMonth[i] == null) {
          balances[i] = 0;
          payoffMonth[i] = month;
          activeCount--;
        }
      }
    }

    final entries = List<DebtPayoffEntry>.generate(count, (i) {
      return DebtPayoffEntry(
        debt: ordered[i],
        monthsToPayoff: payoffMonth[i] ?? month,
        interestPaid: interest[i],
      );
    });

    final totalMonths = entries.isEmpty
        ? 0
        : entries.map((e) => e.monthsToPayoff).reduce((a, b) => a > b ? a : b);

    final totalInterest =
        entries.fold<double>(0, (sum, e) => sum + e.interestPaid);

    final result = DebtPayoffResult(
      entries: entries,
      totalMonths: totalMonths,
      totalInterestPaid: totalInterest,
    );

    _cachedDebts = debts;
    _cachedExtraMonthlyPayment = extraMonthlyPayment;
    _cachedStrategy = strategy;
    _cachedResult = result;
    return result;
  }

  bool _debtsEqual(List<Debt>? a, List<Debt> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  double totalMinimumPayment(List<Debt> debts) =>
      debts.fold(0, (s, d) => s + d.minPayment);
}
