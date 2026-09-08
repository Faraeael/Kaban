import 'dart:typed_data';

import 'coach_service.dart';

/// On-device coach. Rule-based but with intent scoring so the same question
/// always picks the best handler, and so a question that doesn't match any
/// pattern falls through to a *specific* suggestion based on the user's
/// actual data instead of a generic feature list.
class LocalCoach implements CoachService {
  static String _peso(double v) {
    final n = v.abs().toInt();
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    final sign = v < 0 ? '-' : '';
    return '$sign₱${buf.toString()}';
  }

  @override
  Future<CoachReply> ask(String userMessage, FinanceSnapshot snapshot,
      {Uint8List? imageBytes, String? imageMimeType}) async {
    if (imageBytes != null) {
      return const CoachReply(
        text:
            '📸 Screenshot and receipt scanning requires an AI model with vision capabilities (Gemini or OpenAI). Please configure an AI provider in Settings → AI Coach.',
        actions: [],
        warnings: [],
      );
    }
    final lower = userMessage.toLowerCase();
    final scored = <_Intent>[];
    void match(_Intent intent) {
      if (intent.matches(lower)) scored.add(intent);
    }

    match(_Intent('overspend', 2, () => _overspend(snapshot),
        required: ['over', 'spend']));
    match(_Intent('topCategory', 1, () => _topCategory(snapshot),
        keywords: ['top categor', 'biggest categor']));
    match(_Intent('payFirst', 3, () => _payFirst(snapshot),
        keywords: ['pay first', 'which debt', 'priorit', 'order to pay']));
    match(_Intent('debtFree', 2, () => _debtFree(snapshot),
        keywords: ['debt-free', 'debt free', 'payoff', 'when will']));
    match(_Intent('afford', 2, () => _afford(userMessage, snapshot),
        keywords: ['afford', 'can i buy', 'can i spend', 'should i buy']));
    match(_Intent('summary', 2, () => _summary(snapshot),
        keywords: ['how am i', 'summary', 'overview', 'snapshot']));
    match(_Intent('savingsRate', 2, () => _savingsRate(snapshot), keywords: [
      'saving rate',
      'savings rate',
      'save rate',
      'how much am i saving'
    ]));
    match(_Intent('dailySpend', 2, () => _dailySpend(snapshot),
        keywords: ['per day', 'daily', 'each day', 'average spend']));
    match(_Intent('walletLookup', 3, () => _walletLookup(lower, snapshot),
        keywords: [
          'how is my',
          'how much in',
          'how much do i have in',
          'balance'
        ]));
    match(_Intent('biggestWallet', 1, () => _biggestWallet(snapshot),
        keywords: [
          'biggest wallet',
          'most money',
          'where is my money',
          'most cash',
          'has the most'
        ]));
    match(_Intent('negativeWallet', 1, () => _negativeWallets(snapshot),
        keywords: ['in the red', 'negative', 'overdraft', 'below zero']));
    match(_Intent('walletCount', 1, () => _walletCount(snapshot),
        keywords: ['how many wallet', 'wallet count']));
    match(_Intent('totalCash', 2, () => _totalCash(snapshot), keywords: [
      'total cash',
      'how much cash',
      'total money',
      'all wallets'
    ]));
    match(_Intent('help', 1, () => _help(snapshot),
        keywords: ['help', 'what can you', 'capabilities']));
    match(_Intent('foodDrill', 1, () => _categoryDrill('Food', snapshot),
        keywords: ['food', 'groceries']));
    match(_Intent(
        'transportDrill', 1, () => _categoryDrill('Transport', snapshot),
        keywords: ['transport', 'commute', 'grab', 'gas']));

    // Special: wallet-lookup scans wallet names directly. If it produces a
    // real match, return it. If empty, fall through so other intents or the
    // fallback can answer.
    for (final i in scored.where((i) => i.name == 'walletLookup')) {
      final result = i.run();
      if (result.isNotEmpty) {
        return CoachReply(text: result, actions: const [], warnings: const []);
      }
    }
    final others = scored.where((i) => i.name != 'walletLookup').toList();
    if (others.isNotEmpty) {
      others.sort((a, b) => b.score.compareTo(a.score));
      return CoachReply(
          text: others.first.run(), actions: const [], warnings: const []);
    }
    return CoachReply(
        text: _fallback(snapshot), actions: const [], warnings: const []);
  }

  @override
  List<String> suggestedPrompts(FinanceSnapshot snapshot) {
    final prompts = <String>[];
    prompts.add('Paid ₱15 jeep fare');
    if (snapshot.debts.isNotEmpty) {
      prompts.add('What should I pay first?');
    }
    if (snapshot.monthExpenseByCategory.isNotEmpty) {
      prompts.add('Where am I overspending?');
    }
    if (snapshot.walletBalances.isNotEmpty) {
      final first = snapshot.walletBalances.keys.first;
      prompts.add('How is my $first?');
    }
    if (snapshot.monthIncome > 0 && snapshot.monthExpense > 0) {
      prompts.add('What\'s my savings rate this month?');
    }
    if (snapshot.walletBalances.length > 1) {
      prompts.add('Which wallet has the most?');
    }
    return prompts.take(5).toList();
  }

  // ---------------- handlers ----------------

  String _overspend(FinanceSnapshot snapshot) {
    if (snapshot.monthExpenseByCategory.isEmpty) {
      return 'No spending recorded this month yet — your top categories will show up here as you log transactions.';
    }
    final top = snapshot.monthExpenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 =
        top.take(3).map((e) => '**${e.key}**: ${_peso(e.value)}').join(', ');
    return 'Your top 3 categories this month: $top3. Small cuts in the biggest one usually free up the most cash.';
  }

  String _topCategory(FinanceSnapshot snapshot) {
    if (snapshot.monthExpenseByCategory.isEmpty) {
      return 'No categories to rank yet.';
    }
    final top = snapshot.monthExpenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '**${top.first.key}** is your biggest category at ${_peso(top.first.value)} this month.';
  }

  String _payFirst(FinanceSnapshot snapshot) {
    if (snapshot.debts.isEmpty) {
      return 'You don\'t have any debts tracked yet.';
    }
    final highest = snapshot.debts.reduce((a, b) => a.apr > b.apr ? a : b);
    return 'Pay **${highest.name}** first (${highest.apr.toStringAsFixed(1)}% APR, balance ${_peso(highest.balance)}). Under the avalanche method, attacking highest-APR debt saves the most on interest.';
  }

  String _debtFree(FinanceSnapshot snapshot) {
    if (snapshot.debts.isEmpty) {
      return 'You\'re debt-free on what you\'ve tracked.';
    }
    final highest = snapshot.debts.reduce((a, b) => a.apr > b.apr ? a : b);
    return '**${highest.name}** (${highest.apr.toStringAsFixed(1)}% APR, ${_peso(highest.balance)}) is your slowest to clear at current payments. Adding ₱500–₱1,000/mo of extra payment shortens the timeline noticeably.';
  }

  String _afford(String userMessage, FinanceSnapshot snapshot) {
    final surplus = snapshot.monthIncome - snapshot.monthExpense;
    final amountMatch = RegExp(r'(\d[\d,]*\.?\d*k?m?)').firstMatch(userMessage);
    final asking =
        amountMatch != null ? _parseAmount(amountMatch.group(1) ?? '') : 0.0;
    if (surplus <= 0) {
      return 'You\'re at a deficit this month (${_peso(surplus)}). Hold off on non-essential purchases until income catches up.';
    }
    if (asking > 0) {
      if (asking <= surplus / 2) {
        return '${_peso(asking)} is roughly ${((asking / surplus) * 100).toStringAsFixed(0)}% of your ${_peso(surplus)} month-to-date surplus. Likely fine if you have no high-interest debt.';
      }
      if (asking <= surplus) {
        return '${_peso(asking)} fits in your surplus but leaves little room. If credit card debt is above 15% APR, paying that down first usually beats spending.';
      }
      return '${_peso(asking)} is bigger than your current surplus (${_peso(surplus)}). Wait or trim expenses first.';
    }
    return 'Your month-to-date surplus is about ${_peso(surplus)}. For purchases under half that and no high-interest debt, it\'s usually fine.';
  }

  String _summary(FinanceSnapshot snapshot) {
    final walletCount = snapshot.walletBalances.length;
    final cash =
        snapshot.walletBalances.values.fold<double>(0, (s, v) => s + v);
    final net = cash - snapshot.totalDebt;
    final surplus = snapshot.monthIncome - snapshot.monthExpense;
    final lines = <String>[
      '**$walletCount wallet${walletCount == 1 ? '' : 's'}** · cash ${_peso(cash)} · debt ${_peso(snapshot.totalDebt)} · net ${_peso(net)}',
      'This month: +${_peso(snapshot.monthIncome)} income, −${_peso(snapshot.monthExpense)} expense${snapshot.monthExpense == 0 ? '' : ' · ${surplus >= 0 ? 'surplus' : 'deficit'} ${_peso(surplus.abs())}'}',
    ];
    if (snapshot.suggestions.isNotEmpty) {
      lines.add(snapshot.suggestions.join('\n'));
    }
    return lines.join('\n\n');
  }

  String _savingsRate(FinanceSnapshot snapshot) {
    if (snapshot.monthIncome <= 0) {
      return 'No income recorded this month yet.';
    }
    final rate = ((snapshot.monthIncome - snapshot.monthExpense) /
            snapshot.monthIncome) *
        100;
    final verdict = rate >= 20
        ? 'Healthy — above the 20% rule of thumb.'
        : rate >= 0
            ? 'Thin — most of your income is going out the door.'
            : 'Negative — you\'re spending more than you earn this month.';
    return 'Savings rate: **${rate.toStringAsFixed(0)}%** (${_peso(snapshot.monthIncome - snapshot.monthExpense)} of ${_peso(snapshot.monthIncome)}). $verdict';
  }

  String _dailySpend(FinanceSnapshot snapshot) {
    final day = DateTime.now();
    final daysElapsed = day.day;
    if (snapshot.monthExpense <= 0 || daysElapsed == 0) {
      return 'No spending recorded this month yet.';
    }
    final perDay = snapshot.monthExpense / daysElapsed;
    final remaining = DateTime(day.year, day.month + 1, 0).day - daysElapsed;
    return 'You\'re averaging **${_peso(perDay)}/day** so far this month. With $remaining day${remaining == 1 ? '' : 's'} left, budget around ${_peso(perDay * remaining)} more to stay flat.';
  }

  String _walletLookup(String lower, FinanceSnapshot snapshot) {
    for (final entry in snapshot.walletBalances.entries) {
      final name = entry.key.toLowerCase();
      if (lower.contains(name)) {
        return '**${entry.key}** balance is ${_peso(entry.value)}.';
      }
    }
    return '';
  }

  String _biggestWallet(FinanceSnapshot snapshot) {
    if (snapshot.walletBalances.isEmpty) return 'No wallets to compare.';
    final sorted = snapshot.walletBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    if (sorted.length == 1) {
      return '**${top.key}** is your only wallet, holding ${_peso(top.value)}.';
    }
    return '**${top.key}** has the most cash at ${_peso(top.value)}. Your next is **${sorted[1].key}** at ${_peso(sorted[1].value)}.';
  }

  String _negativeWallets(FinanceSnapshot snapshot) {
    final neg =
        snapshot.walletBalances.entries.where((e) => e.value < 0).toList();
    if (neg.isEmpty) return 'No wallet is in the red. Net worth is positive.';
    return 'These wallets are negative: ${neg.map((e) => '**${e.key}** (${_peso(e.value)})').join(', ')}. Move funds in or skip spending there.';
  }

  String _walletCount(FinanceSnapshot snapshot) {
    final n = snapshot.walletBalances.length;
    return n == 0
        ? 'You have no wallets yet.'
        : 'You have **$n wallet${n == 1 ? '' : 's'}**: ${snapshot.walletBalances.keys.join(', ')}.';
  }

  String _totalCash(FinanceSnapshot snapshot) {
    if (snapshot.walletBalances.isEmpty) return 'No cash tracked yet.';
    final total =
        snapshot.walletBalances.values.fold<double>(0, (s, v) => s + v);
    return 'Across ${snapshot.walletBalances.length} wallet${snapshot.walletBalances.length == 1 ? '' : 's'}: **${_peso(total)}**.';
  }

  String _help(FinanceSnapshot snapshot) {
    final lines = <String>[
      'I can answer things like:',
      '• "what should I pay first" — debt priority',
      '• "where am I overspending" — top categories',
      '• "how am I doing this month" — net + monthly snapshot',
      '• "what\'s my savings rate" — income vs expense',
      '• "how is my Maya?" — wallet balance by name',
    ];
    if (snapshot.remoteConfigured) {
      lines.add('');
      lines.add(
          'A remote AI provider is configured but switched off — turn on "Allow remote AI" in Settings for richer, conversational answers.');
    }
    return lines.join('\n');
  }

  String _categoryDrill(String category, FinanceSnapshot snapshot) {
    final spent = snapshot.monthExpenseByCategory[category];
    if (spent == null) {
      return 'No spending recorded in **$category** this month yet.';
    }
    return '**$category** this month: ${_peso(spent)}. Add more transactions to see daily averages.';
  }

  String _fallback(FinanceSnapshot snapshot) {
    final suggestions = <String>[];
    if (snapshot.debts.isNotEmpty) {
      suggestions.add('"what should I pay first?"');
    }
    if (snapshot.monthExpenseByCategory.isNotEmpty) {
      suggestions.add('"where am I overspending?"');
    }
    if (snapshot.monthIncome > 0) {
      suggestions.add('"what\'s my savings rate?"');
    }
    if (snapshot.walletBalances.isNotEmpty) {
      final first = snapshot.walletBalances.keys.first;
      suggestions.add('"how is my $first?"');
    }
    if (snapshot.walletBalances.length > 1) {
      suggestions.add('"which wallet has the most?"');
    }
    if (snapshot.debts.isEmpty &&
        snapshot.monthExpense == 0 &&
        snapshot.walletBalances.isEmpty) {
      return 'I\'m not sure how to answer that yet — add a wallet and log a transaction, then I can give you actual numbers.';
    }
    final askList = suggestions.take(3).join(' · ');
    var reply = 'Try one of these: $askList.';
    if (snapshot.remoteConfigured) {
      reply += ' Or turn on "Allow remote AI" in Settings for a fuller answer.';
    }
    return reply;
  }

  static double _parseAmount(String raw) {
    if (raw.isEmpty) return 0;
    var cleaned = raw.replaceAll(',', '').toLowerCase();
    var mult = 1.0;
    if (cleaned.endsWith('k')) {
      mult = 1000;
      cleaned = cleaned.substring(0, cleaned.length - 1);
    } else if (cleaned.endsWith('m')) {
      mult = 1000000;
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return mult * (double.tryParse(cleaned) ?? 0);
  }
}

class _Intent {
  final String name;
  final int score;
  final List<String> keywords;
  final List<String> required;
  final String Function() run;

  _Intent(this.name, this.score, this.run,
      {this.keywords = const [], this.required = const []});

  bool matches(String lower) {
    if (required.isNotEmpty && !required.every(lower.contains)) return false;
    if (keywords.isEmpty) return true;
    return keywords.any(lower.contains);
  }
}
