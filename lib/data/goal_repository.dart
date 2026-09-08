import 'package:sqflite/sqflite.dart';
import '../models/goal.dart';
import 'database.dart';

class GoalRepository {
  final AppDatabase _appDb;
  GoalRepository(this._appDb);

  Future<List<Goal>> listAll() async {
    final db = await _appDb.db;
    final rows = await db.query('goals',
        orderBy: 'deadline IS NULL, deadline ASC, name ASC');
    return rows.map(Goal.fromMap).toList();
  }

  Future<void> insert(Goal goal) async {
    final db = await _appDb.db;
    await db.insert('goals', goal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Goal goal) async {
    final db = await _appDb.db;
    await db
        .update('goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<void> delete(String id) async {
    final db = await _appDb.db;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }
}
