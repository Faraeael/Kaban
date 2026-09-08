import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/services/notification_parser.dart';

void main() {
  group('NotificationParser', () {
    final parser = NotificationParser();

    test('parses GCash send notification', () {
      final result = parser.parse(
        packageName: 'com.globe.gcash.android',
        title: 'GCash',
        text: 'You sent ₱340.00 to Jollibee',
      );
      expect(result.success, true);
      expect(result.amount, 340);
      expect(result.type, TransactionType.expense);
      expect(result.merchant, contains('Jollibee'));
    });

    test('parses received notification as income', () {
      final result = parser.parse(
        packageName: 'com.paymaya',
        title: 'Maya',
        text: 'You received ₱1,500.00 from Juan Dela Cruz',
      );
      expect(result.success, true);
      expect(result.amount, 1500);
      expect(result.type, TransactionType.income);
    });

    test('ignores balance update notifications', () {
      final result = parser.parse(
        packageName: 'com.bdo.bdopersonal',
        title: 'BDO',
        text: 'Your available balance is ₱50,000.00',
      );
      expect(result.success, false);
    });

    test('parses interest credit notifications even when balance is mentioned',
        () {
      final result = parser.parse(
        packageName: 'com.gotyme.bank',
        title: 'GoTyme Bank',
        text:
            'Interest of ₱84.32 credited to your Go Save account. Your balance is ₱50,084.32',
      );
      expect(result.success, true);
      expect(result.amount, 84.32);
      expect(result.type, TransactionType.income);
      expect(result.category, 'Investment');
    });

    test('parses daily interest earned notifications', () {
      final result = parser.parse(
        packageName: 'ph.seabank.mobile',
        title: 'MariBank',
        text: 'Daily interest of ₱12.45 has been added to your account',
      );
      expect(result.success, true);
      expect(result.amount, 12.45);
      expect(result.type, TransactionType.income);
      expect(result.category, 'Investment');
    });

    test('returns unparsed when no amount present', () {
      final result = parser.parse(
        packageName: 'com.bpi.mobileapp',
        title: 'BPI',
        text: 'You have a new promotion!',
      );
      expect(result.success, false);
    });

    test('parses merchant payment notifications as expense', () {
      final r1 = parser.parse(
        packageName: 'com.paymaya',
        title: 'Maya',
        text: 'Paid to Grab PHP 250.00 successfully',
      );
      expect(r1.success, true);
      expect(r1.amount, 250);
      expect(r1.type, TransactionType.expense);
      expect(r1.category, 'Transport');

      final r2 = parser.parse(
        packageName: 'com.globe.gcash.android',
        title: 'GCash',
        text: 'Payment of PHP 500.00 to Jollibee was successful',
      );
      expect(r2.success, true);
      expect(r2.amount, 500);
      expect(r2.type, TransactionType.expense);
      expect(r2.category, 'Food');
    });
  });
}
