import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';
import '../models/debt.dart';
import '../models/transaction.dart';
import 'database.dart';

const _uuid = Uuid();
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

  static Debt applyPaymentToDebt(Debt debt, double amount) {
    final nextBalance = (debt.balance - amount).clamp(0.0, double.infinity);
    final isPaid = nextBalance <= 0.005;
    var next = debt.copyWith(
      balance: isPaid ? 0.0 : nextBalance,
      paidOff: isPaid,
    );
    if (debt.schedule == DebtSchedule.fixed) {
      if (isPaid) {
        next = next.copyWith(
          paidOff: true,
          schedule: DebtSchedule.none,
          clearDueDay: true,
          clearRemainingPayments: true,
        );
      } else {
        final current = debt.remainingPayments ?? 1;
        final remaining = (current - 1).clamp(1, 9999);
        next = next.copyWith(remainingPayments: remaining);
      }
    }
    return next;
  }

  Future<Debt> recordPayment({
    required Debt debt,
    required double amount,
    String? walletId,
    String? transactionId,
    DateTime? date,
  }) async {
    final updated = applyPaymentToDebt(debt, amount);
    final db = await _appDb.db;
    await db.transaction((txn) async {
      await txn.update(
        'debts',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );
      if (walletId != null && walletId.isNotEmpty) {
        final expenseTxn = Transaction(
          id: transactionId ?? _uuid.v4(),
          amount: amount,
          type: TransactionType.expense,
          category: 'Debt Payment',
          note: 'Payment to ${debt.name}',
          date: date ?? DateTime.now(),
          walletId: walletId,
        );
        await txn.insert(
          'transactions',
          expenseTxn.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    return updated;
  }
}
