import '../models/debt.dart';
import '../models/recurring_transaction.dart';
import '../models/salary_plan.dart';
import '../models/transaction.dart';

class PaycheckObligation {
  final String id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final bool isDebt;
  final String? subtitle;

  const PaycheckObligation({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.isDebt,
    this.subtitle,
  });
}

class PaycheckFundingWindow {
  final DateTime payday;
  final DateTime windowStart;
  final DateTime windowEnd;
  final String label;
  final double grossIncomeThisPayday;
  final double deductionsThisPayday;
  final double netIncomeThisPayday;
  final List<PaycheckObligation> obligations;
  final double totalDebtDue;
  final double totalBillsDue;
  final double safeToSpend;

  const PaycheckFundingWindow({
    required this.payday,
    required this.windowStart,
    required this.windowEnd,
    required this.label,
    required this.grossIncomeThisPayday,
    required this.deductionsThisPayday,
    required this.netIncomeThisPayday,
    required this.obligations,
    required this.totalDebtDue,
    required this.totalBillsDue,
    required this.safeToSpend,
  });
}

class PaycheckPlanner {
  const PaycheckPlanner._();

  static const _monthNames = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static PaycheckFundingWindow calculateFundingWindow({
    required SalaryPlan salaryPlan,
    required List<Debt> debts,
    required List<RecurringTransaction> recurring,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final breakdown = salaryPlan.computeBreakdown();

    final DateTime payday;
    final DateTime windowStart;
    final DateTime windowEnd;
    final double grossIncome;
    final double deductions;
    final double netIncome;

    if (salaryPlan.payFrequency == PayFrequency.monthly) {
      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      final paydayDay = lastDay < 30 ? lastDay : 30;
      payday = DateTime(now.year, now.month, paydayDay);
      windowStart = DateTime(now.year, now.month + 1, 1);
      windowEnd = DateTime(now.year, now.month + 2, 0);

      grossIncome = salaryPlan.effectiveMonthlyBasic + salaryPlan.allowances;
      deductions = breakdown.totalDeductions;
      netIncome = breakdown.netMonthlyIncome;
    } else {
      // biMonthly15_30
      if (now.day <= 15) {
        payday = DateTime(now.year, now.month, 15);
        windowStart = DateTime(now.year, now.month, 16);
        windowEnd = DateTime(now.year, now.month + 1, 0);
      } else {
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        final paydayDay = lastDay < 30 ? lastDay : 30;
        payday = DateTime(now.year, now.month, paydayDay);
        windowStart = DateTime(now.year, now.month + 1, 1);
        windowEnd = DateTime(now.year, now.month + 1, 15);
      }

      grossIncome = (salaryPlan.effectiveMonthlyBasic + salaryPlan.allowances) / 2;
      deductions = breakdown.totalDeductions / 2;
      netIncome = breakdown.netMonthlyIncome / 2;
    }

    final obligations = <PaycheckObligation>[];

    // 1. Map active debts with dueDay falling in window
    for (final debt in debts) {
      if (debt.paidOff) continue;
      final dueDay = debt.dueDay;
      if (dueDay == null) continue;

      bool inWindow = false;
      DateTime dueDate;

      if (salaryPlan.payFrequency == PayFrequency.monthly) {
        // Whole next month cycle
        final clampedDay = dueDay.clamp(1, windowEnd.day);
        dueDate = DateTime(windowStart.year, windowStart.month, clampedDay);
        inWindow = true;
      } else {
        // Bi-monthly
        if (now.day <= 15) {
          // 16th to end of current month
          if (dueDay >= 16 && dueDay <= windowEnd.day) {
            inWindow = true;
            dueDate = DateTime(now.year, now.month, dueDay);
          } else {
            dueDate = DateTime(now.year, now.month, dueDay.clamp(1, windowEnd.day));
          }
        } else {
          // 1st to 15th of next month
          if (dueDay >= 1 && dueDay <= 15) {
            inWindow = true;
            dueDate = DateTime(windowStart.year, windowStart.month, dueDay);
          } else {
            dueDate = DateTime(windowStart.year, windowStart.month, dueDay.clamp(1, 15));
          }
        }
      }

      if (inWindow) {
        final amount = debt.minPayment > 0 ? debt.minPayment : debt.balance;
        obligations.add(
          PaycheckObligation(
            id: 'debt_${debt.id}',
            title: debt.name,
            amount: amount,
            dueDate: dueDate,
            isDebt: true,
            subtitle: debt.minPayment > 0 ? 'Min payment' : 'Full balance',
          ),
        );
      }
    }

    // 2. Map recurring expenses whose nextDue falls in [windowStart, windowEnd]
    final wStart = DateTime(windowStart.year, windowStart.month, windowStart.day);
    final wEnd = DateTime(windowEnd.year, windowEnd.month, windowEnd.day, 23, 59, 59);

    for (final rec in recurring) {
      if (!rec.enabled) continue;
      if (rec.type != TransactionType.expense) continue;

      if (!rec.nextDue.isBefore(wStart) && !rec.nextDue.isAfter(wEnd)) {
        obligations.add(
          PaycheckObligation(
            id: 'rec_${rec.id}',
            title: rec.name,
            amount: rec.amount,
            dueDate: rec.nextDue,
            isDebt: false,
            subtitle: rec.category,
          ),
        );
      }
    }

    // Sort obligations by due date
    obligations.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    double totalDebtDue = 0.0;
    double totalBillsDue = 0.0;
    for (final ob in obligations) {
      if (ob.isDebt) {
        totalDebtDue += ob.amount;
      } else {
        totalBillsDue += ob.amount;
      }
    }

    final safeToSpend = netIncome - totalDebtDue - totalBillsDue;
    final monthName = _monthNames[payday.month];
    final label = '$monthName ${payday.day} Paycheck';

    return PaycheckFundingWindow(
      payday: payday,
      windowStart: windowStart,
      windowEnd: windowEnd,
      label: label,
      grossIncomeThisPayday: grossIncome,
      deductionsThisPayday: deductions,
      netIncomeThisPayday: netIncome,
      obligations: obligations,
      totalDebtDue: totalDebtDue,
      totalBillsDue: totalBillsDue,
      safeToSpend: safeToSpend,
    );
  }
}
