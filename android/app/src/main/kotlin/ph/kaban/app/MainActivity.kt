package ph.kaban.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "finance_tracker/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put("finance_tracker_engine", flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> result.success(isNotificationListenerEnabled())
                "requestPermission" -> {
                    val intent = android.content.Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                    intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
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
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val pkg = packageName
        val flat = android.provider.Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(pkg)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
}