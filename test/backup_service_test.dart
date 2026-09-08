import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:finance_tracker/data/database.dart';
import 'package:finance_tracker/services/backup_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('BackupService', () {
    late AppDatabase db;
    late BackupService service;

    setUp(() async {
      db = AppDatabase.instance;
      db.overridePath = inMemoryDatabasePath;
      await db.close();
      service = BackupService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('exports and imports all tables including recurring_transactions',
        () async {
      final database = await db.db;

      // Insert sample wallet
      await database.insert('wallets', {
        'id': 'w1',
        'name': 'BDO',
        'type': 'bank',
        'starting_balance': 1000.0,
        'currency': 'PHP',
        'color_value': 0xFF000000,
        'archived': 0,
        'logo_asset': 'assets/logos/bdo.svg',
      });

      // Insert sample recurring transaction
      await database.insert('recurring_transactions', {
        'id': 'r1',
        'name': 'MRT Commute',
        'amount': 30.0,
        'type': 'expense',
        'category': 'Transport',
        'interval_days': 1,
        'next_due': DateTime.now().millisecondsSinceEpoch,
        'wallet_id': 'w1',
        'enabled': 1,
      });

      // Export
      final bytes = await service.export();
      expect(bytes, isNotEmpty);

      final decoded = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(decoded['app'], 'kaban');
      expect((decoded['recurring_transactions'] as List).length, 1);
      expect((decoded['wallets'] as List).length, 1);

      // Wipe database
      await database.delete('recurring_transactions');
      await database.delete('wallets');
      expect((await database.query('recurring_transactions')).isEmpty, true);

      // Import back
      await service.import(decoded);

      // Verify restored
      final restoredRecurring = await database.query('recurring_transactions');
      expect(restoredRecurring.length, 1);
      expect(restoredRecurring.first['name'], 'MRT Commute');
      expect(restoredRecurring.first['amount'], 30.0);

      final restoredWallets = await database.query('wallets');
      expect(restoredWallets.length, 1);
      expect(restoredWallets.first['name'], 'BDO');
    });

    test(
        'backward compatibility: successfully imports legacy finance_tracker backup',
        () async {
      final database = await db.db;
      final legacyData = <String, dynamic>{
        'app': 'finance_tracker',
        'schemaVersion': 5,
        'wallets': [
          {
            'id': 'w_legacy',
            'name': 'GCash',
            'type': 'e_wallet',
            'starting_balance': 500.0,
            'currency': 'PHP',
            'color_value': 0xFF007DFE,
            'archived': 0,
            'logo_asset': 'assets/logos/gcash.svg',
          }
        ],
        'transactions': [],
        'debts': [],
        'goals': [],
        'budgets': [],
        'subscriptions': [],
        'chat_messages': [],
        'notification_events': [],
        'recurring_transactions': [],
      };

      await service.import(legacyData);

      final restored = await database.query('wallets');
      expect(restored.length, 1);
      expect(restored.first['name'], 'GCash');
    });
  });
}
