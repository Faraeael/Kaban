import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../data/database.dart';

class BackupService {
  final AppDatabase _db;
  BackupService(this._db);

  static const _tables = [
    'wallets',
    'transactions',
    'debts',
    'goals',
    'budgets',
    'subscriptions',
    'chat_messages',
    'notification_events',
    'recurring_transactions',
  ];

  Future<Uint8List> export() async {
    final database = await _db.db;
    final data = <String, dynamic>{
      'app': 'kaban',
      'schemaVersion': 5,
    };
    for (final table in _tables) {
      data[table] = await database.query(table);
    }
    return Uint8List.fromList(utf8.encode(json.encode(data)));
  }

  /// Restores all tables from a backup payload. Wipes current data first,
  /// inside a single transaction so a failure leaves nothing half-written.
  Future<void> import(Map<String, dynamic> data) async {
    final app = data['app'];
    if (app != 'kaban' && app != 'finance_tracker') {
      throw const FormatException('Not a Kaban backup file.');
    }
    final database = await _db.db;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final table in _tables) {
        batch.delete(table);
      }
      for (final table in _tables) {
        final rows = (data[table] as List?) ?? const [];
        for (final row in rows) {
          batch.insert(
            table,
            Map<String, Object?>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await batch.commit(noResult: true);
    });
  }

  static String backupFileName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'kaban_backup_'
        '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}.json';
  }
}
