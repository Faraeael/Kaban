# Kaban

A quiet, privacy-first personal finance and debt tracker for Philippine wallets (BDO, Maya, GCash, GoTyme, BPI, cash, credit cards), with physical card styling, a swipeable QR Deck for receiving payments, and a built-in AI coach with receipt image scanning. Inspired by the Pikash app's feature set.

## Features

- **Physical card wallets** — banks, e-wallets, credit cards, cash with brand logos, category tabs, and masked account numbers.
- **Receive QR Deck** — attach your static InstaPay / QR Ph receive QR to any wallet and swipe through them fullscreen for quick scanning.
- **Transfers between wallets** — atomic two-sided transfer, net worth remains accurate.
- **Real debt payoff math** — avalanche (highest APR first) and snowball (smallest balance first) with projected payoff dates, total interest, and 1-tap payment recording.
- **Savings goals & budgets** — goals with "+ Add savings", per-category monthly limits with Quincena pay-cycle toggles and overspend alerts.
- **Recurring bills & subscriptions** — automatic catch-up on launch and periodic background processing via WorkManager.
- **Quick Log** — 1-tap expense presets on the Dashboard and an Android Home Screen widget.
- **AI Coach** — local rule-based engine (works offline) plus optional remote coach via Google Gemini, OpenRouter, CommandCode, or OpenCode with multimodal receipt/screenshot scanning.
- **100% on-device** — all data stored locally in SQLite (schema v8). No accounts, no cloud sync, Android cloud auto-backup disabled.

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

### Security & Privacy

- **Local SQLite storage:** Data stays on your device in `finance_tracker.db`.
- **Screen protection:** Android `FLAG_SECURE` enabled so app contents are hidden in the recent apps switcher.
- **Biometric lock:** Require fingerprint, face, or device PIN to view financial data.
- **Privacy Mode (Jeep Mode):** Masks wallet balances, net worth, account numbers, and hides QR/Copy buttons while commuting or in public.
- **No cloud auto-backup:** Android `allowBackup="false"` prevents silent uploading of your database to Google Drive.
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
4. **Add a debt.** Debts tab → "Add debt" → "BDO Credit Card, ₱5000, 24% APR, ₱250 min". Tap "Record payment" to log a payment and deduct from your wallet in one tap.
5. **Test the coach.** Coach tab → tap "What should I pay first?" or type "Paid ₱15 jeep fare" to see an action card appear.
6. **Bind a receive QR.** Wallets screen → tap your card → "Attach QR" → pick a saved QR Ph screenshot → tap "Save Card". Tap the "QR" button on the card to open the fullscreen swipeable QR Deck.
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
├── AndroidManifest.xml           App manifest with allowBackup="false"
└── kotlin/ph/kaban/app/
    ├── MainActivity.kt           Method channels + FLAG_SECURE window protection
    ├── QuickLogReceiver.kt       BroadcastReceiver writing widget taps directly to SQLite
    └── QuickFareWidgetProvider.kt Android Home Screen AppWidget provider
```

## Database schema (SQLite, version 8)

- `wallets` — id, name, type, starting_balance, currency, color_value, archived, logo_asset, account_number, account_name, account_label, qr_image_path
- `transactions` — id, amount, type, category, note, date, wallet_id, transfer_pair_id, auto_captured
- `debts` — id, name, balance, apr, min_payment, strategy, linked_wallet_id, schedule, due_day, remaining_payments, paid_off, billing_day, grace_days
- `goals` — id, name, target, saved, deadline
- `budgets` — id, category, monthly_limit
- `subscriptions` — id, name, amount, cadence, next_billing_date, category, wallet_id
- `notification_events` — id, package_name, raw_title, raw_text, received_at, parse_status, transaction_id
- `chat_messages` — id, role, content, timestamp, image_path
- `recurring_transactions` — id, name, amount, type, category, interval_days, next_due, wallet_id, enabled
## Running tests

```bash
flutter test
```

Tests cover debt payoff simulation, recurring transaction idempotency, balance recalculation, privacy mode masking, and coach action parsing.

## Known limitations

- Bank API auto-sync is not supported — Philippine banks don't offer public APIs; entries are manual, quick-logged, or parsed via Coach.
- No multi-currency — Philippine peso (₱) only.
- Manual export backup — data lives on this device. Use **Settings → Save backup** to create portable JSON backups.

## Privacy

- All data is stored on this device in SQLite. The app does not transmit any of your data anywhere by default.
- The optional remote AI coach only sends data if you explicitly enable it, configure an API key, and choose a non-local provider. Balances are anonymized (rounded to ₱100) by default.

## License

MIT (this project). Brand names (BDO, GCash, Maya, etc.) are trademarks of their respective owners; logos in `assets/logos/` are stylized monograms and vector assets.