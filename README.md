# Kaban

A quiet, privacy-first personal finance and debt tracker for Philippine wallets (BDO, Maya, GCash, GoTyme, BPI, cash, credit cards), with a built-in AI coach and Android notification auto-capture. Inspired by the Pikash app's feature set.

## Features

- **Multi-wallet tracking** — banks, e-wallets, credit cards, cash. Each with its own logo and color tag.
- **Transfers between wallets** — one action, no double-counting.
- **Android notification auto-capture** — GCash, Maya, BDO, BPI transactions logged automatically.
- **Subscription tracking** — Netflix, Spotify, postpaid plans, etc., with auto-detection.
- **Real debt payoff math** — avalanche (highest APR first) and snowball (smallest balance first) with projected payoff dates and total interest.
- **Savings goals** with deadlines.
- **Monthly budgets** per category with overspend alerts.
- **AI Coach** — local rule-based engine (works offline) plus optional remote coach via CommandCode, OpenCode, or OpenRouter.
- **100% on-device** — all data stored in SQLite. No accounts, no cloud.

## Quick start

### Prerequisites

- Flutter SDK 3.22+ (`flutter doctor` to verify)
- Android Studio (for Android) or Xcode (for iOS)
- For Android auto-capture: a physical Android device or emulator running API 24+

### Install

```bash
cd finance_tracker
flutter pub get
flutter run
```

For Android auto-capture support, you also need the Android Kotlin files in place. If you're starting from scratch:

```bash
flutter create --org com.example --project-name finance_tracker .
flutter pub get
```

Then copy the `android/app/src/main/AndroidManifest.xml`, `MainActivity.kt`, and `FinanceNotificationListener.kt` from this repo into your generated project.

### Enable notification auto-capture (Android only)

1. Open the app, go to **Settings → Auto-capture**.
2. Toggle "Enable notification capture" on.
3. Tap "Enable" — Android will open **Settings → Notification access**.
4. Find "Kaban" in the list and toggle it on.
5. Go back to the app. The next time you pay with GCash, Maya, or a whitelisted bank, the transaction will be logged automatically.

The default whitelist:
- `com.globe.gcash.android` (GCash)
- `com.paymaya` (Maya)
- `com.bdo.bdopersonal` (BDO Personal)
- `com.bpi.mobileapp` (BPI)

Add or remove packages in **Settings → Auto-capture → Whitelisted packages**. Need the exact package name? Install a free "Package Name Viewer" from the Play Store.

### Configure the AI coach

The AI Coach works offline by default with on-device rules. To get richer, conversational answers, choose one of three remote providers:

#### CommandCode

1. Sign in at your CommandCode dashboard and copy your API key.
2. In the app: **Settings → AI Coach → Provider → CommandCode**.
3. Toggle "Allow remote AI" on.
4. Paste your API key.
5. The base URL and model are pre-configured; override if needed.

#### OpenCode

Same flow as CommandCode. Paste your OpenCode API key in **Settings**.

#### OpenRouter

1. Sign up at [openrouter.ai](https://openrouter.ai) and copy your API key.
2. In the app: **Settings → AI Coach → Provider → OpenRouter**.
3. Toggle "Allow remote AI" on.
4. Paste your key.

**Privacy note:** When remote AI is enabled, the app sends only an anonymized snapshot — totals per wallet and category, debt list, no merchant names, no personal notes. Balance anonymization (rounding to ₱100) is on by default; toggle off in Settings if you want exact amounts sent.

## Verification

After installing:

1. **Add a wallet.** Wallets screen → "Add wallet" → tap BDO → set starting balance ₱5000.
2. **Log a transaction.** Activity tab → "+" → "₱200 Food from BDO". Dashboard updates instantly.
3. **Try a transfer.** Activity tab → top-right swap icon → "From BDO, To Maya, ₱1000". Both balances adjust; net worth unchanged.
4. **Add a debt.** Debts tab → "Add debt" → "BDO Credit Card, ₱5000, 24% APR, ₱250 min". Switch between Avalanche and Snowball in the menu — verify math changes.
5. **Test the coach.** Coach tab → tap "What should I pay first?" → verify it references your actual highest-APR debt.
6. **Test auto-capture (Android).** Enable notification access as described above. Open GCash and send yourself ₱1. Check the Activity tab.

## Architecture

```
lib/
├── main.dart                     Entry point
├── app.dart                      MaterialApp + router
├── theme/app_theme.dart          Material 3 light/dark themes
├── router/app_router.dart        go_router config (7 routes)
├── models/                       Wallet, Transaction, Debt, Goal, Budget, Subscription, ChatMessage, NotificationEvent, AppSettings
├── data/                         AppDatabase + repositories (sqflite)
├── state/                        Riverpod providers + settings persistence
├── services/                     PayoffCalculator, BalanceRecalculator, NotificationParser, SpendingAnalyzer, SubscriptionDetector, AI (LocalCoach, RemoteCoach, AIProviderConfig)
├── screens/                      Dashboard, Wallets, Transactions, Debts, Subscriptions, Goals, Coach, Settings
└── utils/formatters.dart         Currency + date helpers

assets/logos/                     SVG logos for PH banks, e-wallets, cash, credit cards

android/app/src/main/
├── AndroidManifest.xml           Notification listener service declaration
└── kotlin/com/example/finance_tracker/
    ├── MainActivity.kt           Method channel + permission check
    └── FinanceNotificationListener.kt   NotificationListenerService → Flutter

test/                             Unit tests for payoff math and notification parser
```

## Database schema (SQLite, version 3)

- `wallets` — id, name, type, starting_balance, currency, color_value, archived, logo_asset
- `transactions` — id, amount, type, category, note, date, wallet_id, transfer_pair_id, auto_captured
- `debts` — id, name, balance, apr, min_payment, strategy, linked_wallet_id
- `goals` — id, name, target, saved, deadline
- `budgets` — id, category, monthly_limit
- `subscriptions` — id, name, amount, cadence, next_billing_date, category, wallet_id
- `notification_events` — id, package_name, raw_title, raw_text, received_at, parse_status, transaction_id
- `chat_messages` — id, role, content, timestamp

## Running tests

```bash
flutter test
```

Tests cover the debt payoff simulator (avalanche/snowball ordering, extra payment impact) and the notification parser (GCash send, balance-ignore heuristics).

## Known limitations (v1)

- Bank API auto-sync is not supported — Philippine banks don't offer public APIs. All entries are manual or auto-captured via notifications.
- iOS build works, but notification auto-capture is Android-only (iOS doesn't allow third-party notification reading).
- No cloud backup — data lives on this device. Use "Clear all data" with caution.
- No biometric lock yet — package is wired up but not active.

## Next steps

- Recurring transaction detection + auto-logging
- Multi-currency
- Receipt photo attachments
- Charts: category breakdown pie, savings rate trend, cashflow over time
- Biometric app lock
- Local cloud backup via Google Drive / iCloud

## Privacy

- All data is stored on this device in SQLite. The app does not transmit any of your data anywhere by default.
- The optional remote AI coach only sends data if you explicitly enable it, configure an API key, and choose a non-local provider.
- Notification access is used **only** for the packages you whitelist, and **only** for parsing transaction amounts — never for surveillance or analytics.

## License

MIT (this project). Brand names (BDO, GCash, Maya, etc.) are trademarks of their respective owners; logos in `assets/logos/` are stylized monograms, not official brand artwork.