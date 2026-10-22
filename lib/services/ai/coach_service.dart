import 'dart:typed_data';

import '../coach_actions.dart';
import '../../models/salary_plan.dart';
import '../paycheck_planner.dart';

class CoachReply {
  final String text;
  final List<CoachAction> actions;
  final List<String> warnings;

  const CoachReply({
    required this.text,
    this.actions = const [],
    this.warnings = const [],
  });
}

class FinanceSnapshot {
  final Map<String, double> walletBalances;
  final double totalDebt;
  final double monthIncome;
  final double monthExpense;
  final Map<String, double> monthExpenseByCategory;
  final List<DebtSnapshot> debts;
  final Map<String, double> budgets;
  final List<SubscriptionSnapshot> subscriptions;
  final List<String> suggestions;
  final bool remoteConfigured;
  final SalaryPlan? salaryPlan;
  final PaycheckFundingWindow? currentPaycheckWindow;

  const FinanceSnapshot({
    required this.walletBalances,
    required this.totalDebt,
    required this.monthIncome,
    required this.monthExpense,
    required this.monthExpenseByCategory,
    required this.debts,
    this.budgets = const {},
    this.subscriptions = const [],
    required this.suggestions,
    this.remoteConfigured = false,
    this.salaryPlan,
    this.currentPaycheckWindow,
  });
}

class SubscriptionSnapshot {
  final String name;
  final double amount;
  final String cadence;
  final String category;
  final DateTime nextBillingDate;

  const SubscriptionSnapshot({
    required this.name,
    required this.amount,
    required this.cadence,
    required this.category,
    required this.nextBillingDate,
  });
}

class DebtSnapshot {
  final String id;
  final String name;
  final double balance;
  final double apr;
  final double minPayment;
  final String strategy;
  final String schedule;
  final int? dueDay;
  final int? remainingPayments;
  final bool paidOff;
  final int? billingDay;
  final int? graceDays;

  const DebtSnapshot({
    required this.id,
    required this.name,
    required this.balance,
    required this.apr,
    required this.minPayment,
    required this.strategy,
    this.schedule = 'none',
    this.dueDay,
    this.remainingPayments,
    this.paidOff = false,
    this.billingDay,
    this.graceDays,
  });
}

abstract class CoachService {
  Future<CoachReply> ask(String userMessage, FinanceSnapshot snapshot,
      {Uint8List? imageBytes, String? imageMimeType});
  List<String> suggestedPrompts(FinanceSnapshot snapshot);
}
