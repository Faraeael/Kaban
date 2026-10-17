import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../models/notification_event.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import 'notification_parser.dart';
import 'recurring_notifier.dart';

const _uuid = Uuid();

class NotificationListenerService {
  static const _channel = MethodChannel('finance_tracker/notifications');
  static const _prefsKey = 'auto_capture_packages';
  static bool _handlerInitialized = false;
  static Future<void> _processingChain = Future.value();
  static VoidCallback? _onTransactionAdded;
  static bool Function()? _isEnabled;
  final NotificationParser _parser = NotificationParser();

  Future<bool> isPermissionGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPermissionGranted');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } on PlatformException {
      // User will need to enable manually in Settings
    }
  }

  Future<void> syncWhitelist(Set<String> packages, {bool? enabled}) async {
    try {
      await _channel.invokeMethod('syncWhitelist', {
        'packages': packages.toList(),
        if (enabled != null) 'enabled': enabled,
      });
    } on PlatformException {
      // Non-fatal if platform channel is unavailable (e.g. test environment)
    } on MissingPluginException {
      // Non-fatal in unit tests without platform channel handler
    }
  }

  Future<List<Map<String, dynamic>>> peekPendingNotifications() async {
    try {
      final raw = await _channel
          .invokeMethod<List<dynamic>>('peekPendingNotifications');
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<void> ackPendingNotifications(List<String> keys) async {
    if (keys.isEmpty) return;
    try {
      await _channel.invokeMethod('ackPendingNotifications', {'keys': keys});
    } on PlatformException {
      // Non-fatal
    } on MissingPluginException {
      // Non-fatal
    }
  }

  Future<int> flushPendingNotifications(
    AppDatabase db, {
    VoidCallback? onTransactionAdded,
    bool Function()? isEnabled,
  }) async {
    final checkEnabled = isEnabled ?? _isEnabled;
    if (checkEnabled != null && !checkEnabled()) return 0;
    final pending = await peekPendingNotifications();
    var added = 0;
    for (final item in pending) {
      final txn = await processNotification(
        db,
        item,
        onTransactionAdded: onTransactionAdded ?? _onTransactionAdded,
        isEnabled: checkEnabled,
      );
      if (txn != null) added++;
    }
    return added;
  }

  Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod('setSecure', {'secure': secure});
    } on PlatformException {
      // Non-fatal if platform channel is unavailable
    }
  }

  Future<Set<String>> loadEnabledPackages() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey);
    if (stored == null) {
      return {
        'com.globe.gcash.android',
        'com.paymaya',
        'com.bdo.bdopersonal',
        'com.bpi.mobileapp',
      };
    }
    return stored.toSet();
  }

  Future<void> saveEnabledPackages(Set<String> packages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, packages.toList());
    await syncWhitelist(packages);
  }

  /// Sets up the MethodChannel listener to capture notifications from Kotlin.
  void initHandler(
    AppDatabase db, {
    VoidCallback? onTransactionAdded,
    bool Function()? isEnabled,
  }) {
    _onTransactionAdded = onTransactionAdded;
    _isEnabled = isEnabled;
    if (_handlerInitialized) return;
    _handlerInitialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotification') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        await processNotification(
          db,
          data,
          onTransactionAdded: _onTransactionAdded,
          isEnabled: _isEnabled,
        );
      }
    });
  }

  static String computeEventId({
    String? key,
    required String packageName,
    required int postedAtMs,
    required String title,
    required String text,
  }) {
    return _uuid.v5(
      Namespace.url.value,
      'kaban:notif:${key ?? ''}|$packageName|$postedAtMs|$title|$text',
    );
  }

  Future<Transaction?> processNotification(
    AppDatabase db,
    Map<String, dynamic> data, {
    VoidCallback? onTransactionAdded,
    bool Function()? isEnabled,
  }) {
    final run = _processingChain.then(
      (_) => _processNotificationInternal(
        db,
        data,
        onTransactionAdded: onTransactionAdded,
        isEnabled: isEnabled,
      ),
    );
    _processingChain = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<Transaction?> _processNotificationInternal(
    AppDatabase db,
    Map<String, dynamic> data, {
    VoidCallback? onTransactionAdded,
    bool Function()? isEnabled,
  }) async {
    final checkEnabled = isEnabled ?? _isEnabled;
    if (checkEnabled != null && !checkEnabled()) {
      return null;
    }

    final key = (data['key'] as String?)?.trim();
    final pkg = data['packageName'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final text = data['text'] as String? ?? '';
    final postedAtRaw = (data['postedAt'] as num?)?.toInt();
    final date = postedAtRaw != null && postedAtRaw > 0
        ? DateTime.fromMillisecondsSinceEpoch(postedAtRaw)
        : DateTime.now();

    final eventId = computeEventId(
      key: key,
      packageName: pkg,
      postedAtMs: postedAtRaw ?? date.millisecondsSinceEpoch,
      title: title,
      text: text,
    );
    final txnId = _uuid.v5(Namespace.url.value, 'kaban:notif_txn:$eventId');

    final parsed = _parser.parse(
      packageName: pkg,
      title: title,
      text: text,
    );

    final database = await db.db;
    Wallet? matchedWallet;
    Transaction? createdTxn;
    var committed = false;

    await database.transaction((dbTxn) async {
      final existing = await dbTxn.query(
        'notification_events',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [eventId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        committed = true;
        return;
      }
      if (postedAtRaw == null && (key == null || key.isEmpty)) {
        final recentDup = await dbTxn.query(
          'notification_events',
          columns: ['id'],
          where:
              'package_name = ? AND raw_title = ? AND raw_text = ? AND ABS(received_at - ?) <= 2000',
          whereArgs: [pkg, title, text, date.millisecondsSinceEpoch],
          limit: 1,
        );
        if (recentDup.isNotEmpty) {
          committed = true;
          return;
        }
      }

      if (!parsed.success || parsed.amount == null || parsed.type == null) {
        await dbTxn.insert(
          'notification_events',
          NotificationEvent(
            id: eventId,
            packageName: pkg,
            rawTitle: title,
            rawText: text,
            receivedAt: date,
            parseStatus: NotificationParseStatus.unparsed,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        committed = true;
        return;
      }

      // Match strictly to a tracked non-archived wallet for this package.
      final walletRows = await dbTxn.query(
        'wallets',
        where: 'archived = 0',
        limit: 1000,
      );
      for (final row in walletRows) {
        final candidate = Wallet.fromMap(row);
        final preset = kWalletPresets.firstWhere(
          (p) =>
              p.name.toLowerCase() == candidate.name.toLowerCase() ||
              (p.logoAsset.isNotEmpty && p.logoAsset == candidate.logoAsset),
          orElse: () => const WalletPreset(
            name: '',
            type: WalletType.cash,
            colorValue: 0,
            logoAsset: '',
          ),
        );
        if (preset.notificationPackage == pkg) {
          matchedWallet = candidate;
          break;
        }
      }

      if (matchedWallet == null) {
        await dbTxn.insert(
          'notification_events',
          NotificationEvent(
            id: eventId,
            packageName: pkg,
            rawTitle: title,
            rawText: text,
            receivedAt: date,
            parseStatus: NotificationParseStatus.unparsed,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        committed = true;
        return;
      }

      final note = parsed.merchant != null && parsed.merchant!.isNotEmpty
          ? 'Auto-captured from ${parsed.merchant}'
          : 'Auto-captured';

      final txn = Transaction(
        id: txnId,
        amount: parsed.amount!,
        type: parsed.type!,
        category: parsed.category ??
            (parsed.type == TransactionType.income ? 'Other' : 'Food'),
        note: note,
        date: date,
        walletId: matchedWallet!.id,
        autoCaptured: true,
      );

      final insertedRow = await dbTxn.insert(
        'transactions',
        txn.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await dbTxn.insert(
        'notification_events',
        NotificationEvent(
          id: eventId,
          packageName: pkg,
          rawTitle: title,
          rawText: text,
          receivedAt: date,
          parseStatus: NotificationParseStatus.parsed,
          transactionId: txnId,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      committed = true;
      if (insertedRow > 0) {
        createdTxn = txn;
      }
    });

    if (committed && key != null && key.isNotEmpty) {
      await ackPendingNotifications([key]);
    }

    if (createdTxn != null && matchedWallet != null) {
      try {
        await RecurringNotifier.requestPermission();
        await RecurringNotifier.notify([
          'Auto-captured ₱${parsed.amount!.toStringAsFixed(0)} on ${matchedWallet!.name}',
        ]);
      } catch (_) {}
      onTransactionAdded?.call();
    }
    return createdTxn;
  }
}
