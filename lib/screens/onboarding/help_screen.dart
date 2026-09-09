import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _query = TextEditingController();

  static const _entries = <_HelpEntry>[
    _HelpEntry(
      icon: Icons.account_balance_wallet_rounded,
      task: 'I want to add a wallet',
      steps: [
        'Tap Wallets in the bottom bar.',
        'Tap the + Add wallet button.',
        'Pick a bank or e-wallet, or choose Custom.',
        'Set your starting balance. You can change it later.',
      ],
      navTo: '/wallets',
    ),
    _HelpEntry(
      icon: Icons.swap_horiz_rounded,
      task: 'I moved money between wallets',
      steps: [
        'Go to Activity or Dashboard.',
        'Tap the transfer (swap) button in the top bar or Quick Actions.',
        'Pick the source and destination wallet, then the amount.',
        'Both balances update. Your net worth stays the same.',
      ],
      navTo: '/transactions/transfer',
    ),
    _HelpEntry(
      icon: Icons.receipt_long_rounded,
      task: 'I want to log a transaction',
      steps: [
        'Go to Activity.',
        'Tap + Add.',
        'Pick Income, Expense, or Transfer.',
        'Type the amount, choose a category and a wallet, then Save.',
      ],
      navTo: '/transactions',
    ),
    _HelpEntry(
      icon: Icons.trending_down_rounded,
      task: 'I want to plan debt payoff',
      steps: [
        'Go to Debts.',
        'Tap + Add debt — name it, enter balance, APR %, min payment.',
        'Use the menu (top right) to switch Avalanche ↔ Snowball.',
        'Drag the slider to simulate paying extra each month.',
      ],
      navTo: '/debts',
    ),
    _HelpEntry(
      icon: Icons.subscriptions_rounded,
      task: 'I want to track a recurring bill or subscription',
      steps: [
        'Go to Bills & Subscriptions.',
        'Switch between Recurring Bills and Subscriptions at the top.',
        'Tap + Add to log commute, rent, or utilities under Recurring Bills, or streaming & cloud services under Subscriptions.',
        'Or under Subscriptions, check Detected to auto-track recurring charges from your transactions.',
      ],
      navTo: '/subscriptions',
    ),
    _HelpEntry(
      icon: Icons.flag_rounded,
      task: 'I want to set a savings goal or budget',
      steps: [
        'Go to Goals.',
        'Switch between Goals and Budgets at the top.',
        'Add a goal with a name, target, and optional deadline.',
        'Add a budget per category — overspending lights up the dashboard.',
      ],
      navTo: '/goals',
    ),
    _HelpEntry(
      icon: Icons.psychology_rounded,
      task: 'I want to ask the AI coach',
      steps: [
        'Go to Coach.',
        'Type a question, or tap a suggested prompt.',
        'Try "what should I pay first?", "where am I overspending?", '
            'or "how is my Maya?".',
        'Switch providers anytime in Settings → AI Coach.',
      ],
      navTo: '/coach',
    ),
    _HelpEntry(
      icon: Icons.notifications_active_rounded,
      task: 'I want auto-capture from GCash / Maya / BDO',
      steps: [
        'Settings → Auto-capture → toggle on.',
        'Tap Enable — Android opens Notification access.',
        'Toggle Kaban on, then come back.',
        'Next time you pay, the transaction is logged automatically.',
      ],
      navTo: '/settings',
    ),
    _HelpEntry(
      icon: Icons.lock_rounded,
      task: 'I want to lock the app',
      steps: [
        'Open Settings (top-right cog on Dashboard).',
        'Scroll to Security → toggle "Biometric app lock" on.',
        'Uses fingerprint, face unlock, or your Android screen lock PIN.',
        'Requires authentication whenever opening or returning to the app.',
      ],
      navTo: '/settings',
    ),
    _HelpEntry(
      icon: Icons.ios_share_rounded,
      task: 'I want to back up or restore my data',
      steps: [
        'Settings → Data → Export backup to save a complete JSON backup file.',
        'Settings → Data → Import backup to restore your data on any device.',
        'All wallets, transactions, debts, goals, and recurring entries are preserved.',
      ],
      navTo: '/settings',
    ),
    _HelpEntry(
      icon: Icons.delete_outline_rounded,
      task: 'I want to wipe my data',
      steps: [
        'Settings → Data → Clear all data.',
        'Confirm. This deletes every wallet, transaction, debt, goal, and recurring entry.',
        'Tip: Export a backup first if you might want your data back later.',
      ],
      navTo: '/settings',
    ),
  ];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<_HelpEntry> _filtered() {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    return _entries.where((e) {
      if (e.task.toLowerCase().contains(q)) return true;
      if (e.steps.any((s) => s.toLowerCase().contains(q))) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final results = _filtered();

    return Scaffold(
      backgroundColor: t.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Help'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _query,
              decoration: InputDecoration(
                hintText: 'What are you trying to do?',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? _NoResults(query: _query.text)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _HelpCard(entry: results[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  final _HelpEntry entry;
  const _HelpCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: t.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(entry.icon, size: 20, color: t.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.task,
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (entry.navTo != null)
                IconButton(
                  tooltip: 'Go to ${entry.task}',
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push(entry.navTo!);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(entry.steps.length, (i) {
            final isLast = i == entry.steps.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}.',
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.steps[i],
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: t.colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 40, color: t.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No matches for "$query"',
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different word, or browse the full list.',
              textAlign: TextAlign.center,
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpEntry {
  final IconData icon;
  final String task;
  final List<String> steps;
  final String? navTo;
  const _HelpEntry({
    required this.icon,
    required this.task,
    required this.steps,
    this.navTo,
  });
}
