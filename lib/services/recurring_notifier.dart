import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifies the user when recurring transactions are auto-logged.
///
/// Safe to call from both the main isolate and the WorkManager background
/// isolate — each isolate initializes its own plugin instance.
class RecurringNotifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    _ready = true;
  }

  /// Requests Android 13+ notification permission (no-op elsewhere).
  static Future<void> requestPermission() async {
    await init();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> notify(List<String> labels) async {
    await init();
    if (labels.isEmpty) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'recurring',
        'Recurring entries',
        channelDescription:
            'Notifications when recurring transactions are auto-logged',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    final body = labels.length == 1
        ? '${labels.first} was logged.'
        : '${labels.length} recurring entries were logged: '
            '${labels.take(3).join(', ')}${labels.length > 3 ? '…' : ''}';
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Kaban',
      body,
      details,
    );
  }
}
