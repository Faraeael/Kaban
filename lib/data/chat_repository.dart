import 'package:sqflite/sqflite.dart';
import '../models/chat_message.dart';
import 'database.dart';

class ChatRepository {
  final AppDatabase _appDb;
  ChatRepository(this._appDb);

  Future<List<ChatMessage>> listAll() async {
    final db = await _appDb.db;
    final rows = await db.query('chat_messages', orderBy: 'timestamp ASC');
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<void> insert(ChatMessage m) async {
    final db = await _appDb.db;
    await db.insert('chat_messages', m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clear() async {
    final db = await _appDb.db;
    await db.delete('chat_messages');
  }
}
