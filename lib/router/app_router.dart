import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/coach/coach_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/debts/debts_screen.dart';
import '../screens/goals/goals_screen.dart';
import '../screens/onboarding/help_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/recurring/recurring_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/transactions/transfer_sheet.dart';
import '../screens/transactions/transactions_screen.dart';
import '../screens/wallets/wallets_screen.dart';
import '../state/settings_provider.dart';

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  redirect: (context, state) {
    final container = ProviderScope.containerOf(context);
    final settings = container.read(settingsProvider);
    final loc = state.matchedLocation;
    final atOnboarding = loc == '/onboarding';
    if (!settings.onboardingComplete && !atOnboarding) return '/onboarding';
    if (settings.onboardingComplete && atOnboarding) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
            path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/wallets', builder: (_, __) => const WalletsScreen()),
        GoRoute(
            path: '/transactions',
            builder: (_, __) => const TransactionsScreen()),
        GoRoute(path: '/debts', builder: (_, __) => const DebtsScreen()),
        GoRoute(path: '/coach', builder: (_, __) => const CoachScreen()),
      ],
    ),
    GoRoute(
      path: '/goals',
      builder: (_, __) => const GoalsScreen(),
    ),
    GoRoute(
      path: '/recurring',
      builder: (_, __) => const RecurringScreen(initialTab: 0),
    ),
    GoRoute(
      path: '/subscriptions',
      builder: (_, __) => const RecurringScreen(initialTab: 1),
    ),
    GoRoute(
      path: '/transactions/transfer',
      builder: (_, __) => const TransferSheet(),
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
  ],
);

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  static const _tabs = [
    ('/dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
    (
      '/wallets',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      'Wallets'
    ),
    (
      '/transactions',
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      'Activity'
    ),
    (
      '/debts',
      Icons.trending_down_outlined,
      Icons.trending_down_rounded,
      'Debts'
    ),
    ('/coach', Icons.psychology_outlined, Icons.psychology_rounded, 'Coach'),
  ];

  int _indexFor(String location) {
    final i = _tabs.indexWhere((t) => location.startsWith(t.$1));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _indexFor(location);
    final t = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 640;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final animatedChild = AnimatedSwitcher(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey<String>(location),
        child: child,
      ),
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: idx,
              onDestinationSelected: (i) => context.go(_tabs[i].$1),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final tab in _tabs)
                  NavigationRailDestination(
                    icon: Icon(tab.$2),
                    selectedIcon: Icon(tab.$3),
                    label: Text(tab.$4),
                  ),
              ],
            ),
            VerticalDivider(
              thickness: 0.8,
              width: 0.8,
              color: t.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: animatedChild,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: animatedChild,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: t.colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => context.go(_tabs[i].$1),
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(
                icon: Icon(tab.$2),
                selectedIcon: Icon(tab.$3),
                label: tab.$4,
              ),
          ],
        ),
      ),
    );
  }
}
