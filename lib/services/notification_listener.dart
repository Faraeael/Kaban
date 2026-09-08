import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../data/notification_event_repository.dart';
import '../data/transaction_repository.dart';
import '../data/wallet_repository.dart';
import '../models/notification_event.dart';
import '../models/transaction.dart';
import 'notification_parser.dart';
import 'recurring_notifier.dart';

const _uuid = Uuid();

class NotificationListenerService {
  static const _channel = MethodChannel('finance_tracker/notifications');
  static const _prefsKey = 'auto_capture_packages';
  static bool _handlerInitialized = false;

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

  Future<void> syncWhitelist(Set<String> packages) async {
    try {
      await _channel
          .invokeMethod('syncWhitelist', {'packages': packages.toList()});
    } on PlatformException {
      // Non-fatal if platform channel is unavailable (e.g. test environment)
    }
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
  void initHandler(AppDatabase db, {VoidCallback? onTransactionAdded}) {
    if (_handlerInitialized) return;
    _handlerInitialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotification') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        await processNotification(db, data,
            onTransactionAdded: onTransactionAdded);
      }
    });
  }

  Future<Transaction?> processNotification(
    AppDatabase db,
    Map<String, dynamic> data, {
    VoidCallback? onTransactionAdded,
  }) async {
    final pkg = data['packageName'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final text = data['text'] as String? ?? '';
    final postedAtRaw = data['postedAt'] as int?;
    final date = postedAtRaw != null
        ? DateTime.fromMillisecondsSinceEpoch(postedAtRaw)
        : DateTime.now();

    final parsed = _parser.parse(
      packageName: pkg,
      title: title,
      text: text,
    );

    final notifRepo = NotificationEventRepository(db);
    final walletRepo = WalletRepository(db);
    final txnRepo = TransactionRepository(db);

    if (!parsed.success || parsed.amount == null || parsed.type == null) {
      await notifRepo.insert(NotificationEvent(
        id: _uuid.v4(),
        packageName: pkg,
        rawTitle: title,
        rawText: text,
        receivedAt: date,
        parseStatus: NotificationParseStatus.unparsed,
      ));
      return null;
    }

    // Match to a tracked wallet
    var wallet = await walletRepo.findByPackage(pkg);
    if (wallet == null) {
      final allWallets = await walletRepo.listAll(includeArchived: false);
      wallet = allWallets.firstOrNull;
    }

    if (wallet == null) {
      await notifRepo.insert(NotificationEvent(
        id: _uuid.v4(),
        packageName: pkg,
        rawTitle: title,
        rawText: text,
        receivedAt: date,
        parseStatus: NotificationParseStatus.unparsed,
      ));
      return null;
    }

    final txnId = _uuid.v4();
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
      walletId: wallet.id,
      autoCaptured: true,
    );

    await txnRepo.insert(txn);

    await notifRepo.insert(NotificationEvent(
      id: _uuid.v4(),
      packageName: pkg,
      rawTitle: title,
      rawText: text,
      receivedAt: date,
      parseStatus: NotificationParseStatus.parsed,
      transactionId: txnId,
    ));

    try {
      await RecurringNotifier.requestPermission();
      await RecurringNotifier.notify([
        'Auto-captured ₱${parsed.amount!.toStringAsFixed(0)} on ${wallet.name}',
      ]);
    } catch (_) {}

    onTransactionAdded?.call();
    return txn;
  }
}
