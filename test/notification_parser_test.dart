import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/data/database.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/services/notification_listener.dart';
import 'package:finance_tracker/services/notification_parser.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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

  group('NotificationListenerService integration', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late AppDatabase db;
    late Database rawDb;
    late NotificationListenerService service;

    setUp(() async {
      db = AppDatabase.instance;
      db.overridePath = inMemoryDatabasePath;
      await db.close();
      rawDb = await db.db;
      service = NotificationListenerService();
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('finance_tracker/notifications'),
        null,
      );
      await db.close();
    });

    Future<void> insertWallet({
      required String id,
      required String name,
      required String logoAsset,
    }) async {
      await rawDb.insert('wallets', {
        'id': id,
        'name': name,
        'type': 'ewallet',
        'starting_balance': 1000.0,
        'currency': 'PHP',
        'color_value': 0xFF007DFE,
        'archived': 0,
        'logo_asset': logoAsset,
      });
    }

    test('deduplicates reposted notifications with identical key and postTime',
        () async {
      await insertWallet(
        id: 'w-gcash',
        name: 'GCash',
        logoAsset: 'assets/logos/gcash.svg',
      );
      final payload = {
        'key': '0|com.globe.gcash.android|1|null|10123_1700000000000',
        'packageName': 'com.globe.gcash.android',
        'title': 'GCash',
        'text': 'You sent ₱340.00 to Jollibee',
        'postedAt': 1700000000000,
      };

      final results = await Future.wait([
        service.processNotification(db, payload, isEnabled: () => true),
        service.processNotification(db, payload, isEnabled: () => true),
      ]);

      expect(results.where((t) => t != null), hasLength(1));
      final txns = await rawDb.query('transactions');
      final events = await rawDb.query('notification_events');
      expect(txns, hasLength(1));
      expect(events, hasLength(1));
    });

    test(
        'does not charge unrelated wallet when notification package has no matching wallet',
        () async {
      await insertWallet(
        id: 'w-cash',
        name: 'Cash',
        logoAsset: 'assets/logos/cash.svg',
      );

      final txn = await service.processNotification(
        db,
        {
          'key': 'bdo_1_1700000005000',
          'packageName': 'com.bdo.bdopersonal',
          'title': 'BDO',
          'text': 'You paid ₱1,200.00 to SM Store',
          'postedAt': 1700000005000,
        },
        isEnabled: () => true,
      );

      expect(txn, isNull);
      final txns = await rawDb.query('transactions');
      final events = await rawDb.query('notification_events');
      expect(txns, isEmpty);
      expect(events, hasLength(1));
      expect(events.single['parse_status'], 'unparsed');
    });

    test('skips processing when auto-capture toggle is disabled', () async {
      await insertWallet(
        id: 'w-gcash',
        name: 'GCash',
        logoAsset: 'assets/logos/gcash.svg',
      );

      final txn = await service.processNotification(
        db,
        {
          'key': 'gcash_2_1700000010000',
          'packageName': 'com.globe.gcash.android',
          'title': 'GCash',
          'text': 'You sent ₱150.00 to Grab',
          'postedAt': 1700000010000,
        },
        isEnabled: () => false,
      );

      expect(txn, isNull);
      expect(await rawDb.query('transactions'), isEmpty);
      expect(await rawDb.query('notification_events'), isEmpty);
    });

    test(
        'flushPendingNotifications peeks queued notifications and ACKs only after DB commit',
        () async {
      await insertWallet(
        id: 'w-maya',
        name: 'Maya',
        logoAsset: 'assets/logos/maya.svg',
      );

      final ackedKeys = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('finance_tracker/notifications'),
        (call) async {
          if (call.method == 'peekPendingNotifications') {
            return [
              {
                'key': 'maya_queued_1',
                'packageName': 'com.paymaya',
                'title': 'Maya',
                'text': 'Paid to Jollibee PHP 199.00 successfully',
                'postedAt': 1700000020000,
              }
            ];
          }
          if (call.method == 'ackPendingNotifications') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            ackedKeys.addAll((args['keys'] as List).cast<String>());
            return true;
          }
          return null;
        },
      );

      final count = await service.flushPendingNotifications(
        db,
        isEnabled: () => true,
      );

      expect(count, 1);
      expect(ackedKeys, ['maya_queued_1']);
      final txns = await rawDb.query('transactions');
      expect(txns, hasLength(1));
      expect(txns.single['amount'], 199.0);
    });
  });
}
