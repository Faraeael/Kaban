enum NotificationParseStatus { parsed, unparsed, ignored }

class NotificationEvent {
  final String id;
  final String packageName;
  final String rawTitle;
  final String rawText;
  final DateTime receivedAt;
  final NotificationParseStatus parseStatus;
  final String? transactionId;

  const NotificationEvent({
    required this.id,
    required this.packageName,
    required this.rawTitle,
    required this.rawText,
    required this.receivedAt,
    required this.parseStatus,
    this.transactionId,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'package_name': packageName,
        'raw_title': rawTitle,
        'raw_text': rawText,
        'received_at': receivedAt.millisecondsSinceEpoch,
        'parse_status': parseStatus.name,
        'transaction_id': transactionId,
      };

  factory NotificationEvent.fromMap(Map<String, Object?> m) =>
      NotificationEvent(
        id: m['id'] as String,
        packageName: m['package_name'] as String,
        rawTitle: m['raw_title'] as String,
        rawText: m['raw_text'] as String,
        receivedAt:
            DateTime.fromMillisecondsSinceEpoch(m['received_at'] as int),
        parseStatus:
            NotificationParseStatus.values.byName(m['parse_status'] as String),
        transactionId: m['transaction_id'] as String?,
      );
}
