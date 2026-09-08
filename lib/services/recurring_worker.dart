import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/database.dart';
import 'recurring_engine.dart';
import 'recurring_notifier.dart';

/// Background dispatcher for recurring transaction processing.
///
/// Registered as a WorkManager periodic task (Android) / BGTaskScheduler
/// (iOS). Runs the RecurringEngine outside the UI isolate.
class RecurringWorker {
  static const taskName = 'finance_tracker_recurring';
  static const _prefsKey = 'app_settings_v1';

  static Future<void> init() async {
    await Workmanager().initialize(_callbackDispatcher);
  }

  static Future<void> schedule() async {
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(hours: 12),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(taskName);
  }

  static Future<void> sync() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final auto = raw == null || !raw.contains('"autoRecurring":false');
    if (auto) {
      await schedule();
    } else {
      await cancel();
    }
  }
}

@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != RecurringWorker.taskName) return true;

    // Read the toggle directly from prefs — no Riverpod container here.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(RecurringWorker._prefsKey);
    final disabled = raw != null && raw.contains('"autoRecurring":false');
    if (disabled) return true;

    final engine = RecurringEngine(AppDatabase.instance);
    try {
      final result = await engine.processDue(DateTime.now());
      if (result.created > 0) {
        await RecurringNotifier.notify(result.entryNames);
      }
    } catch (_) {
      // Background work must never crash the OS scheduler loop.
    }
    return true;
  });
}
