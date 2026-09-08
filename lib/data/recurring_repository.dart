import 'package:sqflite/sqflite.dart';
import '../models/recurring_transaction.dart';
import 'database.dart';

class RecurringRepository {
  final AppDatabase _appDb;
  RecurringRepository(this._appDb);

  Future<List<RecurringTransaction>> listAll() async {
    final db = await _appDb.db;
    final rows = await db.query(
      'recurring_transactions',
      orderBy: 'next_due ASC',
    );
    return rows.map(RecurringTransaction.fromMap).toList();
  }

  Future<List<RecurringTransaction>> listDue(DateTime now) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'recurring_transactions',
      where: 'enabled = 1 AND next_due <= ?',
      whereArgs: [now.millisecondsSinceEpoch],
      orderBy: 'next_due ASC',
    );
    return rows.map(RecurringTransaction.fromMap).toList();
  }

  Future<void> insert(RecurringTransaction r) async {
    final db = await _appDb.db;
    await db.insert('recurring_transactions', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(RecurringTransaction r) async {
    final db = await _appDb.db;
    await db.update('recurring_transactions', r.toMap(),
        where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> delete(String id) async {
    final db = await _appDb.db;
    await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
  }
}
