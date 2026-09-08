import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/models/debt.dart';
import 'package:finance_tracker/services/coach_actions.dart';

void main() {
  group('Action Validator & Safety Policy', () {
    test(
        'validator drops update_debt_balance when Gemini amount differs from user',
        () {
      const userMessage = 'I paid 500 to my BDO card';
      final actions = [
        const UpdateDebtBalanceAction(debtName: 'BDO', amount: 1000),
      ];

      final result = validateAgainstUserMessage(
        actions: actions,
        userMessage: userMessage,
      );

      expect(result.actions, isEmpty);
      expect(result.warnings.length, 1);
      expect(result.warnings.first,
          'Ignored 1 action: AI suggested a different amount.');
    });

    test(
        'validator keeps action when amount matches user wording within tolerance',
        () {
      const userMessage = 'I paid 500 to my BDO card';
      final actions = [
        const UpdateDebtBalanceAction(debtName: 'BDO', amount: 500),
      ];

      final result = validateAgainstUserMessage(
        actions: actions,
        userMessage: userMessage,
      );

      expect(result.actions.length, 1);
      expect(result.warnings, isEmpty);
    });

    test('validator drops action when entity name is not mentioned by user',
        () {
      const userMessage = 'Can you create a savings wallet with 5000?';
      final actions = [
        const CreateWalletAction(name: 'CryptoAccount', startingBalance: 5000),
      ];

      final result = validateAgainstUserMessage(
        actions: actions,
        userMessage: userMessage,
      );

      expect(result.actions, isEmpty);
    });

    test(
        'validator keeps create_wallet when Gemini name appears in user wording',
        () {
      const userMessage = 'Create a BDO wallet with 1983.67';
      final actions = [
        const CreateWalletAction(name: 'BDO', startingBalance: 1983.67),
      ];

      final result = validateAgainstUserMessage(
        actions: actions,
        userMessage: userMessage,
      );

      expect(result.actions.length, 1);
      expect(result.warnings, isEmpty);
    });

    test(
        'validator keeps adjust_wallet_balance when amount and wallet match user text',
        () {
      const userMessage = 'My MariBank balance is 50420.50';
      final actions = [
        const AdjustWalletBalanceAction(
            walletName: 'MariBank', targetBalance: 50420.50),
      ];

      final result = validateAgainstUserMessage(
        actions: actions,
        userMessage: userMessage,
      );

      expect(result.actions.length, 1);
      expect(result.warnings, isEmpty);
    });

    test(
        'validator drops adjust_wallet_balance when amount differs from user text',
        () {
      const userMessage = 'My MariBank balance is 50420.50';
      final actions = [
        const AdjustWalletBalanceAction(
            walletName: 'MariBank', targetBalance: 51000.00),
      ];

      final result = validateAgainstUserMessage(
        actions: actions,
        userMessage: userMessage,
      );

      expect(result.actions, isEmpty);
      expect(result.warnings.length, 1);
    });

    test(
        'validator clears walletName from log_income if user did not mention that wallet',
        () {
      const userMessage = 'I earned 1500';
      final actions = [
        const LogTransactionAction(
            amount: 1500,
            isIncome: true,
            category: 'Salary',
            walletName: 'GoTyme'),
      ];

      final result = validateAgainstUserMessage(
        actions: actions,
        userMessage: userMessage,
      );

      expect(result.actions.length, 1);
      expect((result.actions.first as LogTransactionAction).walletName, isNull);
    });
  });

  group('Debt Model & Schedule Serialization', () {
    test(
        'CreateDebtAction preserves schedule, dueDay, remainingPayments, billingDay, graceDays through toMap/fromMap',
        () {
      const fixedDebt = Debt(
        id: 'debt_fixed',
        name: 'Cash Loan',
        balance: 3587.64,
        apr: 18,
        minPayment: 3587.64,
        strategy: DebtStrategy.avalanche,
        schedule: DebtSchedule.fixed,
        dueDay: 27,
        remainingPayments: 7,
      );

      final map = fixedDebt.toMap();
      final roundTrip = Debt.fromMap(map);

      expect(roundTrip.id, 'debt_fixed');
      expect(roundTrip.name, 'Cash Loan');
      expect(roundTrip.balance, 3587.64);
      expect(roundTrip.apr, 18);
      expect(roundTrip.schedule, DebtSchedule.fixed);
      expect(roundTrip.dueDay, 27);
      expect(roundTrip.remainingPayments, 7);
      expect(roundTrip.paidOff, isFalse);

      const cycleDebt = Debt(
        id: 'debt_cycle',
        name: 'Atome',
        balance: 12500,
        apr: 36,
        minPayment: 500,
        strategy: DebtStrategy.snowball,
        schedule: DebtSchedule.statementCycle,
        billingDay: 25,
        graceDays: 10,
      );

      final cycleMap = cycleDebt.toMap();
      final cycleRoundTrip = Debt.fromMap(cycleMap);

      expect(cycleRoundTrip.name, 'Atome');
      expect(cycleRoundTrip.schedule, DebtSchedule.statementCycle);
      expect(cycleRoundTrip.billingDay, 25);
      expect(cycleRoundTrip.graceDays, 10);
    });

    test('fixed-schedule debt payment decrement behavior', () {
      const debt = Debt(
        id: 'loan_1',
        name: 'Cash Loan',
        balance: 7000,
        apr: 12,
        minPayment: 3500,
        strategy: DebtStrategy.avalanche,
        schedule: DebtSchedule.fixed,
        dueDay: 27,
        remainingPayments: 2,
      );

      // First payment: decrements remainingPayments to 1
      final remainingAfterFirst = (debt.remainingPayments! - 1).clamp(0, 9999);
      final debtAfterFirst = debt.copyWith(
        balance: (debt.balance - 3500).clamp(0, double.infinity),
        remainingPayments: remainingAfterFirst,
      );
      expect(debtAfterFirst.remainingPayments, 1);
      expect(debtAfterFirst.paidOff, isFalse);
      expect(debtAfterFirst.schedule, DebtSchedule.fixed);

      // Second payment: hits 0, marks paidOff = true, clears schedule
      final remainingAfterSecond =
          (debtAfterFirst.remainingPayments! - 1).clamp(0, 9999);
      expect(remainingAfterSecond, 0);

      final debtAfterSecond = debtAfterFirst.copyWith(
        balance: (debtAfterFirst.balance - 3500).clamp(0, double.infinity),
        paidOff: true,
        schedule: DebtSchedule.none,
        clearDueDay: true,
        clearRemainingPayments: true,
      );

      expect(debtAfterSecond.balance, 0);
      expect(debtAfterSecond.paidOff, isTrue);
      expect(debtAfterSecond.schedule, DebtSchedule.none);
      expect(debtAfterSecond.dueDay, isNull);
      expect(debtAfterSecond.remainingPayments, isNull);
    });
  });

  group('JSON Action Parser', () {
    test('parses create_wallet action', () {
      final json = {
        'type': 'create_wallet',
        'name': 'BDO',
        'starting_balance': 1983.67,
      };
      final action = parseJsonAction(json);
      expect(action, isA<CreateWalletAction>());
      final a = action as CreateWalletAction;
      expect(a.name, 'BDO');
      expect(a.startingBalance, 1983.67);
    });

    test('parses update_wallet and archive_wallet actions', () {
      final update = parseJsonAction({
        'type': 'update_wallet',
        'name': 'BDO',
        'new_name': 'BDO Savings',
      });
      expect(update, isA<UpdateWalletAction>());
      expect((update as UpdateWalletAction).newName, 'BDO Savings');

      final archive = parseJsonAction({
        'type': 'archive_wallet',
        'name': 'GCash',
      });
      expect(archive, isA<ArchiveWalletAction>());
      expect((archive as ArchiveWalletAction).name, 'GCash');
    });

    test('parses log_income and log_expense actions', () {
      final inc = parseJsonAction({
        'type': 'log_income',
        'amount': 5000,
        'category': 'Salary',
        'note': 'May pay',
      });
      expect(inc, isA<LogTransactionAction>());
      final income = inc as LogTransactionAction;
      expect(income.isIncome, isTrue);
      expect(income.amount, 5000);
      expect(income.category, 'Salary');
      expect(income.note, 'May pay');

      final exp = parseJsonAction({
        'type': 'log_expense',
        'amount': 200,
        'category': 'Food',
      });
      expect(exp, isA<LogTransactionAction>());
      final expense = exp as LogTransactionAction;
      expect(expense.isIncome, isFalse);
      expect(expense.amount, 200);
    });

    test('parses create_debt with fixed schedule', () {
      final json = {
        'type': 'create_debt',
        'name': 'Cash Loan',
        'balance': 3587.64,
        'apr': 18,
        'min_payment': 3587.64,
        'schedule': 'fixed',
        'due_day': 27,
        'remaining_payments': 7,
      };
      final action = parseJsonAction(json);
      expect(action, isA<CreateDebtAction>());
      final a = action as CreateDebtAction;
      expect(a.debt.name, 'Cash Loan');
      expect(a.debt.schedule, DebtSchedule.fixed);
      expect(a.debt.dueDay, 27);
      expect(a.debt.remainingPayments, 7);
    });

    test('parses create_debt with statementCycle schedule', () {
      final json = {
        'type': 'create_debt',
        'name': 'Atome',
        'balance': 12500,
        'apr': 36,
        'min_payment': 500,
        'schedule': 'statementCycle',
        'billing_day': 25,
        'grace_days': 10,
      };
      final action = parseJsonAction(json);
      expect(action, isA<CreateDebtAction>());
      final a = action as CreateDebtAction;
      expect(a.debt.name, 'Atome');
      expect(a.debt.schedule, DebtSchedule.statementCycle);
      expect(a.debt.billingDay, 25);
      expect(a.debt.graceDays, 10);
    });

    test('parses update_debt and delete_debt', () {
      final update = parseJsonAction({
        'type': 'update_debt',
        'name': 'Cash Loan',
        'new_min_payment': 4000,
      });
      expect(update, isA<UpdateDebtAction>());
      expect((update as UpdateDebtAction).newMinPayment, 4000);

      final del = parseJsonAction({
        'type': 'delete_debt',
        'name': 'Cash Loan',
      });
      expect(del, isA<DeleteDebtAction>());
      expect((del as DeleteDebtAction).name, 'Cash Loan');
    });

    test('parses goal and recurring actions', () {
      final createGoal = parseJsonAction({
        'type': 'create_goal',
        'name': 'Travel',
        'target': 20000,
      });
      expect(createGoal, isA<CreateGoalAction>());
      expect((createGoal as CreateGoalAction).goal.target, 20000);

      final addGoal = parseJsonAction({
        'type': 'add_to_goal',
        'name': 'Travel',
        'amount': 1500,
      });
      expect(addGoal, isA<AddToGoalAction>());
      expect((addGoal as AddToGoalAction).amount, 1500);

      final rec = parseJsonAction({
        'type': 'create_recurring',
        'name': 'Commute',
        'amount': 100,
        'frequency': 'daily',
        'kind': 'expense',
        'category': 'Transport',
      });
      expect(rec, isA<CreateRecurringAction>());
      expect((rec as CreateRecurringAction).recurring.intervalDays, 1);

      final updateRec = parseJsonAction({
        'type': 'update_recurring',
        'name': 'Commute',
        'new_amount': 120,
        'delete': true,
      });
      expect(updateRec, isA<UpdateRecurringAction>());
      expect((updateRec as UpdateRecurringAction).delete, isTrue);
    });

    test('parses adjust_wallet_balance and log_income with wallet_name', () {
      final adjust = parseJsonAction({
        'type': 'adjust_wallet_balance',
        'name': 'MariBank',
        'target_balance': 50420.50,
      });
      expect(adjust, isA<AdjustWalletBalanceAction>());
      expect((adjust as AdjustWalletBalanceAction).walletName, 'MariBank');
      expect(adjust.targetBalance, 50420.50);

      final income = parseJsonAction({
        'type': 'log_income',
        'amount': 84.32,
        'category': 'Investment',
        'wallet_name': 'GoTyme',
        'note': 'Interest',
      });
      expect(income, isA<LogTransactionAction>());
      final act = income as LogTransactionAction;
      expect(act.amount, 84.32);
      expect(act.walletName, 'GoTyme');
      expect(act.category, 'Investment');
      expect(act.note, 'Interest');
    });

    test('returns null for missing or invalid required fields', () {
      expect(parseJsonAction({}), isNull);
      expect(parseJsonAction({'type': 'unknown'}), isNull);
      expect(parseJsonAction({'type': 'log_income', 'amount': -50}), isNull);
      expect(parseJsonAction({'type': 'create_debt', 'name': ''}), isNull);
      expect(parseJsonAction({'type': 'adjust_wallet_balance', 'name': ''}),
          isNull);
    });
  });

  group('CoachActionParser Regex Interest & Balance Reconciliation', () {
    final parser = CoachActionParser();

    test('detects interest income with named wallet', () {
      final actions = parser.parse(
        assistantReply: '',
        userMessage: 'Received 85.20 interest from GoTyme',
      );
      expect(actions.length, 1);
      expect(actions.first, isA<LogTransactionAction>());
      final act = actions.first as LogTransactionAction;
      expect(act.amount, 85.20);
      expect(act.isIncome, isTrue);
      expect(act.category, 'Investment');
      expect(act.walletName, 'GoTyme');
    });

    test('detects balance statement as AdjustWalletBalanceAction', () {
      final actions = parser.parse(
        assistantReply: '',
        userMessage: 'My MariBank balance is 50420.50',
      );
      expect(actions.length, 1);
      expect(actions.first, isA<AdjustWalletBalanceAction>());
      final act = actions.first as AdjustWalletBalanceAction;
      expect(act.walletName, 'Maribank');
      expect(act.targetBalance, 50420.50);
    });

    test('detects reconcile command as AdjustWalletBalanceAction', () {
      final actions = parser.parse(
        assistantReply: '',
        userMessage: 'Adjust GoTyme balance to 15000',
      );
      expect(actions.length, 1);
      expect(actions.first, isA<AdjustWalletBalanceAction>());
      final act = actions.first as AdjustWalletBalanceAction;
      expect(act.walletName, 'GoTyme');
      expect(act.targetBalance, 15000);
    });
  });

  group('Installment Loan Parsing & Validation', () {
    test(
        'parseJsonAction computes min_payment fallback for fixed schedule debt',
        () {
      final action = parseJsonAction({
        'type': 'create_debt',
        'name': 'MariLoan',
        'balance': 16482.48,
        'schedule': 'fixed',
        'remaining_payments': 3,
        'due_day': 2,
      });

      expect(action, isA<CreateDebtAction>());
      final debt = (action as CreateDebtAction).debt;
      expect(debt.balance, 16482.48);
      expect(debt.minPayment, 5494.16);
      expect(debt.remainingPayments, 3);
      expect(debt.dueDay, 2);
      expect(debt.schedule, DebtSchedule.fixed);
    });

    test(
        'validator accepts CreateDebtAction with derived total balance (installment * count)',
        () {
      const userMessage =
          'Mariloan\nAmount: 5494.16\nDue Date: Every 2nd of the Month.\nit will be like that 3 more times';
      const action = CreateDebtAction(Debt(
        id: 'test_1',
        name: 'Mariloan',
        balance: 16482.48,
        apr: 0,
        minPayment: 5494.16,
        schedule: DebtSchedule.fixed,
        remainingPayments: 3,
        dueDay: 2,
        strategy: DebtStrategy.avalanche,
      ));

      final result = validateAgainstUserMessage(
        actions: [action],
        userMessage: userMessage,
      );

      expect(result.actions.length, 1);
      expect(result.warnings, isEmpty);
    });

    test(
        'validator drops CreateDebtAction when debt name is completely unmentioned',
        () {
      const userMessage = 'I have a loan of 5000 due every month';
      const action = CreateDebtAction(Debt(
        id: 'test_2',
        name: 'CryptoSharkCard',
        balance: 5000,
        apr: 0,
        minPayment: 500,
        strategy: DebtStrategy.avalanche,
      ));

      final result = validateAgainstUserMessage(
        actions: [action],
        userMessage: userMessage,
      );

      expect(result.actions, isEmpty);
    });

    test('parseJsonAction handles update_debt with new_balance and pay_debt',
        () {
      final update = parseJsonAction({
        'type': 'update_debt',
        'name': 'MariLoan',
        'new_balance': 41453.36,
        'new_min_payment': 5494.16,
        'new_remaining_payments': 9,
        'new_due_day': 2,
      });

      expect(update, isA<UpdateDebtAction>());
      final u = update as UpdateDebtAction;
      expect(u.name, 'MariLoan');
      expect(u.newBalance, 41453.36);
      expect(u.newMinPayment, 5494.16);
      expect(u.newRemainingPayments, 9);
      expect(u.newDueDay, 2);

      final pay = parseJsonAction({
        'type': 'pay_debt',
        'name': 'MariLoan',
        'amount': 5494.16,
      });
      expect(pay, isA<UpdateDebtBalanceAction>());
      expect((pay as UpdateDebtBalanceAction).amount, 5494.16);
    });

    test('validator validates UpdateDebtAction with newBalance', () {
      const userMessage =
          'Update Mariloan balance 41453.36 and min payment 5494.16';
      const action = UpdateDebtAction(
        name: 'Mariloan',
        newBalance: 41453.36,
        newMinPayment: 5494.16,
      );

      final result = validateAgainstUserMessage(
        actions: [action],
        userMessage: userMessage,
      );

      expect(result.actions.length, 1);
      expect(result.warnings, isEmpty);
    });

    test(
        'validator accepts action from recent context when user asks to recreate card',
        () {
      const userMessage = 'Can you create the Card again?';
      const recentTurns = [
        'why did my balance become 0',
        'Delete Mariloan Phase 2. Then update Mariloan: balance 41453.36, min payment 5494.16, due on the 2nd of every month, 9 remaining payments.',
      ];
      const action = CreateDebtAction(Debt(
        id: 'test_recreate',
        name: 'Mariloan',
        balance: 41453.36,
        apr: 0,
        minPayment: 5494.16,
        schedule: DebtSchedule.fixed,
        remainingPayments: 9,
        dueDay: 2,
        strategy: DebtStrategy.avalanche,
      ));

      final result = validateAgainstUserMessage(
        actions: [action],
        userMessage: userMessage,
        recentUserMessages: recentTurns,
      );

      expect(result.actions.length, 1);
      expect(result.warnings, isEmpty);
    });
  });
}
