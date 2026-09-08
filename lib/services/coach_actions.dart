import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';

const _uuid = Uuid();

sealed class CoachAction {
  const CoachAction();
}

class LogTransactionAction extends CoachAction {
  final double amount;
  final bool isIncome;
  final String category;
  final String? note;
  final String? walletName;
  const LogTransactionAction({
    required this.amount,
    required this.isIncome,
    required this.category,
    this.note,
    this.walletName,
  });
}

class UpdateDebtBalanceAction extends CoachAction {
  final String debtName;
  final double amount;
  final String? walletName;
  const UpdateDebtBalanceAction({
    required this.debtName,
    required this.amount,
    this.walletName,
  });
}

class AddToGoalAction extends CoachAction {
  final String goalName;
  final double amount;
  const AddToGoalAction({
    required this.goalName,
    required this.amount,
  });
}

class CreateDebtAction extends CoachAction {
  final Debt debt;
  const CreateDebtAction(this.debt);
}

class CreateGoalAction extends CoachAction {
  final Goal goal;
  const CreateGoalAction(this.goal);
}

class CreateRecurringAction extends CoachAction {
  final RecurringTransaction recurring;
  const CreateRecurringAction(this.recurring);
}

/// Result of the coach recognizing "I want to track a wallet".
class CreateWalletAction extends CoachAction {
  final String name;
  final double startingBalance;
  const CreateWalletAction({
    required this.name,
    this.startingBalance = 0,
  });
}

class UpdateWalletAction extends CoachAction {
  final String name;
  final String? newName;
  final double? newStartingBalance;
  final bool unarchive;
  const UpdateWalletAction({
    required this.name,
    this.newName,
    this.newStartingBalance,
    this.unarchive = false,
  });
}

class ArchiveWalletAction extends CoachAction {
  final String name;
  const ArchiveWalletAction({required this.name});
}

class AdjustWalletBalanceAction extends CoachAction {
  final String walletName;
  final double targetBalance;
  const AdjustWalletBalanceAction({
    required this.walletName,
    required this.targetBalance,
  });
}

class UpdateDebtAction extends CoachAction {
  final String name;
  final String? newName;
  final double? newBalance;
  final double? newApr;
  final double? newMinPayment;
  final DebtSchedule? newSchedule;
  final int? newDueDay;
  final int? newRemainingPayments;
  final int? newBillingDay;
  final int? newGraceDays;
  const UpdateDebtAction({
    required this.name,
    this.newName,
    this.newBalance,
    this.newApr,
    this.newMinPayment,
    this.newSchedule,
    this.newDueDay,
    this.newRemainingPayments,
    this.newBillingDay,
    this.newGraceDays,
  });
}

class DeleteDebtAction extends CoachAction {
  final String name;
  const DeleteDebtAction({required this.name});
}

class UpdateGoalAction extends CoachAction {
  final String name;
  final String? newName;
  final double? newTarget;
  final double? newSaved;
  const UpdateGoalAction({
    required this.name,
    this.newName,
    this.newTarget,
    this.newSaved,
  });
}

class DeleteGoalAction extends CoachAction {
  final String name;
  const DeleteGoalAction({required this.name});
}

class UpdateRecurringAction extends CoachAction {
  final String name;
  final double? newAmount;
  final String? newFrequency;
  final bool? newEnabled;
  final bool delete;
  const UpdateRecurringAction({
    required this.name,
    this.newAmount,
    this.newFrequency,
    this.newEnabled,
    this.delete = false,
  });
}

/// Amount token: ₱1,000.50 / 100 pesos / 2k / ₱50
const String _amt =
    r'([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?(?:[kKmM](?![a-zA-Z]))?)';

/// Regex-based parser that runs on the coach's reply text plus the user's
/// message for context. Only emits actions from unambiguous patterns.
class CoachActionParser {
  // "I spent 200 on food" / "paid ₱150 for coffee" / "paid 13 to jeep" / "Paid PHP13 to Jeep put it under Cash"
  static final _expenseRegex = RegExp(
    r'(?:spent|paid|bought)(?:\s+(?:again|another|also))?\s+(?:(?:₱|PHP|PhP|php)\s*)?'
    '$_amt'
    r'(?:\s*(?:₱|PHP|PhP|php|pesos?))?'
    r'\s+(?:on|for|at|with|to|in)\s+(?:a\s+|an\s+)?([A-Za-z][A-Za-z ]{1,30}?)(?=[\s]*[,.\n]|$|\s+(?:from|at|via|using|and|but|put\s+it\s+under|under)\s)',
    caseSensitive: false,
  );

  // "paid to jeep 15" / "paid a jeep 15 pesos" / "paid again to a jeep 15PHP this time"
  static final _expenseAltRegex = RegExp(
    r'(?:spent|paid|bought)(?:\s+(?:again|another|also))?\s+(?:to|for|on|at)?\s*(?:a\s+|an\s+)?([A-Za-z][A-Za-z ]{1,25}?)\s+(?:(?:₱|PHP|PhP|php)\s*)?'
    '$_amt'
    r'(?:\s*(?:₱|PHP|PhP|php|pesos?))?',
    caseSensitive: false,
  );

  // "I earned 5000" / "received ₱2000" / "salary of 25k"
  static final _incomeRegex = RegExp(
    r'(?:earned|received|got paid|salary(?: of)?|income of)\s+(?:₱|PHP|PhP|php)?\s?'
    '$_amt',
    caseSensitive: false,
  );

  // "paid 500 to my BDO card" / "paying 1000 toward BDO"
  static final _debtPaymentRegex = RegExp(
    r'(?:paid|paying|payment of)\s+(?:₱|PHP|PhP|php)?\s?'
    '$_amt'
    r'\s+(?:to|toward|towards|on|off)\s+(?:my\s+|the\s+)?([A-Za-z][A-Za-z0-9 ]{1,30}?)(?=[\s]*[,.\n]|$|\s+(?:from|at|via|using|and|but|today|yesterday|last)\s)',
    caseSensitive: false,
  );

  // "put 1000 toward travel" / "saved 500 into emergency"
  static final _goalAddRegex = RegExp(
    r'(?:put|added|saved|deposited|transferred)\s+(?:₱|PHP|PhP|php)?\s?'
    '$_amt'
    r'\s+(?:to|toward|towards|into)\s+(?:my\s+|the\s+)?([A-Za-z][A-Za-z0-9 ]{1,30}?)(?=[\s]*[,.\n]|$|\s+(?:from|at|via|using|and|but|today|yesterday|last)\s)',
    caseSensitive: false,
  );

  // "I spend 100 every day on commute" / "200 monthly for gym"
  static final _recurringRegex = RegExp(
    r'(?:spend|pay|charge[d]?|cost[s]?)\s+(?:₱|PHP|PhP|php)?\s?'
    '$_amt'
    r'\s+(?:every\s+)?(day|daily|week|weekly|month|monthly|bi-?weekly|fortnight|year|yearly)\s+(?:on|for)\s+([A-Za-z][A-Za-z ]{1,30}?)(?=[\s]*[,.\n]|$|\s+(?:from|at|via|using|and|but|today|yesterday|last)\s)',
    caseSensitive: false,
  );

  // "I got a new BDO account" / "add a Maya wallet with 5000" /
  // "create a GCash account" / "add a credit card"
  static final _walletCreateRegex = RegExp(
    r'(?:add|create|open|got|received|just got|i\s+got|i\s+received|i\s+opened)\s+'
    r'(?:a\s+|an\s+|new\s+)?'
    r'(?:[A-Za-z][A-Za-z ]{1,25}?\s+)?'
    r'(?:e-?wallet|wallet|account|ewallet|credit\s+card|debit\s+card|bank\s+account|card)\b',
    caseSensitive: false,
  );

  // starting balance after the wallet keyword, e.g. "account with 5000"
  static final _walletBalanceRegex = RegExp(
    r'(?:with\s+(?:a\s+|an\s+|initial\s+|starting\s+|balance\s+of\s+|balance\s+)?₱?\s*|₱\s*)'
    '$_amt',
    caseSensitive: false,
  );

  // "received 85.20 interest from GoTyme" / "earned 12.50 interest"
  static final _interestIncomeRegex = RegExp(
    r'(?:received|got|earned|credited)?\s*(?:₱|PHP|PhP|php)?\s*'
    '$_amt'
    r'\s*(?:in\s+)?interest\s*(?:from|in|on)?\s*(?:my\s+)?([A-Za-z][A-Za-z0-9 ]{1,25}?)?(?=[\s]*[,.\n]|$)',
    caseSensitive: false,
  );

  static final _interestIncomeAltRegex = RegExp(
    r'interest\s+(?:of\s+)?(?:₱|PHP|PhP|php)?\s*'
    '$_amt'
    r'\s*(?:from|in|on)?\s*(?:my\s+)?([A-Za-z][A-Za-z0-9 ]{1,25}?)?(?=[\s]*[,.\n]|$)',
    caseSensitive: false,
  );

  // "My MariBank balance is 50420.50" / "MariBank balance is 50000"
  static final _balanceAdjustRegex = RegExp(
    r'(?:my\s+)?([A-Za-z][A-Za-z0-9 ]{1,25}?)\s+balance\s+(?:is|now)\s+(?:₱|PHP|PhP|php)?\s*'
    '$_amt',
    caseSensitive: false,
  );

  // "Adjust MariBank balance to 50420.50" / "Reconcile GoTyme to 15000"
  static final _balanceAdjustAltRegex = RegExp(
    r'(?:adjust|reconcile|set)\s+(?:my\s+)?([A-Za-z][A-Za-z0-9 ]{1,25}?)(?:\s+balance)?\s+(?:to|at)\s+(?:₱|PHP|PhP|php)?\s*'
    '$_amt',
    caseSensitive: false,
  );

  static const _frequencyDays = {
    'day': 1,
    'daily': 1,
    'week': 7,
    'weekly': 7,
    'bi-weekly': 14,
    'biweekly': 14,
    'fortnight': 14,
    'month': 30,
    'monthly': 30,
    'year': 365,
    'yearly': 365,
  };

  static const _expenseCategories = [
    'Food',
    'Transport',
    'Entertainment',
    'Shopping',
    'Utilities',
    'Health',
    'Subscriptions',
    'Housing',
    'Education',
    'Travel',
    'Insurance',
    'Personal Care',
    'Groceries',
    'Dining Out',
    'Other',
  ];

  static const _incomeCategories = [
    'Salary',
    'Freelance',
    'Bonus',
    'Refund',
    'Gift',
    'Investment',
    'Other',
  ];

  List<CoachAction> parse({
    required String assistantReply,
    String? userMessage,
  }) {
    final actions = <CoachAction>{};
    final hasUserMessage = userMessage != null && userMessage.isNotEmpty;
    final combined =
        hasUserMessage ? '$userMessage\n$assistantReply' : assistantReply;
    final walletText = hasUserMessage ? userMessage : assistantReply;

    // Recurring intents first — they take priority over one-time expense
    // matches on the same text ("I spend 100 every day on commute").
    for (final match in _recurringRegex.allMatches(combined)) {
      final amount = _parseAmount(match.group(1) ?? '');
      final freqKey = (match.group(2) ?? '').toLowerCase();
      final freqDays = _frequencyDays[freqKey];
      if (amount <= 0 || freqDays == null) continue;
      final name = (match.group(3) ?? '').trim();
      if (name.isEmpty) continue;
      actions.add(CreateRecurringAction(RecurringTransaction(
        id: 'coach_${match.start}_$freqDays',
        name: name,
        amount: amount,
        type: TransactionType.expense,
        category: _matchCategory(name, _expenseCategories),
        intervalDays: freqDays,
        nextDue: DateTime.now(),
        walletId: '',
      )));
    }

    // Wallet-creation intents. Run after recurring so "I spend 100 every day
    // on commute" doesn't get misread as "add a wallet". Wallet verbs are
    // specific enough that overlap with expense/income is unlikely.
    final wMatch = _walletCreateRegex.firstMatch(walletText);
    if (wMatch != null) {
      final lower = walletText.toLowerCase();
      // Resolve the brand name from the known list (longest name first so
      // "Security Bank" wins over "Bank").
      String name = 'New wallet';
      final sorted = [...kWalletPresets]
        ..sort((a, b) => b.name.length - a.name.length);
      for (final p in sorted) {
        if (lower.contains(p.name.toLowerCase())) {
          name = p.name;
          break;
        }
      }
      // Optional starting balance after the wallet keyword.
      double? startingBalance;
      final rest = walletText.substring(wMatch.end);
      final bMatch = _walletBalanceRegex.firstMatch(rest);
      if (bMatch != null) startingBalance = _parseAmount(bMatch.group(1) ?? '');
      // Skip if the same sentence already produced a transaction-style action.
      if (!actions.any((a) => a is CreateRecurringAction)) {
        actions.add(CreateWalletAction(
          name: name,
          startingBalance: startingBalance ?? 0,
        ));
      }
    }

    for (final match in _expenseRegex.allMatches(combined)) {
      // Skip if this expense match overlaps a recurring match already captured.
      if (_overlapsRecurring(match.start, match.end, combined)) continue;
      final hint = (match.group(2) ?? '').trim();
      if (_isDebtHint(hint)) continue;
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount <= 0) continue;
      final wallet = _matchWalletName(combined);
      actions.add(LogTransactionAction(
        amount: amount,
        isIncome: false,
        category: _matchCategory(
            hint.isNotEmpty ? hint : combined, _expenseCategories),
        note: hint.isEmpty ? null : hint,
        walletName: wallet,
      ));
    }

    for (final match in _expenseAltRegex.allMatches(combined)) {
      if (_overlapsRecurring(match.start, match.end, combined)) continue;
      final hint = (match.group(1) ?? '').trim();
      if (_isDebtHint(hint)) continue;
      final amount = _parseAmount(match.group(2) ?? '');
      if (amount <= 0) continue;
      if (actions.any((a) =>
          a is LogTransactionAction &&
          !a.isIncome &&
          (a.amount - amount).abs() < 0.005)) {
        continue;
      }
      final wallet = _matchWalletName(combined);
      actions.add(LogTransactionAction(
        amount: amount,
        isIncome: false,
        category: _matchCategory(
            hint.isNotEmpty ? hint : combined, _expenseCategories),
        note: hint.isEmpty ? null : hint,
        walletName: wallet,
      ));
    }

    // Balance adjustments: "My MariBank balance is 50420.50" / "Adjust GoTyme to 15000"
    for (final match in _balanceAdjustRegex.allMatches(combined)) {
      final walletHint = (match.group(1) ?? '').trim();
      final wallet = _matchWalletName(walletHint);
      final amount = _parseAmount(match.group(2) ?? '');
      if (wallet != null && amount >= 0) {
        actions.add(AdjustWalletBalanceAction(
          walletName: wallet,
          targetBalance: amount,
        ));
      }
    }
    for (final match in _balanceAdjustAltRegex.allMatches(combined)) {
      final walletHint = (match.group(1) ?? '').trim();
      final wallet = _matchWalletName(walletHint);
      final amount = _parseAmount(match.group(2) ?? '');
      if (wallet != null && amount >= 0) {
        actions.add(AdjustWalletBalanceAction(
          walletName: wallet,
          targetBalance: amount,
        ));
      }
    }

    // Interest credits: "received 85.20 interest from GoTyme"
    final interestMatches = [
      ..._interestIncomeRegex.allMatches(combined),
      ..._interestIncomeAltRegex.allMatches(combined),
    ];
    for (final match in interestMatches) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount <= 0) continue;
      final walletHint = (match.group(2) ?? '').trim();
      final wallet =
          _matchWalletName(walletHint.isNotEmpty ? walletHint : combined);
      actions.add(LogTransactionAction(
        amount: amount,
        isIncome: true,
        category: 'Investment',
        note: 'Interest',
        walletName: wallet,
      ));
    }

    for (final match in _incomeRegex.allMatches(combined)) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount <= 0) continue;
      if (actions.any((a) =>
          (a is LogTransactionAction &&
              a.isIncome &&
              (a.amount - amount).abs() < 0.005) ||
          (a is AdjustWalletBalanceAction &&
              (a.targetBalance - amount).abs() < 0.005))) {
        continue;
      }
      final before = combined.substring(max(0, match.start - 40), match.start);
      actions.add(LogTransactionAction(
        amount: amount,
        isIncome: true,
        category: _matchCategory(before, _incomeCategories),
      ));
    }

    for (final match in _debtPaymentRegex.allMatches(combined)) {
      final amount = _parseAmount(match.group(1) ?? '');
      final debtName = (match.group(2) ?? '').trim();
      if (amount <= 0 || debtName.isEmpty) continue;
      // Skip if this amount was already captured as an expense
      if (actions.any((a) =>
          a is LogTransactionAction &&
          !a.isIncome &&
          (a.amount - amount).abs() < 0.005)) {
        continue;
      }
      // If the target matches a recognized expense category (e.g. Jeep -> Transport, Jollibee -> Food), skip debt payment
      final cat = _matchCategory(debtName, _expenseCategories);
      if (cat != 'Other') {
        continue;
      }
      final wallet = _matchWalletName(combined, exclude: debtName);
      actions.add(UpdateDebtBalanceAction(
        debtName: debtName,
        amount: amount,
        walletName: wallet,
      ));
    }

    for (final match in _goalAddRegex.allMatches(combined)) {
      final amount = _parseAmount(match.group(1) ?? '');
      final goalName = (match.group(2) ?? '').trim();
      if (amount <= 0 || goalName.isEmpty) continue;
      actions.add(AddToGoalAction(goalName: goalName, amount: amount));
    }

    // Debt creation intents (e.g. "now add SPAY Total Balance: 50,692.25..." or "Adding SPAY: ₱6,213.65/mo...")
    for (final debtAct in _parseCreateDebts(combined)) {
      actions.add(debtAct);
    }
    if (!actions.any((a) => a is CreateDebtAction) && hasUserMessage) {
      for (final debtAct in _parseCreateDebts(userMessage)) {
        actions.add(debtAct);
      }
    }
    if (!actions.any((a) => a is CreateDebtAction)) {
      for (final debtAct in _parseCreateDebts(assistantReply)) {
        actions.add(debtAct);
      }
    }

    // Goal creation intents (e.g. "create goal emergency fund target 50000")
    final goalAct = _parseCreateGoal(combined) ??
        (hasUserMessage ? _parseCreateGoal(userMessage) : null) ??
        _parseCreateGoal(assistantReply);
    if (goalAct != null) {
      actions.add(goalAct);
    }

    return actions.toList();
  }

  List<CreateDebtAction> _parseCreateDebts(String text) {
    final results = <CreateDebtAction>[];
    final blocks = text.split(RegExp(
        r'\n{2,}|\n(?=[A-Za-z0-9_\- ]+:)|\b(?=now\s+add\b|add\s+(?:debt|loan|card)\b|Adding\s+[A-Za-z0-9_\- ]+:)'));
    for (final block in blocks) {
      final single = _parseSingleCreateDebt(block);
      if (single != null &&
          !results.any((r) =>
              r.debt.name.toLowerCase() == single.debt.name.toLowerCase())) {
        results.add(single);
      }
    }
    if (results.isEmpty) {
      final fallback = _parseSingleCreateDebt(text);
      if (fallback != null) results.add(fallback);
    }
    return results;
  }

  CreateDebtAction? _parseSingleCreateDebt(String text) {
    final lower = text.toLowerCase();
    final hasDebtKeyword = lower.contains('add') ||
        lower.contains('adding') ||
        lower.contains('debt') ||
        lower.contains('loan') ||
        lower.contains('installment') ||
        lower.contains('spay') ||
        lower.contains('sloan');
    if (!hasDebtKeyword) return null;

    // 1. Extract name
    String? name;
    final nameMatch = RegExp(
      r'(?:now\s+add|add(?:\s+a|\s+new)?(?:\s+debt|\s+loan|\s+card)?|adding)\s+([A-Za-z0-9_\- ]{2,30}?)(?=\s*(?:\n|:|,|\bas\b|\bwith\b|\btotal\b|\bbalance\b|\bmin\b|$))',
      caseSensitive: false,
    ).firstMatch(text);
    if (nameMatch != null) {
      final cand = nameMatch.group(1)!.trim();
      final candLower = cand.toLowerCase();
      if (candLower != 'debt' && candLower != 'loan' && candLower != 'card') {
        name = cand;
      }
    }
    if (name == null) {
      final labelMatch = RegExp(
              r'(?:debt|name|loan)[:\s]+([A-Za-z0-9_\- ]{2,30})',
              caseSensitive: false)
          .firstMatch(text);
      if (labelMatch != null) name = labelMatch.group(1)!.trim();
    }
    if (name == null || name.isEmpty) return null;

    // 2. Extract balance
    double? balance;
    final balMatch = RegExp(
      r'(?:total\s+balance|balance|total\s+amount|\(total)\s*[:\s]*₱?\s*' +
          _amt,
      caseSensitive: false,
    ).firstMatch(text);
    if (balMatch != null) {
      balance = _parseAmount(balMatch.group(1) ?? '');
    }

    // 3. Extract min payment / installment
    double? minPayment;
    final minMatch = RegExp(
          r'(?:min[._\s]*payment|monthly(?:\s+payment)?|installment|per\s+month|\/mo(?:nth)?)\s*[:\s]*₱?\s*' +
              _amt,
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'₱?\s*' + _amt + r'\s*(?:\/mo(?:nth)?|per\s+month|monthly)',
          caseSensitive: false,
        ).firstMatch(text);
    if (minMatch != null) {
      minPayment = _parseAmount(minMatch.group(1) ?? '');
    }

    // 4. Extract due day
    int? dueDay;
    final dueMatch = RegExp(
      r'(?:due(?:\s+date|\s+day)?(?:\s+every)?|every)\s*[:\s]*(?:every\s+)?([0-9]{1,2})(?:st|nd|rd|th)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (dueMatch != null) {
      dueDay = int.tryParse(dueMatch.group(1) ?? '');
    }

    // 5. Extract remaining payments / term
    int? remaining;
    final termMatch = RegExp(
          r'([0-9]{1,3})\s*(?:mths?|months?|payments?|installments?)(?:\s+(?:left|remaining))?',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'(?:for|term(?:\s+of)?)\s+([0-9]{1,3})\s*(?:mths?|months?|payments?|installments?)',
          caseSensitive: false,
        ).firstMatch(text);
    if (termMatch != null) {
      remaining = int.tryParse(termMatch.group(1) ?? '');
    }

    // 6. Extract APR
    double apr = 0.0;
    final aprMatch = RegExp(
      r'([0-9]+(?:\.[0-9]+)?)\s*%\s*apr|apr\s*[:\s]*([0-9]+(?:\.[0-9]+)?)%?',
      caseSensitive: false,
    ).firstMatch(text);
    if (aprMatch != null) {
      final aprStr = aprMatch.group(1) ?? aprMatch.group(2) ?? '0';
      apr = double.tryParse(aprStr) ?? 0.0;
    }

    // Balance/minPayment fallbacks
    if ((balance == null || balance <= 0) &&
        minPayment != null &&
        remaining != null) {
      balance = (minPayment * remaining * 100).round() / 100.0;
    }
    if ((minPayment == null || minPayment <= 0) &&
        balance != null &&
        remaining != null &&
        remaining > 0) {
      minPayment = (balance / remaining * 100).round() / 100.0;
    }

    if (balance == null || balance <= 0) return null;

    final schedule = (remaining != null || dueDay != null || minPayment != null)
        ? DebtSchedule.fixed
        : DebtSchedule.none;

    return CreateDebtAction(Debt(
      id: _uuid.v4(),
      name: name,
      balance: balance,
      apr: apr,
      minPayment: minPayment ?? 0.0,
      strategy: DebtStrategy.avalanche,
      schedule: schedule,
      dueDay: dueDay,
      remainingPayments: remaining,
    ));
  }

  CreateGoalAction? _parseCreateGoal(String text) {
    final lower = text.toLowerCase();
    if (!lower.contains('goal') && !lower.contains('target')) return null;
    final match = RegExp(
      r'(?:add|create|save\s+for|new)\s+(?:a\s+)?goal\s+(?:for\s+|named\s+)?([A-Za-z0-9_\- ]{2,30}?)\s+(?:with\s+(?:a\s+)?target\s+(?:of\s+)?|target\s*[:\s]*)\s*₱?\s*' +
          _amt,
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      final name = match.group(1)!.trim();
      final target = _parseAmount(match.group(2) ?? '');
      if (name.isNotEmpty && target > 0) {
        return CreateGoalAction(Goal(
          id: _uuid.v4(),
          name: name,
          target: target,
          saved: 0,
        ));
      }
    }
    return null;
  }

  bool _overlapsRecurring(int start, int end, String combined) {
    for (final match in _recurringRegex.allMatches(combined)) {
      if (start < match.end && end > match.start) return true;
    }
    return false;
  }

  static double parseAmount(String raw) => _parseAmount(raw);

  static double _parseAmount(String raw) {
    if (raw.isEmpty) return 0;
    var cleaned = raw.replaceAll(',', '').toLowerCase();
    double multiplier = 1;
    if (cleaned.endsWith('k')) {
      multiplier = 1000;
      cleaned = cleaned.substring(0, cleaned.length - 1);
    } else if (cleaned.endsWith('m')) {
      multiplier = 1000000;
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return multiplier * (double.tryParse(cleaned) ?? 0);
  }

  static bool _isDebtHint(String text) {
    final lower = text.toLowerCase();
    return lower.contains('card') ||
        lower.contains('loan') ||
        lower.contains('debt') ||
        lower.contains('spay') ||
        lower.contains('sloan');
  }

  static String? _matchWalletName(String text, {String? exclude}) {
    // 1. First look for explicit prepositional wallet indicators: "from Maya", "using GCash", "via BPI", "under Cash", "through Maya"
    final prepMatches = RegExp(
      r'(?:from|using|via|through|under|out\s+of|with|in)\s+(?:my\s+|the\s+)?([A-Za-z0-9_\- ]{2,25}?)(?=[\s]*[,.\n]|$|\s+(?:and|but|today|yesterday)\s)',
      caseSensitive: false,
    ).allMatches(text);
    for (final m in prepMatches) {
      final cand = m.group(1)?.trim();
      if (cand != null && cand.isNotEmpty) {
        final matched = _matchPresetOrCash(cand);
        if (matched != null) return matched;
      }
    }

    // 2. Otherwise, scan the text optionally excluding the given phrase (e.g. debt name)
    var textToScan = text;
    if (exclude != null && exclude.trim().isNotEmpty) {
      textToScan = text.replaceAll(
          RegExp(RegExp.escape(exclude.trim()), caseSensitive: false), ' ');
    }
    return _matchPresetOrCash(textToScan);
  }

  static String? _matchPresetOrCash(String text) {
    if (RegExp(r'\b(?:cash\s+on\s+hand|cash)\b', caseSensitive: false)
        .hasMatch(text)) {
      return 'Cash';
    }
    final lower = text.toLowerCase();
    final sortedPresets = [...kWalletPresets]
      ..sort((a, b) => b.name.length - a.name.length);
    for (final p in sortedPresets) {
      final pNameLower = p.name.toLowerCase();
      if (pNameLower.length <= 4) {
        if (RegExp(r'\b' + RegExp.escape(pNameLower) + r'\b').hasMatch(lower)) {
          return p.name;
        }
      } else {
        if (lower.contains(pNameLower)) {
          return p.name;
        }
      }
    }
    return null;
  }

  static String _matchCategory(String raw, List<String> haystack) {
    final lower = raw.toLowerCase();
    for (final c in haystack) {
      if (lower.contains(c.toLowerCase())) return c;
    }
    if (lower.contains('interest') || lower.contains('dividend')) {
      return 'Investment';
    }
    if (lower.contains('restaurant') ||
        lower.contains('coffee') ||
        lower.contains('resto') ||
        lower.contains('jollibee') ||
        lower.contains('mcdo') ||
        lower.contains('food') ||
        lower.contains('lunch') ||
        lower.contains('dinner') ||
        lower.contains('breakfast') ||
        lower.contains('snack') ||
        lower.contains('starbucks') ||
        lower.contains('chowking') ||
        lower.contains('mang inasal')) {
      return 'Food';
    }
    if (lower.contains('gas') ||
        lower.contains('taxi') ||
        lower.contains('commute') ||
        lower.contains('grab') ||
        lower.contains('jeep') ||
        lower.contains('jeepney') ||
        lower.contains('fare') ||
        lower.contains('trike') ||
        lower.contains('tricycle') ||
        lower.contains('bus') ||
        lower.contains('mrt') ||
        lower.contains('lrt') ||
        lower.contains('train') ||
        lower.contains('angkas') ||
        lower.contains('joyride') ||
        lower.contains('beep')) {
      return 'Transport';
    }
    if (lower.contains('grocery') ||
        lower.contains('groceries') ||
        lower.contains('supermarket') ||
        lower.contains('puregold') ||
        lower.contains('robinsons') ||
        lower.contains('savemore')) {
      return 'Groceries';
    }
    if (lower.contains('movie') ||
        lower.contains('netflix') ||
        lower.contains('game')) {
      return 'Entertainment';
    }
    if (lower.contains('bill') ||
        lower.contains('electric') ||
        lower.contains('water') ||
        lower.contains('meralco')) {
      return 'Utilities';
    }
    return haystack.last;
  }
}

double? _toDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) {
    var cleaned = val.trim().replaceAll(RegExp(r'^[₱$PHPphp\s]+'), '');
    cleaned = cleaned.replaceAll(',', '').trim();
    double mult = 1.0;
    if (cleaned.toLowerCase().endsWith('k')) {
      mult = 1000.0;
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    } else if (cleaned.toLowerCase().endsWith('m') &&
        !cleaned.toLowerCase().endsWith('mths') &&
        !cleaned.toLowerCase().endsWith('months')) {
      mult = 1000000.0;
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    final match = RegExp(r'[0-9]+(?:\.[0-9]+)?').firstMatch(cleaned);
    if (match != null) {
      final parsed = double.tryParse(match.group(0)!);
      if (parsed != null) return mult * parsed;
    }
  }
  return null;
}

int? _toInt(dynamic val) {
  if (val == null) return null;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) {
    final match = RegExp(r'\d+').firstMatch(val);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
  }
  return null;
}

CoachAction? parseJsonAction(Map<String, dynamic> m) {
  try {
    final typeRaw = (m['type'] ?? m['action'] ?? m['action_type']) as String?;
    if (typeRaw == null) return null;
    final type = typeRaw.toLowerCase().trim();
    switch (type) {
      case 'create_wallet':
      case 'add_wallet':
        final name = (m['name'] ?? m['wallet_name'])?.toString().trim();
        if (name == null || name.isEmpty) return null;
        final balance =
            _toDouble(m['starting_balance'] ?? m['balance'] ?? m['amount']) ??
                0.0;
        return CreateWalletAction(name: name, startingBalance: balance);

      case 'update_wallet':
        final name = (m['name'] ?? m['wallet_name'])?.toString().trim();
        if (name == null || name.isEmpty) return null;
        return UpdateWalletAction(
          name: name,
          newName: (m['new_name'] ?? m['name'])?.toString().trim(),
          newStartingBalance:
              _toDouble(m['new_starting_balance'] ?? m['starting_balance']),
          unarchive: (m['unarchive'] as bool?) ?? false,
        );

      case 'archive_wallet':
        final name = (m['name'] ?? m['wallet_name'])?.toString().trim();
        if (name == null || name.isEmpty) return null;
        return ArchiveWalletAction(name: name);

      case 'adjust_wallet_balance':
        final name = (m['name'] ?? m['wallet_name'])?.toString().trim();
        final target =
            _toDouble(m['target_balance'] ?? m['balance'] ?? m['amount']);
        if (name == null || name.isEmpty || target == null || target < 0) {
          return null;
        }
        return AdjustWalletBalanceAction(
            walletName: name, targetBalance: target);

      case 'log_income':
        final amount = _toDouble(m['amount']);
        if (amount == null || amount <= 0) return null;
        final walletName = (m['wallet_name'] ?? m['wallet'])?.toString().trim();
        return LogTransactionAction(
          amount: amount,
          isIncome: true,
          category: (m['category'])?.toString().trim() ?? 'Salary',
          note: (m['note'])?.toString().trim(),
          walletName:
              walletName != null && walletName.isNotEmpty ? walletName : null,
        );

      case 'log_expense':
        final amount = _toDouble(m['amount']);
        if (amount == null || amount <= 0) return null;
        final walletName = (m['wallet_name'] ?? m['wallet'])?.toString().trim();
        return LogTransactionAction(
          amount: amount,
          isIncome: false,
          category: (m['category'])?.toString().trim() ?? 'Other',
          note: (m['note'])?.toString().trim(),
          walletName:
              walletName != null && walletName.isNotEmpty ? walletName : null,
        );

      case 'create_debt':
      case 'add_debt':
      case 'new_debt':
        final name =
            (m['name'] ?? m['debt_name'] ?? m['title'])?.toString().trim();
        var balance = _toDouble(
            m['balance'] ?? m['total_balance'] ?? m['amount'] ?? m['total']);
        final apr = _toDouble(m['apr'] ?? m['interest_rate']) ?? 0.0;
        var minPay = _toDouble(m['min_payment'] ??
                m['monthly_payment'] ??
                m['installment'] ??
                m['payment'] ??
                m['min_pay']) ??
            0.0;
        final schedRaw = (m['schedule'] ?? m['debt_schedule'])?.toString();
        final schedLower = schedRaw?.toLowerCase();
        final schedule = schedLower != null
            ? (schedLower.contains('fix') || schedLower.contains('install')
                ? DebtSchedule.fixed
                : (schedLower.contains('cycle') ||
                        schedLower.contains('statement') ||
                        schedLower.contains('card')
                    ? DebtSchedule.statementCycle
                    : DebtSchedule.none))
            : ((m['due_day'] != null ||
                    m['remaining_payments'] != null ||
                    m['months_left'] != null)
                ? DebtSchedule.fixed
                : ((m['billing_day'] != null || m['grace_days'] != null)
                    ? DebtSchedule.statementCycle
                    : DebtSchedule.none));
        final dueDay = _toInt(m['due_day'] ?? m['due_date'] ?? m['due']);
        final remaining = _toInt(m['remaining_payments'] ??
            m['months_left'] ??
            m['payments_left'] ??
            m['installments_left'] ??
            m['term']);
        final billingDay = _toInt(m['billing_day'] ?? m['statement_day']);
        final graceDays = _toInt(m['grace_days'] ?? m['grace_period']);

        if ((balance == null || balance <= 0) &&
            minPay > 0 &&
            remaining != null &&
            remaining > 0) {
          balance = (minPay * remaining * 100).round() / 100.0;
        }
        if (minPay <= 0 &&
            balance != null &&
            balance > 0 &&
            schedule == DebtSchedule.fixed &&
            remaining != null &&
            remaining > 0) {
          minPay = (balance / remaining * 100).round() / 100.0;
        }

        if (name == null || name.isEmpty || balance == null || balance <= 0) {
          return null;
        }

        final debt = Debt(
          id: _uuid.v4(),
          name: name,
          balance: balance,
          apr: apr,
          minPayment: minPay,
          strategy: DebtStrategy.avalanche,
          schedule: schedule,
          dueDay: dueDay,
          remainingPayments: remaining,
          billingDay: billingDay,
          graceDays: graceDays,
        );
        return CreateDebtAction(debt);

      case 'pay_debt':
      case 'update_debt_balance':
        final name = (m['name'] ?? m['debt_name'])?.toString().trim();
        final amount = _toDouble(m['amount']);
        final wallet = (m['wallet_name'] ?? m['wallet'] ?? m['walletName'])
            ?.toString()
            .trim();
        if (name == null || name.isEmpty || amount == null || amount <= 0) {
          return null;
        }
        return UpdateDebtBalanceAction(
          debtName: name,
          amount: amount,
          walletName: (wallet != null && wallet.isNotEmpty) ? wallet : null,
        );

      case 'update_debt':
        final name = (m['name'] ?? m['debt_name'])?.toString().trim();
        if (name == null || name.isEmpty) return null;
        final schedRaw = (m['new_schedule'] ?? m['schedule'])?.toString();
        final schedLower = schedRaw?.toLowerCase();
        final newSchedule = schedLower != null
            ? (schedLower.contains('fix') || schedLower.contains('install')
                ? DebtSchedule.fixed
                : (schedLower.contains('cycle') ||
                        schedLower.contains('statement') ||
                        schedLower.contains('card')
                    ? DebtSchedule.statementCycle
                    : DebtSchedule.none))
            : null;
        return UpdateDebtAction(
          name: name,
          newName: (m['new_name'] ?? m['newName'])?.toString().trim(),
          newBalance: _toDouble(m['new_balance'] ?? m['balance']),
          newApr: _toDouble(m['new_apr'] ?? m['apr']),
          newMinPayment: _toDouble(m['new_min_payment'] ?? m['min_payment']),
          newSchedule: newSchedule,
          newDueDay: _toInt(m['new_due_day'] ?? m['due_day']),
          newRemainingPayments:
              _toInt(m['new_remaining_payments'] ?? m['remaining_payments']),
          newBillingDay: _toInt(m['new_billing_day'] ?? m['billing_day']),
          newGraceDays: _toInt(m['new_grace_days'] ?? m['grace_days']),
        );

      case 'delete_debt':
        final name = (m['name'] ?? m['debt_name'])?.toString().trim();
        if (name == null || name.isEmpty) return null;
        return DeleteDebtAction(name: name);

      case 'create_goal':
      case 'add_goal':
        final name =
            (m['name'] ?? m['goal_name'] ?? m['title'])?.toString().trim();
        final target =
            _toDouble(m['target'] ?? m['target_amount'] ?? m['amount']);
        if (name == null || name.isEmpty || target == null || target <= 0) {
          return null;
        }
        return CreateGoalAction(Goal(
          id: _uuid.v4(),
          name: name,
          target: target,
          saved: _toDouble(m['saved'] ?? m['current_saved']) ?? 0.0,
        ));

      case 'add_to_goal':
        final name = (m['name'] ?? m['goal_name'])?.toString().trim();
        final amount = _toDouble(m['amount']);
        if (name == null || name.isEmpty || amount == null || amount <= 0) {
          return null;
        }
        return AddToGoalAction(goalName: name, amount: amount);

      case 'update_goal':
        final name = (m['name'] ?? m['goal_name'])?.toString().trim();
        if (name == null || name.isEmpty) return null;
        return UpdateGoalAction(
          name: name,
          newName: (m['new_name'])?.toString().trim(),
          newTarget: _toDouble(m['new_target'] ?? m['target']),
          newSaved: _toDouble(m['new_saved'] ?? m['saved']),
        );

      case 'delete_goal':
        final name = (m['name'] ?? m['goal_name'])?.toString().trim();
        if (name == null || name.isEmpty) return null;
        return DeleteGoalAction(name: name);

      case 'create_recurring':
        final name = (m['name'])?.toString().trim();
        final amount = _toDouble(m['amount']);
        if (name == null || name.isEmpty || amount == null || amount <= 0) {
          return null;
        }
        final freqStr = (m['frequency'] as String? ?? 'monthly').toLowerCase();
        final intervalDays = switch (freqStr) {
          'day' || 'daily' => 1,
          'week' || 'weekly' => 7,
          'bi-weekly' || 'biweekly' || 'fortnight' => 14,
          'year' || 'yearly' => 365,
          _ => 30,
        };
        final kind = (m['kind'] as String? ?? 'expense').toLowerCase();
        final type =
            kind == 'income' ? TransactionType.income : TransactionType.expense;
        final category = (m['category'] as String?)?.trim() ?? 'Other';
        return CreateRecurringAction(RecurringTransaction(
          id: _uuid.v4(),
          name: name,
          amount: amount,
          type: type,
          category: category,
          intervalDays: intervalDays,
          nextDue: DateTime.now(),
          walletId: '',
        ));

      case 'update_recurring':
        final name = (m['name'])?.toString().trim();
        if (name == null || name.isEmpty) return null;
        return UpdateRecurringAction(
          name: name,
          newAmount: _toDouble(m['new_amount'] ?? m['amount']),
          newFrequency:
              (m['new_frequency'] ?? m['frequency'])?.toString().trim(),
          newEnabled: m['new_enabled'] as bool?,
          delete: (m['delete'] as bool?) ?? false,
        );

      default:
        return null;
    }
  } catch (_) {
    return null;
  }
}

List<double> extractAmounts(String text) {
  final matches = RegExp(_amt).allMatches(text);
  final amounts = <double>[];
  for (final m in matches) {
    final parsed = CoachActionParser.parseAmount(m.group(1) ?? '');
    if (parsed > 0) amounts.add(parsed);
  }
  return amounts;
}

({List<CoachAction> actions, List<String> warnings})
    validateAgainstUserMessage({
  required List<CoachAction> actions,
  required String userMessage,
  List<String> recentUserMessages = const [],
  List<String> recentAssistantMessages = const [],
  List<String> knownEntityNames = const [],
  bool hasImageAttachment = false,
}) {
  final userLower = userMessage.toLowerCase();
  final isConfirmOrFollowUp = RegExp(
    r'^(?:confirm|approve|accept|yes|yep|yeah|yup|sure|ok|okay|please|proceed|do\s+it|save\s+it|save\s+them|add\s+it|log\s+it|pay\s+it|show\s+the\s+card|send\s+the\s+card|go\s+ahead)\b',
    caseSensitive: false,
  ).hasMatch(userLower.trim());

  final currentAmounts = extractAmounts(userMessage);
  final hasCurrentAmounts = currentAmounts.isNotEmpty;
  final contextText = [userMessage, ...recentUserMessages].join('\n');
  final contextAmounts = extractAmounts(contextText);
  final assistantText = recentAssistantMessages.join('\n');
  final assistantAmounts = extractAmounts(assistantText);
  final allUserAmounts = {
    ...currentAmounts,
    ...contextAmounts,
    if (isConfirmOrFollowUp || !hasCurrentAmounts) ...assistantAmounts,
  }.toList();
  final userAmounts = hasCurrentAmounts ? currentAmounts : contextAmounts;
  final contextLower = contextText.toLowerCase();
  final validated = <CoachAction>[];
  var ignoredAmountsCount = 0;
  final warnings = <String>[];

  for (final action in actions) {
    // 1. Amount safety check: if the action has a non-zero amount,
    // it must match an amount mentioned in the user message (within 0.05),
    // be present in conversation context, or be a derived product (installment * count).
    // If an image was attached (receipt/screenshot), amount is extracted by multimodal vision.
    bool matchesAmount = true;
    if (hasImageAttachment) {
      matchesAmount = true;
    } else if (action is CreateDebtAction) {
      final bal = action.debt.balance;
      final minPay = action.debt.minPayment;
      // 1. Check if balance matches any user amount directly
      final balMatches = userAmounts.any((amt) => (amt - bal).abs() < 0.05) ||
          allUserAmounts.any((amt) => (amt - bal).abs() < 0.05);
      // 2. Check if min payment matches any user amount directly
      final minPayMatches = (minPay > 0 &&
              userAmounts.any((amt) => (amt - minPay).abs() < 0.05)) ||
          (minPay > 0 &&
              allUserAmounts.any((amt) => (amt - minPay).abs() < 0.05));
      // 3. Check if balance matches product of an amount and a multiplier count (e.g. 5494.16 * 3)
      final multiplierMatches = allUserAmounts.any((amt) {
        if (action.debt.remainingPayments != null &&
            (amt * action.debt.remainingPayments! - bal).abs() < 0.05) {
          return true;
        }
        final countText = hasCurrentAmounts ? userMessage : contextText;
        final countMatches =
            RegExp(r'\b([1-9]|[1-9][0-9]|[1-3][0-5][0-9]|360)\b')
                .allMatches(countText);
        for (final cm in countMatches) {
          final count = int.tryParse(cm.group(1) ?? '');
          if (count != null && (amt * count - bal).abs() < 0.05) {
            return true;
          }
        }
        return false;
      });

      if (!balMatches && !minPayMatches && !multiplierMatches) {
        if (allUserAmounts.isNotEmpty || !isConfirmOrFollowUp) {
          matchesAmount = false;
        }
      }
    } else if (action is UpdateDebtAction) {
      if (action.newBalance != null && action.newBalance! > 0) {
        final balMatches = allUserAmounts
            .any((amt) => (amt - action.newBalance!).abs() < 0.05);
        if (!balMatches &&
            (allUserAmounts.isNotEmpty || !isConfirmOrFollowUp)) {
          matchesAmount = false;
        }
      }
      if (action.newMinPayment != null && action.newMinPayment! > 0) {
        final minPayMatches = allUserAmounts
            .any((amt) => (amt - action.newMinPayment!).abs() < 0.05);
        if (!minPayMatches &&
            (allUserAmounts.isNotEmpty || !isConfirmOrFollowUp)) {
          matchesAmount = false;
        }
      }
    } else {
      double? actionAmount;
      switch (action) {
        case LogTransactionAction a:
          actionAmount = a.amount;
        case AdjustWalletBalanceAction a:
          actionAmount = a.targetBalance;
        case UpdateDebtBalanceAction a:
          actionAmount = a.amount;
        case AddToGoalAction a:
          actionAmount = a.amount;
        case CreateWalletAction a:
          if (a.startingBalance > 0) actionAmount = a.startingBalance;
        case CreateGoalAction a:
          actionAmount = a.goal.target;
        case CreateRecurringAction a:
          actionAmount = a.recurring.amount;
        case UpdateRecurringAction a:
          if (a.newAmount != null && a.newAmount! > 0) {
            actionAmount = a.newAmount;
          }
        default:
          actionAmount = null;
      }

      if (actionAmount != null && actionAmount > 0) {
        if (allUserAmounts.isEmpty) {
          // User message is conversational / confirmation without numbers
          matchesAmount = isConfirmOrFollowUp || !hasCurrentAmounts;
        } else {
          matchesAmount =
              allUserAmounts.any((amt) => (amt - actionAmount!).abs() < 0.05);
        }
      }
    }

    if (!matchesAmount) {
      ignoredAmountsCount++;
      continue;
    }

    // 2. Name validation: the entity name (or brand) should be mentioned in user wording,
    // context, recent assistant turns, or match known entities/generic categories.
    String? entityName;
    switch (action) {
      case CreateWalletAction a:
        if (a.name.toLowerCase() == 'new wallet') {
          if (!userLower.contains('wallet') && !userLower.contains('account')) {
            continue;
          }
        } else {
          entityName = a.name;
        }
      case UpdateWalletAction a:
        entityName = a.name;
      case ArchiveWalletAction a:
        entityName = a.name;
      case AdjustWalletBalanceAction a:
        entityName = a.walletName;
      case CreateDebtAction a:
        entityName = a.debt.name;
      case UpdateDebtBalanceAction a:
        entityName = a.debtName;
      case UpdateDebtAction a:
        entityName = a.name;
      case DeleteDebtAction a:
        entityName = a.name;
      case AddToGoalAction a:
        entityName = a.goalName;
      case UpdateGoalAction a:
        entityName = a.name;
      case DeleteGoalAction a:
        entityName = a.name;
      default:
        entityName = null;
    }

    if (entityName != null && entityName.isNotEmpty) {
      final nameLower = entityName.toLowerCase();
      final tokens =
          nameLower.split(RegExp(r'\s+')).where((t) => t.length >= 3);
      final userTokens =
          userLower.split(RegExp(r'[^a-z0-9]+')).where((t) => t.length >= 3);
      final contextTokens =
          contextLower.split(RegExp(r'[^a-z0-9]+')).where((t) => t.length >= 3);
      final assistantLower = assistantText.toLowerCase();

      final isKnownEntity = knownEntityNames.any((k) {
        final kl = k.toLowerCase();
        return kl == nameLower ||
            kl.contains(nameLower) ||
            nameLower.contains(kl);
      });

      final matchesGenericTerm = (action is UpdateDebtAction ||
                  action is UpdateDebtBalanceAction ||
                  action is DeleteDebtAction) &&
              (userLower.contains('debt') ||
                  userLower.contains('loan') ||
                  userLower.contains('card') ||
                  userLower.contains('spay') ||
                  userLower.contains('sloan') ||
                  userLower.contains('bill') ||
                  userLower.contains('owe')) ||
          (action is UpdateWalletAction ||
                  action is ArchiveWalletAction ||
                  action is AdjustWalletBalanceAction) &&
              (userLower.contains('wallet') ||
                  userLower.contains('account') ||
                  userLower.contains('balance') ||
                  userLower.contains('bank')) ||
          (action is UpdateGoalAction ||
                  action is AddToGoalAction ||
                  action is DeleteGoalAction) &&
              (userLower.contains('goal') ||
                  userLower.contains('target') ||
                  userLower.contains('save') ||
                  userLower.contains('saving') ||
                  userLower.contains('fund'));

      final hasNameMatch = isConfirmOrFollowUp ||
          isKnownEntity ||
          matchesGenericTerm ||
          userLower.contains(nameLower) ||
          tokens.any((t) => userLower.contains(t)) ||
          userTokens.any((ut) => nameLower.contains(ut)) ||
          contextLower.contains(nameLower) ||
          tokens.any((t) => contextLower.contains(t)) ||
          contextTokens.any((ct) => nameLower.contains(ct)) ||
          assistantLower.contains(nameLower) ||
          tokens.any((t) => assistantLower.contains(t));

      if (!hasNameMatch && !hasImageAttachment) {
        continue;
      }
    }

    // If LogTransactionAction had a walletName that the user did not say,
    // clear the walletName so it defaults safely rather than targeting the wrong wallet.
    // (Unless image attachment is present, where vision detected the wallet from the receipt/app).
    CoachAction processedAction = action;
    if (!hasImageAttachment &&
        action is LogTransactionAction &&
        action.walletName != null) {
      final wLower = action.walletName!.toLowerCase();
      final tokens = wLower.split(RegExp(r'\s+')).where((t) => t.length >= 3);
      final hasMatch = userLower.contains(wLower) ||
          tokens.any((t) => userLower.contains(t));
      if (!hasMatch) {
        processedAction = LogTransactionAction(
          amount: action.amount,
          isIncome: action.isIncome,
          category: action.category,
          note: action.note,
          walletName: null,
        );
      }
    }

    validated.add(processedAction);
  }

  if (ignoredAmountsCount > 0) {
    warnings.add(
      ignoredAmountsCount == 1
          ? 'Ignored 1 action: AI suggested a different amount.'
          : 'Ignored $ignoredAmountsCount actions: AI suggested a different amount.',
    );
  }

  return (actions: validated, warnings: warnings);
}
