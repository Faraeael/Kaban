package ph.kaban.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val notifChannelName = "finance_tracker/notifications"
    private val quickLogChannelName = "finance_tracker/quick_log"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put("finance_tracker_engine", flutterEngine)

        // ── Notification listener channel ──────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notifChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> result.success(isNotificationListenerEnabled())
                    "requestPermission" -> {
                        val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    }
                    "syncWhitelist" -> {
                        val list = call.argument<List<String>>("packages") ?: emptyList()
                        val prefs = getSharedPreferences("finance_tracker", MODE_PRIVATE)
                        prefs.edit().putStringSet("auto_capture_packages", list.toSet()).apply()
                        result.success(true)
                    }
                    "setSecure" -> {
                        val secure = call.argument<Boolean>("secure") ?: false
                        if (secure) {
                            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Quick Log widget channel ───────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, quickLogChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncPresets" -> {
                        val presets = call.argument<List<Map<String, Any>>>("presets")
                            ?: emptyList()
                        val prefs = getSharedPreferences("finance_tracker", MODE_PRIVATE)
                        val editor = prefs.edit()
                        for (i in 0..3) {
                            if (i < presets.size) {
                                val p = presets[i]
                                editor.putString("preset_${i}_label", p["label"] as? String ?: "")
                                editor.putFloat(
                                    "preset_${i}_amount",
                                    (p["amount"] as? Number)?.toFloat() ?: 0f
                                )
                                editor.putString("preset_${i}_icon", p["icon"] as? String ?: "💸")
                                editor.putString("preset_${i}_category", p["category"] as? String ?: "Other")
                                editor.putString("preset_${i}_walletId", p["walletId"] as? String ?: "")
                            } else {
                                // Clear unused slots
                                editor.remove("preset_${i}_label")
                                editor.remove("preset_${i}_amount")
                                editor.remove("preset_${i}_icon")
                                editor.remove("preset_${i}_category")
                                editor.remove("preset_${i}_walletId")
                            }
                        }
                        editor.apply()
                        // Tell the widget to refresh its views
                        val refreshIntent = Intent(QuickFareWidgetProvider.ACTION_REFRESH)
                        refreshIntent.setClass(this, QuickFareWidgetProvider::class.java)
                        sendBroadcast(refreshIntent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val pkg = packageName
        val flat = android.provider.Settings.Secure.getString(
            contentResolver, "enabled_notification_listeners"
        )
        return flat != null && flat.contains(pkg)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
}