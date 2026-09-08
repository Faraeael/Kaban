enum ChatRole { user, assistant }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory ChatMessage.fromMap(Map<String, Object?> m) => ChatMessage(
        id: m['id'] as String,
        role: ChatRole.values.byName(m['role'] as String),
        content: m['content'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
      );
}
