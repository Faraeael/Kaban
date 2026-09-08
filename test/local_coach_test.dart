import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/services/ai/coach_service.dart';
import 'package:finance_tracker/services/ai/local_coach.dart';

FinanceSnapshot _snap({
  Map<String, double>? wallets,
  Map<String, double>? byCategory,
  double income = 0,
  double expense = 0,
  double totalDebt = 0,
  List<DebtSnapshot>? debts,
  bool remoteConfigured = false,
}) {
  return FinanceSnapshot(
    walletBalances: wallets ?? const {},
    totalDebt: totalDebt,
    monthIncome: income,
    monthExpense: expense,
    monthExpenseByCategory: byCategory ?? const {},
    debts: debts ?? const [],
    suggestions: const [],
    remoteConfigured: remoteConfigured,
  );
}

List<DebtSnapshot> _debts(String name, double balance, double apr) => [
      DebtSnapshot(
          id: '1',
          name: name,
          balance: balance,
          apr: apr,
          minPayment: 500,
          strategy: 'avalanche')
    ];

void main() {
  final coach = LocalCoach();

  group('LocalCoach', () {
    test('pay-first picks highest APR', () async {
      final snap =
          _snap(debts: _debts('Card A', 5000, 18) + _debts('Card B', 8000, 5));
      // Note: _debts returns [first], so this is one debt named 'Card A'.
      final r = (await coach.ask('what should I pay first', snap)).text;
      expect(r.toLowerCase(), contains('card a'));
    });

    test('summary includes wallet count and net', () async {
      final snap = _snap(
          wallets: {'BDO': 5000, 'Maya': 3000},
          totalDebt: 2000,
          income: 10000,
          expense: 4000);
      final r = (await coach.ask('how am I doing this month', snap)).text;
      expect(r, contains('2 wallet'));
      expect(r.toLowerCase(), contains('cash'));
    });

    test('savings rate returns percentage', () async {
      final snap = _snap(income: 10000, expense: 7000);
      final r = (await coach.ask('what is my savings rate', snap)).text;
      expect(r, contains('30%'));
    });

    test('wallet lookup returns balance for known wallet', () async {
      final snap = _snap(wallets: {'Maya': 1500});
      final r = (await coach.ask('how is my Maya', snap)).text;
      expect(r, contains('₱1,500'));
    });

    test('wallet lookup falls through when wallet not found', () async {
      final snap = _snap(wallets: {'Maya': 1500});
      final r = (await coach.ask('how is my BDO', snap)).text;
      // Should not contain "balance is" because BDO doesn't exist
      expect(r.contains('balance is'), isFalse);
    });

    test('biggest wallet returns the largest', () async {
      final snap = _snap(wallets: {'Maya': 1500, 'BDO': 8000, 'GCash': 500});
      final r = (await coach.ask('which wallet has the most', snap)).text;
      expect(r, contains('BDO'));
    });

    test('negative wallets flagged', () async {
      final snap = _snap(wallets: {'Maya': -200, 'BDO': 5000});
      final r = (await coach.ask('is any wallet in the red', snap)).text;
      expect(r, contains('Maya'));
    });

    test('total cash across all wallets', () async {
      final snap = _snap(wallets: {'A': 1000, 'B': 2000, 'C': 500});
      final r = (await coach.ask('how much cash total', snap)).text;
      expect(r, contains('₱3,500'));
    });

    test('afford returns verdict with explicit amount', () async {
      final snap = _snap(income: 20000, expense: 10000);
      final r = (await coach.ask('can I afford a 5000 purchase', snap)).text;
      expect(r, contains('₱5,000'));
    });

    test('fallback gives specific suggestions, not generic', () async {
      final snap = _snap(wallets: {'Maya': 1000});
      final r1 = (await coach.ask('xyzzy plugh foobar', snap)).text;
      final r2 = (await coach.ask('completely unrelated gibberish', snap)).text;
      // The fallback lists the same data-driven suggestions for both
      expect(r1, contains('"how is my Maya?"'));
      expect(r2, contains('"how is my Maya?"'));
    });

    test('suggested prompts include savings rate when applicable', () {
      final snap = _snap(wallets: {'Maya': 1000}, income: 10000, expense: 5000);
      final p = coach.suggestedPrompts(snap);
      expect(p.any((q) => q.toLowerCase().contains('savings rate')), isTrue);
    });
  });
}
