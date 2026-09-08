package ph.kaban.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home Screen AppWidget that shows up to 4 Quick Log presets.
 *
 * Presets are stored in SharedPreferences by the Flutter side via
 * the "finance_tracker/quick_log" MethodChannel (syncPresets call).
 * The widget reads the prefs directly so it works without a live
 * Flutter engine.
 */
class QuickFareWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, id)
            } catch (t: Throwable) {
                android.util.Log.e("QuickFareWidget", "Error updating widget $id", t)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Refresh all widget instances when presets change.
        if (intent.action == ACTION_REFRESH) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, QuickFareWidgetProvider::class.java)
            )
            onUpdate(context, manager, ids)
        }
    }

    companion object {
        const val ACTION_REFRESH = "ph.kaban.app.WIDGET_REFRESH"

        // Default presets displayed if app hasn't synced custom presets yet
        private val DEFAULT_PRESETS = arrayOf(
            Triple("Jeepney", 13f, "🚐"),
            Triple("Tricycle", 25f, "🛺"),
            Triple("Lunch", 150f, "🍱"),
            Triple("Coffee", 120f, "☕")
        )

        fun updateWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int
        ) {
            val prefs = context.getSharedPreferences("finance_tracker", Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.widget_quick_fare)

            // Open app Intent
            val openIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }

            // Read up to 4 presets stored as "preset_0" … "preset_3"
            val buttonIds = intArrayOf(
                R.id.btn_preset_0,
                R.id.btn_preset_1,
                R.id.btn_preset_2,
                R.id.btn_preset_3
            )

            for (i in 0..3) {
                var label = prefs.getString("preset_${i}_label", null)
                var amount = prefs.getFloat("preset_${i}_amount", -1f)
                var icon = prefs.getString("preset_${i}_icon", null)
                val category = prefs.getString("preset_${i}_category", "Other") ?: "Other"
                val walletId = prefs.getString("preset_${i}_walletId", null) ?: ""

                // Fall back to built-in presets on clean install before first Flutter sync
                if (label == null && i < DEFAULT_PRESETS.size) {
                    label = DEFAULT_PRESETS[i].first
                    amount = DEFAULT_PRESETS[i].second
                    icon = DEFAULT_PRESETS[i].third
                }

                if (!label.isNullOrBlank() && amount >= 0) {
                    val iconStr = if (!icon.isNullOrBlank()) icon else "💸"
                    val amtFormatted = if (amount % 1f == 0f) "₱${amount.toInt()}" else "₱%.2f".format(amount)
                    views.setTextViewText(buttonIds[i], "$iconStr $label\n$amtFormatted")
                    views.setOnClickPendingIntent(
                        buttonIds[i],
                        buildLogIntent(context, widgetId, i, label, amount, category, walletId, iconStr)
                    )
                } else {
                    views.setTextViewText(buttonIds[i], "—")
                    if (openIntent != null) {
                        views.setOnClickPendingIntent(
                            buttonIds[i],
                            PendingIntent.getActivity(
                                context,
                                widgetId * 10 + i + 100,
                                openIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                        )
                    }
                }
            }

            // Open app on header tap
            if (openIntent != null) {
                views.setOnClickPendingIntent(
                    R.id.widget_header,
                    PendingIntent.getActivity(
                        context, 0, openIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )
            }

            manager.updateAppWidget(widgetId, views)
        }

        private fun buildLogIntent(
            context: Context,
            widgetId: Int,
            index: Int,
            label: String,
            amount: Float,
            category: String,
            walletId: String,
            icon: String
        ): PendingIntent {
            val intent = Intent(context, QuickLogReceiver::class.java).apply {
                action = QuickLogReceiver.ACTION_QUICK_LOG
                putExtra(QuickLogReceiver.EXTRA_LABEL, label)
                putExtra(QuickLogReceiver.EXTRA_AMOUNT, amount)
                putExtra(QuickLogReceiver.EXTRA_CATEGORY, category)
                putExtra(QuickLogReceiver.EXTRA_WALLET_ID, walletId)
                putExtra(QuickLogReceiver.EXTRA_ICON, icon)
                // Unique request code per widget instance + slot
                putExtra("widget_id", widgetId)
                putExtra("slot", index)
            }
            return PendingIntent.getBroadcast(
                context,
                widgetId * 10 + index,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
