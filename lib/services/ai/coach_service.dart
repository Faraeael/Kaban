import '../coach_actions.dart';

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
  final List<String> suggestions;
  final bool remoteConfigured;

  const FinanceSnapshot({
    required this.walletBalances,
    required this.totalDebt,
    required this.monthIncome,
    required this.monthExpense,
    required this.monthExpenseByCategory,
    required this.debts,
    required this.suggestions,
    this.remoteConfigured = false,
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
  Future<CoachReply> ask(String userMessage, FinanceSnapshot snapshot);
  List<String> suggestedPrompts(FinanceSnapshot snapshot);
}
