package ph.kaban.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import org.json.JSONArray
import java.io.File

/**
 * Android Home Screen Widget that renders bound QR Ph / InstaPay receive QR images
 * with Previous (◀) and Next (▶) navigation buttons to switch wallets directly
 * on the launcher.
 */
class QuickQrWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, id)
            } catch (t: Throwable) {
                android.util.Log.e("QuickQrWidget", "Error updating widget $id", t)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, QuickQrWidgetProvider::class.java)
        )

        when (intent.action) {
            ACTION_REFRESH -> {
                onUpdate(context, manager, ids)
            }
            ACTION_PREV -> {
                val widgetId = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                stepIndex(context, widgetId, -1)
                if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    updateWidget(context, manager, widgetId)
                } else {
                    onUpdate(context, manager, ids)
                }
            }
            ACTION_NEXT -> {
                val widgetId = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                stepIndex(context, widgetId, 1)
                if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    updateWidget(context, manager, widgetId)
                } else {
                    onUpdate(context, manager, ids)
                }
            }
        }
    }

    private fun stepIndex(context: Context, widgetId: Int, delta: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val total = prefs.getInt(KEY_QR_COUNT, 0)
        if (total <= 1) return
        val currentKey = if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            "qr_current_idx_$widgetId"
        } else {
            "qr_current_idx_global"
        }
        val current = prefs.getInt(currentKey, 0)
        val next = (current + delta + total) % total
        prefs.edit().putInt(currentKey, next).apply()
    }

    companion object {
        const val PREFS_NAME = "finance_tracker"
        const val ACTION_REFRESH = "ph.kaban.app.QR_WIDGET_REFRESH"
        const val ACTION_PREV = "ph.kaban.app.QR_WIDGET_PREV"
        const val ACTION_NEXT = "ph.kaban.app.QR_WIDGET_NEXT"
        const val EXTRA_WIDGET_ID = "widget_id"

        const val KEY_QR_DECK = "qr_deck_json"
        const val KEY_QR_COUNT = "qr_deck_count"

        fun updateWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.widget_qr_deck)

            val rawDeck = prefs.getString(KEY_QR_DECK, "[]") ?: "[]"
            val deck = try {
                JSONArray(rawDeck)
            } catch (_: Exception) {
                JSONArray()
            }

            val total = deck.length()
            val currentKey = "qr_current_idx_$widgetId"
            var currentIdx = prefs.getInt(currentKey, prefs.getInt("qr_current_idx_global", 0))
            if (total == 0) {
                currentIdx = 0
            } else {
                currentIdx = ((currentIdx % total) + total) % total
            }

            // Open app Intent on card tap
            val openIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }

            if (openIntent != null) {
                val openPi = PendingIntent.getActivity(
                    context,
                    widgetId * 100,
                    openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.qr_card_container, openPi)
                views.setOnClickPendingIntent(R.id.qr_wallet_name, openPi)
            }

            // Wire Prev button
            val prevIntent = Intent(context, QuickQrWidgetProvider::class.java).apply {
                action = ACTION_PREV
                putExtra(EXTRA_WIDGET_ID, widgetId)
            }
            views.setOnClickPendingIntent(
                R.id.qr_btn_prev,
                PendingIntent.getBroadcast(
                    context,
                    widgetId * 100 + 1,
                    prevIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )

            // Wire Next button
            val nextIntent = Intent(context, QuickQrWidgetProvider::class.java).apply {
                action = ACTION_NEXT
                putExtra(EXTRA_WIDGET_ID, widgetId)
            }
            views.setOnClickPendingIntent(
                R.id.qr_btn_next,
                PendingIntent.getBroadcast(
                    context,
                    widgetId * 100 + 2,
                    nextIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )

            if (total == 0) {
                views.setTextViewText(R.id.qr_wallet_name, "Receive QR")
                views.setTextViewText(R.id.qr_counter, "0/0")
                views.setTextViewText(R.id.qr_account_details, "Attach QR screenshot in Kaban")
                views.setImageViewResource(R.id.qr_image_view, android.R.drawable.ic_menu_gallery)
            } else {
                val item = deck.optJSONObject(currentIdx)
                val name = item?.optString("name", "Receive QR") ?: "Receive QR"
                val acct = item?.optString("details", "") ?: ""
                val imagePath = item?.optString("qrImagePath", "") ?: ""

                views.setTextViewText(R.id.qr_wallet_name, name)
                views.setTextViewText(R.id.qr_counter, "${currentIdx + 1}/$total")
                views.setTextViewText(
                    R.id.qr_account_details,
                    if (acct.isNotEmpty()) acct else "InstaPay / QR Ph"
                )

                var bitmapSet = false
                if (imagePath.isNotEmpty()) {
                    val file = File(imagePath)
                    if (file.exists()) {
                        try {
                            val bitmap = BitmapFactory.decodeFile(file.absolutePath)
                            if (bitmap != null) {
                                views.setImageViewBitmap(R.id.qr_image_view, bitmap)
                                bitmapSet = true
                            }
                        } catch (t: Throwable) {
                            android.util.Log.w("QuickQrWidget", "Failed decoding QR bitmap: ${t.message}")
                        }
                    }
                }
                if (!bitmapSet) {
                    views.setImageViewResource(R.id.qr_image_view, android.R.drawable.ic_menu_gallery)
                }
            }

            manager.updateAppWidget(widgetId, views)
        }
    }
}
