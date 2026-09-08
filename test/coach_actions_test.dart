import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/models/chat_message.dart';
import 'package:finance_tracker/services/coach_actions.dart';

void main() {
  final parser = CoachActionParser();

  group('CoachActionParser', () {
    test('detects expense from user message', () {
      final actions = parser.parse(
        assistantReply: 'Noted, that adds up fast.',
        userMessage: 'I spent 200 on food',
      );
      final expense = actions.whereType<LogTransactionAction>().single;
      expect(expense.isIncome, isFalse);
      expect(expense.amount, 200);
      expect(expense.category, 'Food');
    });

    test('detects income with peso sign and comma', () {
      final actions = parser.parse(
        assistantReply: 'Nice, logged it.',
        userMessage: 'I received ₱1,500 today',
      );
      final income = actions.whereType<LogTransactionAction>().single;
      expect(income.isIncome, isTrue);
      expect(income.amount, 1500);
    });

    test('detects debt payment toward named debt', () {
      final actions = parser.parse(
        assistantReply: 'Good progress!',
        userMessage: 'I paid 500 to my BDO card',
      );
      final payment = actions.whereType<UpdateDebtBalanceAction>().single;
      expect(payment.amount, 500);
      expect(payment.debtName.toLowerCase(), contains('bdo'));
    });

    test('detects savings toward goal', () {
      final actions = parser.parse(
        assistantReply: 'On track.',
        userMessage: 'I put 1000 toward travel fund',
      );
      final add = actions.whereType<AddToGoalAction>().single;
      expect(add.amount, 1000);
      expect(add.goalName.toLowerCase(), contains('travel'));
    });

    test('handles k-suffix amounts', () {
      final actions = parser.parse(
        assistantReply: '',
        userMessage: 'I spent 2k on shopping',
      );
      final expense = actions.whereType<LogTransactionAction>().single;
      expect(expense.amount, 2000);
    });

    test('preserves decimal wallet starting balance', () {
      final actions = parser.parse(
        assistantReply: '',
        userMessage: 'Create a BDO wallet with 1983.67',
      );
      final wallet = actions.whereType<CreateWalletAction>().single;
      expect(wallet.name, 'BDO');
      expect(wallet.startingBalance, 1983.67);
    });

    test('preserves decimal wallet balance with amount wording', () {
      final actions = parser.parse(
        assistantReply: '',
        userMessage: 'Create a BDO wallet with 1983.67 Amount',
      );
      final wallet = actions.whereType<CreateWalletAction>().single;
      expect(wallet.startingBalance, 1983.67);
    });

    test('wallet action ignores conflicting assistant wallet name', () {
      final actions = parser.parse(
        assistantReply: 'I will create a GCash wallet with ₱2,000.',
        userMessage: 'Create a BDO wallet with 1983.67',
      );
      final wallet = actions.whereType<CreateWalletAction>().single;
      expect(wallet.name, 'BDO');
      expect(wallet.startingBalance, 1983.67);
    });

    test('no actions from plain advice text', () {
      final actions = parser.parse(
        assistantReply:
            'Your top category this month is Food. Consider the avalanche '
            'method for your debts — highest APR first saves the most interest.',
      );
      expect(actions, isEmpty);
    });

    test('detects recurring intent without double-logging as expense', () {
      final actions = parser.parse(
        assistantReply: 'Got it, I\'ll set that up for you.',
        userMessage: 'I spend 100 every day on commute',
      );
      final recurring = actions.whereType<CreateRecurringAction>().single;
      expect(recurring.recurring.amount, 100);
      expect(recurring.recurring.intervalDays, 1);
      expect(recurring.recurring.category, 'Transport');
      // Must not also emit a one-time expense for the same sentence.
      expect(actions.whereType<LogTransactionAction>(), isEmpty);
    });

    test('detects monthly recurring', () {
      final actions = parser.parse(
        assistantReply: '',
        userMessage: 'I pay 1500 monthly for gym',
      );
      final recurring = actions.whereType<CreateRecurringAction>().single;
      expect(recurring.recurring.amount, 1500);
      expect(recurring.recurring.intervalDays, 30);
    });

    test('detects wallet creation with brand match', () {
      final actions = parser.parse(
        assistantReply: 'Got it, tracking that wallet for you.',
        userMessage: 'I got a new BDO account with 5000',
      );
      final wallet = actions.whereType<CreateWalletAction>().single;
      expect(wallet.name, 'BDO');
      expect(wallet.startingBalance, 5000);
    });

    test('detects generic wallet creation without balance', () {
      final actions = parser.parse(
        assistantReply: 'Okay.',
        userMessage: 'please add a wallet',
      );
      final wallet = actions.whereType<CreateWalletAction>().single;
      expect(wallet.name, 'New wallet');
      expect(wallet.startingBalance, 0);
    });

    test('wallet creation does not double up as expense', () {
      final actions = parser.parse(
        assistantReply: '',
        userMessage: 'I spent 200 on food and also add a GCash wallet',
      );
      // "add a GCash wallet" is a wallet intent; "spent 200 on food" is an
      // expense. Both should surface, but the wallet action must not also
      // duplicate as an expense.
      expect(actions.whereType<CreateWalletAction>(), isNotEmpty);
      expect(actions.whereType<LogTransactionAction>().length, 1);
    });

    test('detects debt creation from structured user message like SPAY', () {
      const userMsg = '''now add SPAY

Total Balance: 50,692.25
Min. payment: 6213.65
Due date: 15th
10mths left''';
      final actions = parser.parse(
        assistantReply: '',
        userMessage: userMsg,
      );
      final debtAct = actions.whereType<CreateDebtAction>().single;
      expect(debtAct.debt.name, 'SPAY');
      expect(debtAct.debt.balance, 50692.25);
      expect(debtAct.debt.minPayment, 6213.65);
      expect(debtAct.debt.dueDay, 15);
      expect(debtAct.debt.remainingPayments, 10);
    });

    test('detects debt creation from assistant plain text reply', () {
      const assistantText =
          'Adding SPAY: ₱6,213.65/month for 10 months (total ₱50,692.25), due every 15th, 0% APR assumed. Approving both debts below — confirm to add them.';
      final actions = parser.parse(
        assistantReply: assistantText,
      );
      final debtAct = actions.whereType<CreateDebtAction>().single;
      expect(debtAct.debt.name, 'SPAY');
      expect(debtAct.debt.balance, 50692.25);
      expect(debtAct.debt.minPayment, 6213.65);
      expect(debtAct.debt.dueDay, 15);
      expect(debtAct.debt.remainingPayments, 10);
    });

    test(
        'parseJsonAction handles strings, ordinals, commas, and unit suffixes gracefully',
        () {
      final json = {
        'type': 'create_debt',
        'name': 'SPAY',
        'balance': '50,692.25',
        'min_payment': '₱6,213.65',
        'due_day': '15th',
        'remaining_payments': '10mths',
        'schedule': 'fixed',
      };
      final action = parseJsonAction(json);
      expect(action, isA<CreateDebtAction>());
      final debt = (action as CreateDebtAction).debt;
      expect(debt.name, 'SPAY');
      expect(debt.balance, 50692.25);
      expect(debt.minPayment, 6213.65);
      expect(debt.dueDay, 15);
      expect(debt.remainingPayments, 10);
    });

    test('detects Philippine jeepney fare with wallet under Cash', () {
      final actions = parser.parse(
        assistantReply: '',
        userMessage: 'Paid PHP13 to Jeep put it under Cash',
      );
      final expense = actions.whereType<LogTransactionAction>().single;
      expect(expense.isIncome, isFalse);
      expect(expense.amount, 13);
      expect(expense.category, 'Transport');
      expect(expense.walletName, 'Cash');
      expect(actions.whereType<UpdateDebtBalanceAction>(), isEmpty);
    });

    test('detects repeated commute fare with amount following category', () {
      final actions = parser.parse(
        assistantReply: '',
        userMessage: 'after that I paid again to a jeep 15PHP this time',
      );
      final expense = actions.whereType<LogTransactionAction>().single;
      expect(expense.isIncome, isFalse);
      expect(expense.amount, 15);
      expect(expense.category, 'Transport');
      expect(actions.whereType<UpdateDebtBalanceAction>(), isEmpty);
    });

    test('detects Paid PHP15 to Jeep as Transport expense, not debt payment',
        () {
      final actions = parser.parse(
        assistantReply: '',
        userMessage: 'Paid PHP15 to Jeep',
      );
      final expense = actions.whereType<LogTransactionAction>().single;
      expect(expense.isIncome, isFalse);
      expect(expense.amount, 15);
      expect(expense.category, 'Transport');
      expect(actions.whereType<UpdateDebtBalanceAction>(), isEmpty);
    });

    test('detects tricycle and food as expenses, not debt payments', () {
      final trikeActions = parser.parse(
        assistantReply: '',
        userMessage: 'paid 20 to tricycle',
      );
      final trikeExpense =
          trikeActions.whereType<LogTransactionAction>().single;
      expect(trikeExpense.amount, 20);
      expect(trikeExpense.category, 'Transport');
      expect(trikeActions.whereType<UpdateDebtBalanceAction>(), isEmpty);

      final foodActions = parser.parse(
        assistantReply: '',
        userMessage: 'paid 250 for Jollibee',
      );
      final foodExpense = foodActions.whereType<LogTransactionAction>().single;
      expect(foodExpense.amount, 250);
      expect(foodExpense.category, 'Food');
      expect(foodActions.whereType<UpdateDebtBalanceAction>(), isEmpty);
    });

    test('detects debt payment with paying wallet from user message', () {
      final actions = parser.parse(
        assistantReply: '',
        userMessage: 'I paid 500 to my BDO card from Maya',
      );
      final payment = actions.whereType<UpdateDebtBalanceAction>().single;
      expect(payment.amount, 500);
      expect(payment.debtName.toLowerCase(), contains('bdo'));
      expect(payment.walletName, 'Maya');
    });

    test('parseJsonAction parses pay_debt with wallet_name', () {
      final json = {
        'type': 'pay_debt',
        'name': 'MariLoan',
        'amount': 1500,
        'wallet_name': 'GCash',
      };
      final action = parseJsonAction(json);
      expect(action, isA<UpdateDebtBalanceAction>());
      final payment = action as UpdateDebtBalanceAction;
      expect(payment.debtName, 'MariLoan');
      expect(payment.amount, 1500);
      expect(payment.walletName, 'GCash');
    });

    test('parseJsonAction parses update_debt_balance with wallet', () {
      final json = {
        'type': 'update_debt_balance',
        'debt_name': 'Credit Card',
        'amount': 2500.50,
        'wallet': 'Cash',
      };
      final action = parseJsonAction(json);
      expect(action, isA<UpdateDebtBalanceAction>());
      final payment = action as UpdateDebtBalanceAction;
      expect(payment.debtName, 'Credit Card');
      expect(payment.amount, 2500.50);
      expect(payment.walletName, 'Cash');
    });

    test(
        'validateAgainstUserMessage preserves action on conversational confirmation',
        () {
      const action = LogTransactionAction(
        amount: 250,
        isIncome: false,
        category: 'Food',
        note: 'Lunch',
      );
      final validated = validateAgainstUserMessage(
        actions: [action],
        userMessage: 'yes please proceed',
        recentUserMessages: ['Should I log 250 for lunch?'],
        recentAssistantMessages: ['Would you like to log ₱250 for Lunch?'],
      );
      expect(validated.actions.length, 1);
      expect(validated.warnings, isEmpty);
    });

    test(
        'validateAgainstUserMessage matches generic debt term and known entity',
        () {
      const action = UpdateDebtBalanceAction(
        debtName: 'MariLoan',
        amount: 500,
        walletName: 'GCash',
      );
      final validated = validateAgainstUserMessage(
        actions: [action],
        userMessage: 'pay 500 to my debt from GCash',
        knownEntityNames: ['MariLoan'],
      );
      expect(validated.actions.length, 1);
      expect(validated.warnings, isEmpty);
    });

    test('parseJsonAction generates unique UUIDs for batch loan payload', () {
      final json1 = {
        'type': 'create_debt',
        'name': 'Loan ₱30k (Due 29th)',
        'balance': 24954.86,
        'min_payment': 3564.98,
        'due_day': 29,
        'remaining_payments': 7,
      };
      final json2 = {
        'type': 'create_debt',
        'name': 'Loan ₱5k (Due 20th)',
        'balance': 5864.48,
        'min_payment': 733.06,
        'due_day': 20,
        'remaining_payments': 8,
      };
      final json3 = {
        'type': 'create_debt',
        'name': 'Loan ₱5k (Due 1st)',
        'balance': 6535.76,
        'min_payment': 594.16,
        'due_day': 1,
        'remaining_payments': 11,
      };
      final json4 = {
        'type': 'create_debt',
        'name': 'Loan ₱15.7k (Due 1st)',
        'balance': 22388.04,
        'min_payment': 1865.67,
        'due_day': 1,
        'remaining_payments': 12,
      };

      final a1 = parseJsonAction(json1) as CreateDebtAction;
      final a2 = parseJsonAction(json2) as CreateDebtAction;
      final a3 = parseJsonAction(json3) as CreateDebtAction;
      final a4 = parseJsonAction(json4) as CreateDebtAction;

      final ids = {a1.debt.id, a2.debt.id, a3.debt.id, a4.debt.id};
      expect(ids.length, 4,
          reason: 'Every loan parsed in batch must have a distinct unique ID');
      for (final id in ids) {
        expect(id.contains('action_'), isFalse,
            reason: 'ID should be a standard UUID, not timestamp-based');
      }
    });

    test('ChatMessage serializes and deserializes imagePath correctly', () {
      final msg = ChatMessage(
        id: 'test-1',
        role: ChatRole.user,
        content: 'Check my loans',
        timestamp: DateTime(2026, 3, 29, 14, 30),
        imagePath:
            '/data/user/0/ph.kaban.app/app_flutter/chat_images/receipt.jpg',
      );
      final map = msg.toMap();
      expect(map['image_path'],
          '/data/user/0/ph.kaban.app/app_flutter/chat_images/receipt.jpg');

      final restored = ChatMessage.fromMap(map);
      expect(restored.id, msg.id);
      expect(restored.imagePath, msg.imagePath);
      expect(restored.content, msg.content);
    });
  });
}
