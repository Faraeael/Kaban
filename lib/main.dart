import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'app.dart';
import 'services/recurring_engine.dart';
import 'services/recurring_notifier.dart';
import 'services/recurring_worker.dart';
import 'state/data_providers.dart';
import 'state/quick_preset_provider.dart';
import 'state/settings_provider.dart';

final _localAuth = LocalAuthentication();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  final container = ProviderContainer();
  await container.read(settingsProvider.notifier).load();

  // Process due recurring transactions (commute, meals, etc.) on launch.
  final settings = container.read(settingsProvider);
  if (settings.autoRecurring) {
    final engine = RecurringEngine(container.read(databaseProvider));
    try {
      final result = await engine.processDue(DateTime.now());
      if (result.created > 0) {
        await RecurringNotifier.requestPermission();
        await RecurringNotifier.notify(result.entryNames);
      }
    } catch (_) {
      // Never block app startup on a scheduler hiccup.
    }
  }

  // Background scheduler: keeps recurring entries flowing even when the
  // app is closed. Best-effort — OS decides the actual cadence.
  try {
    await RecurringWorker.init();
    await RecurringWorker.sync();
  } catch (_) {
    // Workmanager init can fail on emulators without GMS; non-fatal.
  }

  // Initialize Android notification auto-capture listener and sync whitelist
  final notifService = container.read(notificationListenerServiceProvider);
  notifService.initHandler(
    container.read(databaseProvider),
    onTransactionAdded: () {
      container.read(transactionListProvider.notifier).load();
      container.read(walletListProvider.notifier).load();
    },
  );
  if (settings.autoCaptureEnabled) {
    try {
      await notifService.syncWhitelist(settings.autoCapturePackages);
    } catch (_) {}
  }
  try {
    await notifService.setSecure(settings.biometricLock);
  } catch (_) {}

  // Initialize Quick Log presets so Android Home Screen widget is synced on launch
  try {
    container.read(quickPresetProvider);
  } catch (_) {}

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const _LockGate(child: FinanceTrackerApp()),
    ),
  );
}

class _LockGate extends ConsumerStatefulWidget {
  final Widget child;
  const _LockGate({required this.child});

  @override
  ConsumerState<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<_LockGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _authenticating = false;
  bool _wentBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _lockIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wentBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      if (_wentBackground) {
        _unlocked = false;
        _wentBackground = false;
      }
      _lockIfNeeded();
    }
  }

  Future<void> _lockIfNeeded() async {
    final enabled = ref.read(settingsProvider).biometricLock;
    try {
      await ref.read(notificationListenerServiceProvider).setSecure(enabled);
    } catch (_) {}
    if (!enabled || _unlocked || _authenticating) {
      setState(() {});
      return;
    }
    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;
    try {
      final canCheck = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!canCheck) {
        _authenticating = false;
        if (mounted) setState(() {});
        return;
      }
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock Kaban to see your data.',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (mounted) {
        setState(() {
          _unlocked = ok;
          _authenticating = false;
        });
      }
    } catch (_) {
      _authenticating = false;
      if (mounted) setState(() {});
    } finally {
      _authenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(settingsProvider).biometricLock;
    if (!enabled || _unlocked) {
      return widget.child;
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF101614),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.lock_rounded,
                    size: 34, color: Color(0xFF75EEA5)),
              ),
              const SizedBox(height: 18),
              const Text(
                'Kaban is locked',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Authenticate to continue.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              _authenticating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF75EEA5),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _authenticate,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF75EEA5),
                        foregroundColor: const Color(0xFF101614),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 13),
                      ),
                      icon: const Icon(Icons.fingerprint_rounded, size: 20),
                      label: const Text('Unlock'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
