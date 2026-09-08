import 'package:sqflite/sqflite.dart';
import '../models/budget.dart';
import 'database.dart';

class BudgetRepository {
  final AppDatabase _appDb;
  BudgetRepository(this._appDb);

  Future<List<Budget>> listAll() async {
    final db = await _appDb.db;
    final rows = await db.query('budgets', orderBy: 'category ASC');
    return rows.map(Budget.fromMap).toList();
  }

  Future<void> upsert(Budget budget) async {
    final db = await _appDb.db;
    await db.insert('budgets', budget.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final db = await _appDb.db;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }
}