import 'package:sqflite/sqflite.dart';
import '../models/wallet.dart';
import 'database.dart';

class WalletRepository {
  final AppDatabase _appDb;
  WalletRepository(this._appDb);

  Future<List<Wallet>> listAll({bool includeArchived = true}) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'wallets',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'archived ASC, name ASC',
    );
    return rows.map(Wallet.fromMap).toList();
  }

  Future<Wallet?> findById(String id) async {
    final db = await _appDb.db;
    final rows =
        await db.query('wallets', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Wallet.fromMap(rows.first);
  }

  Future<Wallet?> findByPackage(String packageName) async {
    final db = await _appDb.db;
    final rows = await db.query('wallets', limit: 1000);
    for (final row in rows) {
      final wallet = Wallet.fromMap(row);
      final preset = kWalletPresets.firstWhere(
        (p) => p.name == wallet.name,
        orElse: () => const WalletPreset(
          name: '',
          type: WalletType.cash,
          colorValue: 0,
          logoAsset: '',
        ),
      );
      if (preset.notificationPackage == packageName) return wallet;
    }
    return null;
  }

  Future<void> insert(Wallet wallet) async {
    final db = await _appDb.db;
    await db.insert('wallets', wallet.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Wallet wallet) async {
    final db = await _appDb.db;
    await db.update('wallets', wallet.toMap(),
        where: 'id = ?', whereArgs: [wallet.id]);
  }

  Future<void> delete(String id) async {
    final db = await _appDb.db;
    await db.transaction((txn) async {
      final batch = txn.batch();
      // Remove both halves of any transfers touching this wallet.
      batch.delete(
        'transactions',
        where: 'wallet_id = ? OR transfer_pair_id IN (SELECT transfer_pair_id '
            'FROM transactions WHERE wallet_id = ? AND transfer_pair_id IS NOT NULL)',
        whereArgs: [id, id],
      );
      batch.delete('subscriptions', where: 'wallet_id = ?', whereArgs: [id]);
      batch.delete('recurring_transactions',
          where: 'wallet_id = ?', whereArgs: [id]);
      batch.delete('debts', where: 'linked_wallet_id = ?', whereArgs: [id]);
      batch.delete('wallets', where: 'id = ?', whereArgs: [id]);
      await batch.commit(noResult: true);
    });
  }
}
