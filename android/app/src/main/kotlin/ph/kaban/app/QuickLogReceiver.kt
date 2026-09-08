package ph.kaban.app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.widget.RemoteViews
import android.widget.Toast
import java.util.UUID

/**
 * BroadcastReceiver that handles one-tap Quick Log actions from the
 * Home Screen widget.
 *
 * It writes the transaction directly to the SQLite database (same DB
 * that sqflite uses at the default Flutter path) so the record appears
 * in-app next time the user opens Kaban, without needing a live
 * Flutter engine.
 *
 * Provides instant feedback:
 * 1. Tactile haptic pulse (vibration)
 * 2. Visual widget state: tapped chip glows emerald green with "✓ Logged!",
 *    and widget title updates to "✓ Added <label> (<amount>)"
 * 3. Smooth auto-revert back to idle state after 1.5 seconds
 */
class QuickLogReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_QUICK_LOG) return

        val label = intent.getStringExtra(EXTRA_LABEL) ?: return
        val amount = intent.getFloatExtra(EXTRA_AMOUNT, -1f)
        if (amount < 0) return
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: "Other"
        val walletId = intent.getStringExtra(EXTRA_WALLET_ID).takeUnless { it.isNullOrBlank() }
        val icon = intent.getStringExtra(EXTRA_ICON) ?: "💸"
        val widgetId = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val slot = intent.getIntExtra(EXTRA_SLOT, -1)

        val pendingResult = goAsync()

        Thread {
            try {
                val saved = writeTransaction(context, label, amount, category, walletId, icon)
                Handler(Looper.getMainLooper()).post {
                    if (saved) {
                        triggerHaptic(context)
                        showFeedback(context, widgetId, slot, label, amount, icon, pendingResult)
                    } else {
                        pendingResult.finish()
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("QuickLogReceiver", "Error processing quick log: ${e.message}", e)
                try { pendingResult.finish() } catch (_: Exception) {}
            }
        }.start()
    }

    private fun triggerHaptic(context: Context) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                val vibrator = vibratorManager?.defaultVibrator
                vibrator?.vibrate(VibrationEffect.createOneShot(45, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(VibrationEffect.createOneShot(45, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(45)
                }
            }
        } catch (e: Exception) {
            android.util.Log.w("QuickLogReceiver", "Haptic pulse unavailable: ${e.message}")
        }
    }

    private fun showFeedback(
        context: Context,
        widgetId: Int,
        slot: Int,
        label: String,
        amount: Float,
        icon: String,
        pendingResult: PendingResult
    ) {
        try {
            val manager = AppWidgetManager.getInstance(context)
            val widgetIds = if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                intArrayOf(widgetId)
            } else {
                manager.getAppWidgetIds(ComponentName(context, QuickFareWidgetProvider::class.java))
            }

            val buttonIds = intArrayOf(
                R.id.btn_preset_0,
                R.id.btn_preset_1,
                R.id.btn_preset_2,
                R.id.btn_preset_3
            )

            val amtStr = if (amount % 1f == 0f) "₱${amount.toInt()}" else "₱%.2f".format(amount)

            // 1. Instant visual feedback on the widget
            val feedbackViews = RemoteViews(context.packageName, R.layout.widget_quick_fare)
            feedbackViews.setTextViewText(R.id.widget_title, "✓ Added $label ($amtStr)")
            feedbackViews.setTextColor(R.id.widget_title, 0xFF4ADE80.toInt())

            if (slot in 0..3) {
                feedbackViews.setTextViewText(buttonIds[slot], "✓ Logged!\n$amtStr")
                feedbackViews.setInt(buttonIds[slot], "setBackgroundResource", R.drawable.widget_chip_logged_bg)
            }

            for (id in widgetIds) {
                manager.partiallyUpdateAppWidget(id, feedbackViews)
            }

            // 2. Toast fallback (for OSes that display background toasts)
            try {
                Toast.makeText(context, "$icon $label $amtStr logged ✓", Toast.LENGTH_SHORT).show()
            } catch (_: Exception) {}

            // 3. Smooth auto-revert back after 1.5 seconds
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    for (id in widgetIds) {
                        QuickFareWidgetProvider.updateWidget(context, manager, id)
                    }
                } catch (e: Exception) {
                    android.util.Log.e("QuickLogReceiver", "Error resetting widget: ${e.message}", e)
                } finally {
                    try { pendingResult.finish() } catch (_: Exception) {}
                }
            }, 1500L)
        } catch (e: Exception) {
            android.util.Log.e("QuickLogReceiver", "Error showing feedback: ${e.message}", e)
            try { pendingResult.finish() } catch (_: Exception) {}
        }
    }

    companion object {
        const val ACTION_QUICK_LOG = "ph.kaban.app.QUICK_LOG"
        const val EXTRA_LABEL = "label"
        const val EXTRA_AMOUNT = "amount"
        const val EXTRA_CATEGORY = "category"
        const val EXTRA_WALLET_ID = "walletId"
        const val EXTRA_ICON = "icon"
        const val EXTRA_WIDGET_ID = "widget_id"
        const val EXTRA_SLOT = "slot"

        /**
         * Writes an expense transaction row to the sqflite SQLite database.
         * The DB is located at the standard Flutter/sqflite path.
         * Returns true on success.
         */
        private fun writeTransaction(
            context: Context,
            label: String,
            amount: Float,
            category: String,
            walletIdHint: String?,
            icon: String
        ): Boolean {
            return try {
                val dbPath = findDatabasePath(context) ?: return false
                val db = SQLiteDatabase.openDatabase(
                    dbPath,
                    null,
                    SQLiteDatabase.OPEN_READWRITE
                )

                // Resolve wallet: use hint or fall back to first non-archived wallet.
                val walletId = resolveWalletId(db, walletIdHint)
                    ?: run { db.close(); return false }

                val txnId = UUID.randomUUID().toString()
                val now = System.currentTimeMillis()

                val cv = ContentValues().apply {
                    put("id", txnId)
                    put("amount", amount.toDouble())
                    put("type", "expense")
                    put("category", category)
                    put("note", "$icon $label")
                    put("date", now)
                    put("wallet_id", walletId)
                    put("auto_captured", 0)
                }
                db.insertOrThrow("transactions", null, cv)
                db.close()
                true
            } catch (e: Exception) {
                android.util.Log.e("QuickLogReceiver", "Failed to write quick log: ${e.message}", e)
                false
            }
        }

        private fun findDatabasePath(context: Context): String? {
            val candidates = listOf(
                java.io.File(context.filesDir.parentFile, "app_flutter/finance_tracker.db"),
                java.io.File(context.filesDir, "finance_tracker.db"),
                context.getDatabasePath("finance_tracker.db"),
                context.getDatabasePath("kaban.db")
            )
            for (candidate in candidates) {
                if (candidate.exists()) {
                    return candidate.absolutePath
                }
            }
            return candidates.first().absolutePath
        }

        private fun resolveWalletId(db: SQLiteDatabase, hint: String?): String? {
            if (!hint.isNullOrBlank()) {
                db.rawQuery(
                    "SELECT id FROM wallets WHERE id=? AND archived=0 LIMIT 1",
                    arrayOf(hint)
                ).use { c ->
                    if (c.moveToFirst()) return c.getString(0)
                }
            }
            db.rawQuery(
                "SELECT id FROM wallets WHERE archived=0 ORDER BY rowid LIMIT 1",
                null
            ).use { c ->
                if (c.moveToFirst()) return c.getString(0)
            }
            return null
        }
    }
}
