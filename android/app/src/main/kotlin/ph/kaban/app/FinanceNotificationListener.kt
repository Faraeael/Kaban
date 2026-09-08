package ph.kaban.app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Receives notifications from whitelisted packages and forwards them
 * to Flutter via the finance_tracker/notifications MethodChannel.
 *
 * Flutter side parses, deduplicates, and writes a Transaction
 * (see lib/services/notification_parser.dart).
 */
class FinanceNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        val n = sbn.notification ?: return
        val title = n.extras?.getString("android.title") ?: ""
        val text = n.extras?.getString("android.text") ?: ""

        val prefs = getSharedPreferences("finance_tracker", MODE_PRIVATE)
        val defaultPackages = setOf(
            "com.globe.gcash.android",
            "com.paymaya",
            "com.bdo.bdopersonal",
            "com.bpi.mobileapp"
        )
        val enabled = prefs.getStringSet("auto_capture_packages", defaultPackages) ?: defaultPackages
        if (pkg !in enabled) return

        val engine = FlutterEngineCache.getInstance().get("finance_tracker_engine")
            ?: return
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "finance_tracker/notifications")
        channel.invokeMethod(
            "onNotification",
            mapOf(
                "packageName" to pkg,
                "title" to title,
                "text" to text,
                "postedAt" to sbn.postTime
            )
        )
    }
}