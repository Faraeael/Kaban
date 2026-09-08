import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/transaction.dart';
import 'database.dart';

class TransactionRepository {
  final AppDatabase _appDb;
  TransactionRepository(this._appDb);

  Future<List<Transaction>> listAll({int? limit}) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit,
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> listByWallet(String walletId, {int? limit}) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'transactions',
      where: 'wallet_id = ?',
      whereArgs: [walletId],
      orderBy: 'date DESC',
      limit: limit,
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> listByMonth(DateTime month) async {
    final db = await _appDb.db;
    final start = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
    final end = DateTime(month.year, month.month + 1, 1).millisecondsSinceEpoch;
    final rows = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> listAllExcludingTransfers() async {
    final db = await _appDb.db;
    final rows = await db.query(
      'transactions',
      where: 'transfer_pair_id IS NULL',
      orderBy: 'date DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<void> insert(Transaction t) async {
    final db = await _appDb.db;
    await db.insert('transactions', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertMany(List<Transaction> txns) async {
    final db = await _appDb.db;
    final batch = db.batch();
    for (final t in txns) {
      batch.insert('transactions', t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> update(Transaction t) async {
    final db = await _appDb.db;
    await db
        .update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> delete(String id) async {
    final db = await _appDb.db;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByTransferPair(String pairId) async {
    final db = await _appDb.db;
    await db.delete('transactions',
        where: 'transfer_pair_id = ?', whereArgs: [pairId]);
  }
}
