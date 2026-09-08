import 'package:sqflite/sqflite.dart';
import '../models/subscription.dart';
import 'database.dart';

class SubscriptionRepository {
  final AppDatabase _appDb;
  SubscriptionRepository(this._appDb);

  Future<List<Subscription>> listAll() async {
    final db = await _appDb.db;
    final rows = await db.query('subscriptions', orderBy: 'next_billing_date ASC');
    return rows.map(Subscription.fromMap).toList();
  }

  Future<void> insert(Subscription sub) async {
    final db = await _appDb.db;
    await db.insert('subscriptions', sub.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Subscription sub) async {
    final db = await _appDb.db;
    await db.update('subscriptions', sub.toMap(), where: 'id = ?', whereArgs: [sub.id]);
  }

  Future<void> delete(String id) async {
    final db = await _appDb.db;
    await db.delete('subscriptions', where: 'id = ?', whereArgs: [id]);
  }
}