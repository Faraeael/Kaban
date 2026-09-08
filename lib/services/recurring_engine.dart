import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../data/recurring_repository.dart';
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
  final AppDatabase _db;
  RecurringEngine(this._db);

  Future<RecurringRunResult> processDue(DateTime now) async {
    final repo = RecurringRepository(_db);
    final due = await repo.listDue(now);
    var created = 0;
    final names = <String>{};

    for (final r in due) {
      var next = r.nextDue;
      final database = await _db.db;
      final batch = database.batch();
      var cursor = r;
      while (!next.isAfter(now)) {
        batch.insert(
          'transactions',
          Transaction(
            id: _uuid.v4(),
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
        created++;
        names.add(r.name);
        next = next.add(Duration(days: r.intervalDays));
        cursor = cursor.copyWith(nextDue: next);
      }
      batch.update(
        'recurring_transactions',
        cursor.toMap(),
        where: 'id = ?',
        whereArgs: [r.id],
      );
      await batch.commit(noResult: true);
    }
    return RecurringRunResult(created: created, entryNames: names.toList());
  }
}
