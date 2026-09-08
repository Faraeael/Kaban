import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
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

  /// Silently writes a timestamped backup to the app documents directory
  /// under an `auto_backups/` subfolder, keeping only the latest 5 backups.
  Future<String?> autoBackup() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(path.join(dir.path, 'auto_backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final bytes = await export();
      final filePath = path.join(backupDir.path, backupFileName());
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Clean up older auto backups beyond 5
      final entities = await backupDir.list().toList();
      final files = entities
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      if (files.length > 5) {
        files.sort(
            (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        while (files.length > 5) {
          final oldest = files.removeAt(0);
          await oldest.delete();
        }
      }
      return filePath;
    } catch (_) {
      return null;
    }
  }
}
