import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';

const _uuid = Uuid();

/// Result of a recurring-processing pass.
class RecurringRunResult {
  final int created;
  final List<String> entryNames;
  const RecurringRunResult({required this.created, required this.entryNames});
}

/// Processes due recurring transactions: for each enabled recurring entry
/// whose next_due has passed, creates the corresponding transaction and
/// rolls next_due forward until it is in the future. Catch-up covers gaps
/// (e.g. a daily commute missed over a weekend).
class RecurringEngine {
  static Future<void> _runLock = Future.value();
  final AppDatabase _db;
  RecurringEngine(this._db);

  static String occurrenceTransactionId(String recurringId, DateTime dueAt) {
    return _uuid.v5(
      Namespace.url.value,
      'kaban:recurring:$recurringId:${dueAt.millisecondsSinceEpoch}',
    );
  }

  Future<RecurringRunResult> processDue(DateTime now) {
    final run = _runLock.then((_) => _processDueInternal(now));
    _runLock = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<RecurringRunResult> _processDueInternal(DateTime now) async {
    final database = await _db.db;
    var created = 0;
    final names = <String>{};

    await database.transaction((txn) async {
      final rows = await txn.query(
        'recurring_transactions',
        where: 'enabled = 1 AND next_due <= ?',
        whereArgs: [now.millisecondsSinceEpoch],
        orderBy: 'next_due ASC',
      );
      final due = rows.map(RecurringTransaction.fromMap).toList();

      for (final r in due) {
        final stepDays = r.intervalDays <= 0 ? 1 : r.intervalDays;
        var next = r.nextDue;
        var cursor = r;
        while (!next.isAfter(now)) {
          final txnId = occurrenceTransactionId(r.id, next);
          final inserted = await txn.insert(
            'transactions',
            Transaction(
              id: txnId,
              amount: r.amount,
              type: r.type,
              category: r.category,
              note: r.name,
              date: next,
              walletId: r.walletId,
              autoCaptured: true,
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (inserted > 0) {
            created++;
            names.add(r.name);
          }
          next = next.add(Duration(days: stepDays));
          cursor = cursor.copyWith(nextDue: next);
        }
        await txn.update(
          'recurring_transactions',
          cursor.toMap(),
          where: 'id = ?',
          whereArgs: [r.id],
        );
      }
    });

    return RecurringRunResult(created: created, entryNames: names.toList());
  }
}
