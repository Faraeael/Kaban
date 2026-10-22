import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/models/debt.dart';
import 'package:finance_tracker/models/recurring_transaction.dart';
import 'package:finance_tracker/models/salary_plan.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/services/paycheck_planner.dart';

void main() {
  group('PaycheckPlanner', () {
    const salaryPlan = SalaryPlan(
      basicSalary: 60000,
      allowances: 0,
      payFrequency: PayFrequency.biMonthly15_30,
      autoCalculateDeductions: false,
      customSss: 1750,
      customPhilHealth: 1500,
      customPagIbig: 200,
      customTax: 5000,
      otherDeductions: 0,
    );
    // Total deductions = 8,450. Net monthly = 51,550. Per cutoff = 25,775. Gross per cutoff = 30,000.

    const debtMidMonth = Debt(
      id: 'd1',
      name: 'Credit Card A',
      balance: 10000,
      apr: 24,
      minPayment: 2500,
      strategy: DebtStrategy.avalanche,
      dueDay: 20,
    );

    const debtEarlyMonth = Debt(
      id: 'd2',
      name: 'Car Loan',
      balance: 150000,
      apr: 10,
      minPayment: 7000,
      strategy: DebtStrategy.avalanche,
      dueDay: 5,
    );

    const paidOffDebt = Debt(
      id: 'd3',
      name: 'Old Loan',
      balance: 0,
      apr: 0,
      minPayment: 1000,
      strategy: DebtStrategy.avalanche,
      dueDay: 22,
      paidOff: true,
    );

    final recurringBill = RecurringTransaction(
      id: 'r1',
      name: 'Internet Meralco',
      amount: 1800,
      type: TransactionType.expense,
      category: 'Utilities',
      intervalDays: 30,
      nextDue: DateTime(2025, 10, 22),
      walletId: 'w1',
    );

    test('Oct 15 payday funds Oct 16–31 debts and expenses', () {
      final window = PaycheckPlanner.calculateFundingWindow(
        salaryPlan: salaryPlan,
        debts: [debtMidMonth, debtEarlyMonth, paidOffDebt],
        recurring: [recurringBill],
        asOf: DateTime(2025, 10, 10), // before/on 15th
      );

      expect(window.payday, DateTime(2025, 10, 15));
      expect(window.windowStart, DateTime(2025, 10, 16));
      expect(window.windowEnd, DateTime(2025, 10, 31));
      expect(window.label, 'Oct 15 Paycheck');

      expect(window.grossIncomeThisPayday, 30000.0);
      expect(window.deductionsThisPayday, 4225.0);
      expect(window.netIncomeThisPayday, 25775.0);

      // debtMidMonth (dueDay 20) and recurringBill (nextDue Oct 22) should match
      // debtEarlyMonth (dueDay 5) must NOT match
      // paidOffDebt must NOT match
      expect(window.obligations.length, 2);
      expect(window.totalDebtDue, 2500.0);
      expect(window.totalBillsDue, 1800.0);
      expect(window.safeToSpend, 25775.0 - 2500.0 - 1800.0);
    });

    test('Oct 30 payday funds Nov 1–15 debts and expenses', () {
      final window = PaycheckPlanner.calculateFundingWindow(
        salaryPlan: salaryPlan,
        debts: [debtMidMonth, debtEarlyMonth, paidOffDebt],
        recurring: [recurringBill],
        asOf: DateTime(2025, 10, 20), // after 15th
      );

      expect(window.payday, DateTime(2025, 10, 30));
      expect(window.windowStart, DateTime(2025, 11, 1));
      expect(window.windowEnd, DateTime(2025, 11, 15));
      expect(window.label, 'Oct 30 Paycheck');

      // debtEarlyMonth (dueDay 5) matches Nov 1–15 window
      // debtMidMonth (dueDay 20) does NOT match
      // recurringBill (nextDue Oct 22) does NOT match Nov 1-15
      expect(window.obligations.length, 1);
      expect(window.obligations.first.title, 'Car Loan');
      expect(window.obligations.first.dueDate, DateTime(2025, 11, 5));
      expect(window.totalDebtDue, 7000.0);
      expect(window.totalBillsDue, 0.0);
      expect(window.safeToSpend, 25775.0 - 7000.0);
    });

    test('Monthly frequency funds entire next month cycle', () {
      final monthlyPlan = salaryPlan.copyWith(payFrequency: PayFrequency.monthly);
      final window = PaycheckPlanner.calculateFundingWindow(
        salaryPlan: monthlyPlan,
        debts: [debtMidMonth, debtEarlyMonth],
        recurring: [
          RecurringTransaction(
            id: 'r2',
            name: 'Gym',
            amount: 2000,
            type: TransactionType.expense,
            category: 'Fitness',
            intervalDays: 30,
            nextDue: DateTime(2025, 11, 8),
            walletId: 'w1',
          ),
        ],
        asOf: DateTime(2025, 10, 25),
      );

      expect(window.payday, DateTime(2025, 10, 30));
      expect(window.windowStart, DateTime(2025, 11, 1));
      expect(window.windowEnd, DateTime(2025, 11, 30));
      expect(window.grossIncomeThisPayday, 60000.0);
      expect(window.netIncomeThisPayday, 51550.0);

      // Both debts (dueDay 5 and 20) fall in Nov 1-30, and Gym falls in Nov
      expect(window.obligations.length, 3);
      expect(window.totalDebtDue, 2500.0 + 7000.0);
      expect(window.totalBillsDue, 2000.0);
      expect(window.safeToSpend, 51550.0 - 9500.0 - 2000.0);
    });
  });
}
