import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../state/data_providers.dart';
import '../../state/settings_provider.dart';
import '../../utils/formatters.dart';
import 'widgets/charts.dart';
import 'widgets/debt_progress.dart';
import 'widgets/insight_banner.dart';
import 'widgets/quick_log_card.dart';
import 'widgets/summary_card.dart';
import 'widgets/wallet_balance_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletListProvider.notifier).load();
      ref.read(transactionListProvider.notifier).load();
      ref.read(debtListProvider.notifier).load();
      ref.read(goalListProvider.notifier).load();
      ref.read(budgetListProvider.notifier).load();
      ref.read(subscriptionListProvider.notifier).load();
      final settings = ref.read(settingsProvider);
      if (settings.autoBackupOnLaunch) {
        ref.read(backupServiceProvider).autoBackup();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final wallets = ref.watch(walletListProvider);
    final txns = ref.watch(transactionListProvider);
    final debts = ref.watch(debtListProvider);
    final balances = ref.watch(walletBalancesProvider);
    final netWorth = ref.watch(netWorthProvider);
    final monthSummary = ref.watch(monthSummaryProvider);
    final settings = ref.watch(settingsProvider);

    final insight = ref.watch(dashboardInsightProvider);
    final payoff = ref.watch(dashboardPayoffProvider);
    final startingDebt = debts.fold<double>(0, (s, d) => s + d.balance) +
        payoff.totalInterestPaid;

    final visibleWallets = wallets.where((w) => !w.archived).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(settings.privacyMode
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            tooltip: settings.privacyMode ? 'Show balances' : 'Hide balances',
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(settingsProvider.notifier).update(
                    settings.copyWith(privacyMode: !settings.privacyMode),
                  );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(walletListProvider.notifier).load(),
            ref.read(transactionListProvider.notifier).load(),
            ref.read(debtListProvider.notifier).load(),
          ]);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;

            final netWorthCard = Semantics(
              label: settings.privacyMode
                  ? 'Net worth is hidden. Privacy mode is active.'
                  : 'Net worth: ${netWorth < 0 ? "negative " : ""}${peso(netWorth.abs())} for ${monthLabel(DateTime.now())}',
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: t.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: t.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Net worth',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: settings.privacyMode
                                  ? 'Show net worth'
                                  : 'Hide net worth',
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref.read(settingsProvider.notifier).update(
                                        settings.copyWith(
                                            privacyMode: !settings.privacyMode),
                                      );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    settings.privacyMode
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 18,
                                    color: t.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            monthLabel(DateTime.now()),
                            style: t.textTheme.labelSmall?.copyWith(
                              color: t.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: MediaQuery.of(context).disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Text(
                        settings.privacyMode ? '₱••••••' : peso(netWorth),
                        key: ValueKey<bool>(settings.privacyMode),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: netWorth < 0
                              ? t.colorScheme.error
                              : t.colorScheme.onPrimaryContainer,
                          letterSpacing: settings.privacyMode ? 2.0 : -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            final insightBanner = (insight != null)
                ? InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push('/goals'),
                    child: InsightBanner(insight: insight),
                  )
                : null;

            final walletsSection = visibleWallets.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Wallets',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          TextButton(
                            onPressed: () => context.push('/wallets'),
                            child: const Text('See all'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: visibleWallets.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) => WalletBalanceCard(
                            wallet: visibleWallets[i],
                            balance: balances[visibleWallets[i].id] ?? 0,
                            obscureBalance: settings.privacyMode,
                            onTap: () => context.push('/wallets'),
                          ),
                        ),
                      ),
                    ],
                  )
                : null;

            final summaryCard = SummaryCard(
              income: monthSummary.income,
              expense: monthSummary.expense,
              obscure: settings.privacyMode,
            );

            final debtProgressCard = DebtProgressCard(
              totalDebt: debts.fold(0, (s, d) => s + d.balance),
              startingTotalDebt: startingDebt,
              monthsRemaining: payoff.totalMonths,
              wallets: wallets,
              onTap: () => context.push('/debts'),
            );

            if (isWide) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            netWorthCard,
                            if (insightBanner != null) ...[
                              const SizedBox(height: 14),
                              insightBanner,
                            ],
                            const SizedBox(height: 14),
                            const _QuickActionStrip(),
                            const SizedBox(height: 14),
                            const QuickLogCard(),
                            if (walletsSection != null) ...[
                              const SizedBox(height: 14),
                              walletsSection,
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            summaryCard,
                            const SizedBox(height: 12),
                            CashflowBarChart(txns: txns),
                            const SizedBox(height: 12),
                            SpendingPieChart(
                                byCategory: monthSummary.byCategory),
                            const SizedBox(height: 12),
                            debtProgressCard,
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                netWorthCard,
                if (insightBanner != null) ...[
                  const SizedBox(height: 14),
                  insightBanner,
                ],
                const SizedBox(height: 14),
                const _QuickActionStrip(),
                const SizedBox(height: 14),
                const QuickLogCard(),
                if (walletsSection != null) ...[
                  const SizedBox(height: 14),
                  walletsSection,
                  const SizedBox(height: 14),
                ],
                summaryCard,
                const SizedBox(height: 12),
                CashflowBarChart(txns: txns),
                const SizedBox(height: 12),
                SpendingPieChart(byCategory: monthSummary.byCategory),
                const SizedBox(height: 12),
                debtProgressCard,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuickActionStrip extends StatelessWidget {
  const _QuickActionStrip();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final items = [
      (
        icon: Icons.swap_horiz_rounded,
        label: 'Transfer',
        path: '/transactions/transfer',
      ),
      (
        icon: Icons.flag_rounded,
        label: 'Goals & Budgets',
        path: '/goals',
      ),
      (
        icon: Icons.autorenew_rounded,
        label: 'Bills & Subs',
        path: '/recurring',
      ),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final item = items[i];
          return InkWell(
            onTap: () => ctx.push(item.path),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: t.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: t.colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 18, color: t.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
