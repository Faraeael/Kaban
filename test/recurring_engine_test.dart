import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/data/database.dart';
import 'package:finance_tracker/data/recurring_repository.dart';
import 'package:finance_tracker/models/recurring_transaction.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/services/recurring_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late RecurringEngine engine;
  late RecurringRepository repo;
  late Database rawDb;

  setUp(() async {
    db = AppDatabase.instance;
    db.overridePath = inMemoryDatabasePath;
    db.close();
    engine = RecurringEngine(db);
    repo = RecurringRepository(db);
    rawDb = await db.db;
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addWallet() async {
    await rawDb.insert('wallets', {
      'id': 'w1',
      'name': 'Maya',
      'type': 'ewallet',
      'starting_balance': 1000,
      'currency': 'PHP',
      'color_value': 0xFF1A1A1A,
      'archived': 0,
      'logo_asset': 'assets/logos/maya.svg',
    });
  }

  test('creates transaction when due and rolls next_due forward', () async {
    await addWallet();
    final due = DateTime(2026, 9, 1, 8);
    await repo.insert(RecurringTransaction(
      id: 'r1',
      name: 'Commute',
      amount: 100,
      type: TransactionType.expense,
      category: 'Transport',
      intervalDays: 1,
      nextDue: due,
      walletId: 'w1',
    ));

    final result = await engine.processDue(DateTime(2026, 9, 2, 9));
    expect(result.created, 2); // Sep 1 8:00 and Sep 2 8:00 are both due by 9:00
    expect(result.entryNames, ['Commute']);

    final txns =
        await rawDb.query('transactions', where: 'wallet_id = ?', whereArgs: ['w1']);
    expect(txns, hasLength(2));
    expect(txns.first['amount'], 100);
    expect(txns.first['note'], 'Commute');
    expect(txns.first['date'], due.millisecondsSinceEpoch);

    final recurring = await repo.listAll();
    expect(recurring.single.nextDue, DateTime(2026, 9, 3, 8));
  });

  test('catch-up creates multiple missed entries with correct dates', () async {
    await addWallet();
    await repo.insert(RecurringTransaction(
      id: 'r2',
      name: 'Work lunch',
      amount: 250,
      type: TransactionType.expense,
      category: 'Food',
      intervalDays: 1,
      nextDue: DateTime(2026, 9, 1, 12),
      walletId: 'w1',
    ));

    // 3 days pass without opening the app; Sep 4 12:00 isn't due yet at 9:00.
    final result = await engine.processDue(DateTime(2026, 9, 4, 9));
    expect(result.created, 3); // Sep 1, 2, 3
    expect(result.entryNames, ['Work lunch']);

    final txns = await rawDb.query('transactions', orderBy: 'date ASC');
    expect(txns, hasLength(3));
    expect(txns.first['date'], DateTime(2026, 9, 1, 12).millisecondsSinceEpoch);
    expect(txns.last['date'], DateTime(2026, 9, 3, 12).millisecondsSinceEpoch);

    final recurring = await repo.listAll();
    expect(recurring.single.nextDue, DateTime(2026, 9, 4, 12));
  });

  test('skips disabled entries', () async {
    await addWallet();
    await repo.insert(RecurringTransaction(
      id: 'r3',
      name: 'Disabled',
      amount: 50,
      type: TransactionType.expense,
      category: 'Other',
      intervalDays: 1,
      nextDue: DateTime(2026, 9, 1),
      walletId: 'w1',
      enabled: false,
    ));

    final result = await engine.processDue(DateTime(2026, 9, 5));
    expect(result.created, 0);
    expect(result.entryNames, isEmpty);
    final txns = await rawDb.query('transactions');
    expect(txns, isEmpty);
  });

  test('does nothing when nothing is due', () async {
    await addWallet();
    await repo.insert(RecurringTransaction(
      id: 'r4',
      name: 'Future',
      amount: 100,
      type: TransactionType.expense,
      category: 'Other',
      intervalDays: 7,
      nextDue: DateTime(2026, 9, 10),
      walletId: 'w1',
    ));

    final result = await engine.processDue(DateTime(2026, 9, 1));
    expect(result.created, 0);
  });
}
