package ph.kaban.app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
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

        val saved = writeTransaction(context, label, amount, category, walletId, icon)

        if (saved) {
            Toast.makeText(
                context,
                "$icon $label ₱${amount.toInt()} logged ✓",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    companion object {
        const val ACTION_QUICK_LOG = "ph.kaban.app.QUICK_LOG"
        const val EXTRA_LABEL = "label"
        const val EXTRA_AMOUNT = "amount"
        const val EXTRA_CATEGORY = "category"
        const val EXTRA_WALLET_ID = "walletId"
        const val EXTRA_ICON = "icon"

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
