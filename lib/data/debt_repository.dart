import 'package:sqflite/sqflite.dart';
import '../models/debt.dart';
import 'database.dart';

class DebtRepository {
  final AppDatabase _appDb;
  DebtRepository(this._appDb);

  Future<List<Debt>> listAll() async {
    final db = await _appDb.db;
    final rows = await db.query('debts', orderBy: 'balance DESC');
    return rows.map(Debt.fromMap).toList();
  }

  Future<void> insert(Debt debt) async {
    final db = await _appDb.db;
    await db.insert('debts', debt.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Debt debt) async {
    final db = await _appDb.db;
    await db
        .update('debts', debt.toMap(), where: 'id = ?', whereArgs: [debt.id]);
  }

  Future<void> delete(String id) async {
    final db = await _appDb.db;
    await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }
}
