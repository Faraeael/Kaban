# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

The owner — a Filipino professional who commutes daily, pays for work meals, and juggles several Philippine wallets (bank, e-wallet, credit, cash) — plus a small trusted circle of family and friends who receive sideloaded APKs. Distribution is trust-based, not through an app store, so first-run setup must be self-serve and friction-free.

## Product Purpose

A privacy-first Android app for tracking income, expenses, debts, savings goals, budgets, and subscriptions across multiple Philippine wallets, with a built-in AI coach and notification auto-capture. Success is the user knowing their real net worth and cashflow at a glance without their financial data ever leaving the device.

## Positioning

The combination no other PH finance tracker copies honestly: 100% on-device storage (no accounts, no cloud, no telemetry) + Philippine-native depth (peso formatting, BDO/BPI/Maya/GCash/GoTyme presets, GCash/Maya/BDO/BPI notification auto-capture) + an AI coach that acts on conversation — logging expenses, debt payments, savings contributions, and recurring entries after explicit confirmation. Inspired by Pikash's feature set.

## Operating Context

Used in short bursts on an Android phone: logging a commute or meal right after paying, checking balances before a purchase, reviewing debt progress monthly. Android notification auto-capture (API 24+) reads whitelisted banking app notifications so transactions log themselves. All data lives in on-device SQLite; the optional remote AI coach sends only an anonymized snapshot (no merchant names, balances rounded to ₱100 by default) and only when the user enables it with an API key.

## Capabilities and Constraints

- Flutter app, Android-first. iOS parity is explicitly not required.
- Philippine peso only; multi-currency is explicitly out of scope.
- Multi-wallet tracking with official PH bank/e-wallet presets plus custom wallets; transfers between wallets without double-counting.
- Debt payoff math: avalanche and snowball strategies with projected payoff dates and total interest.
- Savings goals with deadlines; monthly budgets per category with overspend alerts.
- Subscription tracking with auto-detection from transaction history.
- Notification auto-capture from a user-editable whitelist (defaults: GCash, Maya, BDO Personal, BPI).
- AI Coach: local offline rule engine by default; optional remote providers (CommandCode, OpenCode, OpenRouter) with base URL/model/API key configuration and a Test API button.
- Coach actions (log expense/income, record debt payment, add to savings goal, create debt/goal, create recurring entry) always render as suggest-and-confirm cards — the coach never writes silently.
- Recurring transactions engine: daily/weekly/bi-weekly/monthly/yearly entries, WorkManager background scheduling, and launch-time catch-up with correctly-dated backfill.
- JSON backup export/import; biometric app lock (local_auth); SQLite schema version 4.
- No accounts, no cloud sync, no telemetry.

## Brand Commitments

- Name: "Kaban" (traditional Filipino treasury / chest for safekeeping wealth and savings).
- Official bank/e-wallet logos are used in-app (BDO, BPI, Maya, GCash, GoTyme, Metrobank, UnionBank, Security Bank, Landbank, RCBC, Shopee); generic monograms for cash/credit/custom. Binding for visual work.
- Voice is plain and practical — short labels, honest privacy copy, no marketing exaggeration.

## Evidence on Hand

- `README.md`: full feature, architecture, schema, and privacy documentation.
- `assets/logos/`: the official SVG logos noted above.
- Working codebase: all screens, engine, and tests described above exist and pass.
- No testimonials, press, benchmarks, or user data exist; future work must not fabricate them.

## Product Principles

1. Privacy is the product — everything is on-device by default; anything remote is opt-in, keyed, and anonymized.
2. The coach suggests, never acts silently — every write to user data requires visible confirmation.
3. Philippine-first — peso, PH wallets, PH notification sources; foreign-market features never displace these.
4. Trusted-circle scale — the app must be understandable and self-serve without an app store, onboarding, or support staff.
5. Honesty in numbers — balances, debt math, and catch-up backfill must stay accurate; approximations are labeled as such.
