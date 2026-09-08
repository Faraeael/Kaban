import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/models/debt.dart';
import 'package:finance_tracker/services/payoff_calculator.dart';

void main() {
  group('PayoffCalculator', () {
    final calc = PayoffCalculator();

    test('avalanche prioritizes highest APR', () {
      final result = calc.simulate(
        debts: const [
          Debt(
              id: 'a',
              name: 'Low APR loan',
              balance: 10000,
              apr: 5,
              minPayment: 250,
              strategy: DebtStrategy.avalanche),
          Debt(
              id: 'b',
              name: 'Credit card',
              balance: 5000,
              apr: 18,
              minPayment: 250,
              strategy: DebtStrategy.avalanche),
        ],
        extraMonthlyPayment: 0,
        strategy: DebtStrategy.avalanche,
      );

      final ordered = result.entries.toList();
      expect(ordered.first.debt.id, 'b');
      expect(ordered.last.debt.id, 'a');
    });

    test('snowball prioritizes smallest balance', () {
      final result = calc.simulate(
        debts: const [
          Debt(
              id: 'a',
              name: 'Big loan',
              balance: 10000,
              apr: 5,
              minPayment: 250,
              strategy: DebtStrategy.snowball),
          Debt(
              id: 'b',
              name: 'Small card',
              balance: 500,
              apr: 18,
              minPayment: 25,
              strategy: DebtStrategy.snowball),
        ],
        extraMonthlyPayment: 0,
        strategy: DebtStrategy.snowball,
      );

      final ordered = result.entries.toList();
      expect(ordered.first.debt.id, 'b');
    });

    test('extra payment shortens timeline', () {
      final debts = [
        const Debt(
            id: 'a',
            name: 'Loan',
            balance: 10000,
            apr: 10,
            minPayment: 250,
            strategy: DebtStrategy.avalanche),
      ];

      final noExtra = calc.simulate(
          debts: debts,
          extraMonthlyPayment: 0,
          strategy: DebtStrategy.avalanche);
      final withExtra = calc.simulate(
          debts: debts,
          extraMonthlyPayment: 1000,
          strategy: DebtStrategy.avalanche);

      expect(withExtra.totalMonths, lessThan(noExtra.totalMonths));
      expect(withExtra.totalInterestPaid, lessThan(noExtra.totalInterestPaid));
    });

    test('empty debt list returns zero result', () {
      final result = calc.simulate(
          debts: [], extraMonthlyPayment: 0, strategy: DebtStrategy.avalanche);
      expect(result.totalMonths, 0);
      expect(result.totalInterestPaid, 0);
      expect(result.entries, isEmpty);
    });

    test(
        'fixed schedule debt with zero minPayment uses balance/remainingPayments fallback',
        () {
      const debt = Debt(
        id: 'mariloan',
        name: 'MariLoan',
        balance: 16482.48,
        apr: 0,
        minPayment: 0,
        schedule: DebtSchedule.fixed,
        remainingPayments: 3,
        strategy: DebtStrategy.avalanche,
      );

      final result = calc.simulate(
        debts: [debt],
        extraMonthlyPayment: 0,
        strategy: DebtStrategy.avalanche,
      );

      expect(result.totalMonths, 3);
      expect(result.entries.first.monthsToPayoff, 3);
    });
  });
}
