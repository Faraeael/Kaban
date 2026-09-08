import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  static const int _dbVersion = 6;

  /// Test seam: overrides the on-disk path for in-memory / ffi databases.
  String? overridePath;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = overridePath ??
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          'finance_tracker.db',
        );
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE wallets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        starting_balance REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'PHP',
        color_value INTEGER NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0,
        logo_asset TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        date INTEGER NOT NULL,
        wallet_id TEXT NOT NULL,
        transfer_pair_id TEXT,
        auto_captured INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        balance REAL NOT NULL,
        apr REAL NOT NULL,
        min_payment REAL NOT NULL,
        strategy TEXT NOT NULL,
        linked_wallet_id TEXT,
        schedule TEXT NOT NULL DEFAULT 'none',
        due_day INTEGER,
        remaining_payments INTEGER,
        paid_off INTEGER NOT NULL DEFAULT 0,
        billing_day INTEGER,
        grace_days INTEGER
      )
    ''');
    batch.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        target REAL NOT NULL,
        saved REAL NOT NULL,
        deadline INTEGER
      )
    ''');
    batch.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        monthly_limit REAL NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE subscriptions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        cadence TEXT NOT NULL,
        next_billing_date INTEGER NOT NULL,
        category TEXT NOT NULL,
        wallet_id TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE notification_events (
        id TEXT PRIMARY KEY,
        package_name TEXT NOT NULL,
        raw_title TEXT NOT NULL,
        raw_text TEXT NOT NULL,
        received_at INTEGER NOT NULL,
        parse_status TEXT NOT NULL,
        transaction_id TEXT
      )
    ''');
    batch.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        image_path TEXT
      )
    ''');
    batch.execute('''
      CREATE TABLE recurring_transactions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        interval_days INTEGER NOT NULL,
        next_due INTEGER NOT NULL,
        wallet_id TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_txn_wallet_date ON transactions(wallet_id, date)');
    batch.execute('CREATE INDEX idx_txn_date ON transactions(date)');
    batch.execute('CREATE INDEX idx_sub_wallet ON subscriptions(wallet_id)');
    batch.execute(
        'CREATE INDEX idx_notif_received ON notification_events(received_at)');
    batch.execute(
        'CREATE INDEX idx_recurring_due ON recurring_transactions(next_due)');
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS wallets (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          starting_balance REAL NOT NULL,
          currency TEXT NOT NULL DEFAULT 'PHP',
          color_value INTEGER NOT NULL,
          archived INTEGER NOT NULL DEFAULT 0,
          logo_asset TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS subscriptions (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          cadence TEXT NOT NULL,
          next_billing_date INTEGER NOT NULL,
          category TEXT NOT NULL,
          wallet_id TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notification_events (
          id TEXT PRIMARY KEY,
          package_name TEXT NOT NULL,
          raw_title TEXT NOT NULL,
          raw_text TEXT NOT NULL,
          received_at INTEGER NOT NULL,
          parse_status TEXT NOT NULL,
          transaction_id TEXT
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sub_wallet ON subscriptions(wallet_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_notif_received ON notification_events(received_at)');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_transactions (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          category TEXT NOT NULL,
          interval_days INTEGER NOT NULL,
          next_due INTEGER NOT NULL,
          wallet_id TEXT NOT NULL,
          enabled INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_recurring_due ON recurring_transactions(next_due)');
    }
    if (oldVersion < 5) {
      await db.execute(
          "ALTER TABLE debts ADD COLUMN schedule TEXT NOT NULL DEFAULT 'none'");
      await db.execute("ALTER TABLE debts ADD COLUMN due_day INTEGER");
      await db
          .execute("ALTER TABLE debts ADD COLUMN remaining_payments INTEGER");
      await db.execute(
          "ALTER TABLE debts ADD COLUMN paid_off INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE debts ADD COLUMN billing_day INTEGER");
      await db.execute("ALTER TABLE debts ADD COLUMN grace_days INTEGER");
    }
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE chat_messages ADD COLUMN image_path TEXT");
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
