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
        if (!prefs.getBoolean("auto_capture_enabled", false)) return
        val defaultPackages = setOf(
            "com.globe.gcash.android",
            "com.paymaya",
            "com.bdo.bdopersonal",
            "com.bpi.mobileapp"
        )
        val enabled = prefs.getStringSet("auto_capture_packages", defaultPackages) ?: defaultPackages
        if (pkg !in enabled) return

        val key = "${sbn.key ?: "${pkg}_${sbn.id}"}_${sbn.postTime}"
        val payload = mapOf(
            "key" to key,
            "packageName" to pkg,
            "title" to title,
            "text" to text,
            "postedAt" to sbn.postTime
        )

        enqueuePending(this, key, pkg, title, text, sbn.postTime)

        val engine = FlutterEngineCache.getInstance().get("finance_tracker_engine")
        if (engine != null) {
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "finance_tracker/notifications")
            channel.invokeMethod("onNotification", payload)
        }
    }

    companion object {
        private val queueLock = Any()

        fun enqueuePending(
            context: android.content.Context,
            key: String,
            pkg: String,
            title: String,
            text: String,
            postedAt: Long
        ) {
            synchronized(queueLock) {
                try {
                    val prefs = context.getSharedPreferences("finance_tracker", MODE_PRIVATE)
                    val raw = prefs.getString("pending_notifications_v1", "[]") ?: "[]"
                    val arr = org.json.JSONArray(raw)
                    for (i in 0 until arr.length()) {
                        val existing = arr.optJSONObject(i) ?: continue
                        if (existing.optString("key") == key &&
                            existing.optLong("postedAt") == postedAt &&
                            existing.optString("text") == text
                        ) {
                            return
                        }
                    }
                    val trimmed = org.json.JSONArray()
                    val start = (arr.length() - 199).coerceAtLeast(0)
                    for (i in start until arr.length()) {
                        trimmed.put(arr.get(i))
                    }
                    trimmed.put(
                        org.json.JSONObject().apply {
                            put("key", key)
                            put("packageName", pkg)
                            put("title", title)
                            put("text", text)
                            put("postedAt", postedAt)
                        }
                    )
                    prefs.edit().putString("pending_notifications_v1", trimmed.toString()).commit()
                } catch (_: Exception) {}
            }
        }

        fun peekPending(context: android.content.Context): List<Map<String, Any>> {
            synchronized(queueLock) {
                val prefs = context.getSharedPreferences("finance_tracker", MODE_PRIVATE)
                val raw = prefs.getString("pending_notifications_v1", null) ?: return emptyList()
                val list = mutableListOf<Map<String, Any>>()
                try {
                    val arr = org.json.JSONArray(raw)
                    for (i in 0 until arr.length()) {
                        val obj = arr.optJSONObject(i) ?: continue
                        list.add(
                            mapOf(
                                "key" to obj.optString("key", ""),
                                "packageName" to obj.optString("packageName", ""),
                                "title" to obj.optString("title", ""),
                                "text" to obj.optString("text", ""),
                                "postedAt" to obj.optLong("postedAt", 0L)
                            )
                        )
                    }
                } catch (_: Exception) {}
                return list
            }
        }

        fun ackPending(context: android.content.Context, keysToRemove: Set<String>) {
            if (keysToRemove.isEmpty()) return
            synchronized(queueLock) {
                try {
                    val prefs = context.getSharedPreferences("finance_tracker", MODE_PRIVATE)
                    val raw = prefs.getString("pending_notifications_v1", null) ?: return
                    val arr = org.json.JSONArray(raw)
                    val remaining = org.json.JSONArray()
                    for (i in 0 until arr.length()) {
                        val obj = arr.optJSONObject(i) ?: continue
                        if (obj.optString("key", "") !in keysToRemove) {
                            remaining.put(obj)
                        }
                    }
                    prefs.edit().putString("pending_notifications_v1", remaining.toString()).commit()
                } catch (_: Exception) {}
            }
        }
    }
}