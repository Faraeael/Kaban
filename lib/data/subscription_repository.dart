import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/subscription.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import 'database.dart';

class SubscriptionRepository {
  final AppDatabase _appDb;
  SubscriptionRepository(this._appDb);
  static const _uuid = Uuid();


  Future<List<Subscription>> listAll() async {
    final db = await _appDb.db;
    final rows =
        await db.query('subscriptions', orderBy: 'next_billing_date ASC');
    return rows.map(Subscription.fromMap).toList();
  }

  Future<void> insert(Subscription sub) async {
    final db = await _appDb.db;
    await db.insert('subscriptions', sub.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Subscription sub) async {
    final db = await _appDb.db;
    await db.update('subscriptions', sub.toMap(),
        where: 'id = ?', whereArgs: [sub.id]);
  }

  Future<Subscription> recordPayment({
    required Subscription subscription,
    required String walletId,
    required DateTime nextDate,
    DateTime? date,
    String? transactionId,
  }) async {
    final updated = subscription.copyWith(
      nextBillingDate: nextDate,
      walletId: walletId,
    );
    final effectiveTxnId = transactionId ??
        _uuid.v5(
          Namespace.url.value,
          'kaban:subscription:${subscription.id}:${subscription.nextBillingDate.millisecondsSinceEpoch}',
        );
    final db = await _appDb.db;
    await db.transaction((txn) async {
      // Gate update on current next_billing_date to prevent race / double-pay:
      final affected = await txn.update(
        'subscriptions',
        updated.toMap(),
        where: 'id = ? AND next_billing_date = ?',
        whereArgs: [
          subscription.id,
          subscription.nextBillingDate.millisecondsSinceEpoch,
        ],
      );
      if (affected == 0) {
        throw StateError(
          'Subscription ${subscription.name} was already paid or billing date modified concurrently.',
        );
      }
      final expenseTxn = Transaction(
        id: effectiveTxnId,
        amount: subscription.amount,
        type: TransactionType.expense,
        category: subscription.category,
        note: '${subscription.name} subscription',
        date: date ?? DateTime.now(),
        walletId: walletId,
      );
      await txn.insert(
        'transactions',
        expenseTxn.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    return updated;
  }
  Future<void> delete(String id) async {
    final db = await _appDb.db;
    await db.delete('subscriptions', where: 'id = ?', whereArgs: [id]);
  }
}
