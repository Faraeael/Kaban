import 'package:sqflite/sqflite.dart';
import '../models/notification_event.dart';
import 'database.dart';

class NotificationEventRepository {
  final AppDatabase _appDb;
  NotificationEventRepository(this._appDb);

  Future<List<NotificationEvent>> listRecent({int limit = 200}) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'notification_events',
      orderBy: 'received_at DESC',
      limit: limit,
    );
    return rows.map(NotificationEvent.fromMap).toList();
  }

  Future<List<NotificationEvent>> listUnparsed({int limit = 100}) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'notification_events',
      where: 'parse_status = ?',
      whereArgs: ['unparsed'],
      orderBy: 'received_at DESC',
      limit: limit,
    );
    return rows.map(NotificationEvent.fromMap).toList();
  }

  Future<void> insert(NotificationEvent e) async {
    final db = await _appDb.db;
    await db.insert('notification_events', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAll() async {
    final db = await _appDb.db;
    await db.delete('notification_events');
  }
}
