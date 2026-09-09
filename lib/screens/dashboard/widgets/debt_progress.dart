import 'package:flutter/material.dart';
import '../../../models/wallet.dart';
import '../../../utils/formatters.dart';

class DebtProgressCard extends StatelessWidget {
  final double totalDebt;
  final double startingTotalDebt;
  final int monthsRemaining;
  final List<Wallet> wallets;
  final VoidCallback? onTap;

  const DebtProgressCard({
    super.key,
    required this.totalDebt,
    required this.startingTotalDebt,
    required this.monthsRemaining,
    required this.wallets,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isFullyDebtFree = startingTotalDebt > 0 && totalDebt <= 0;
    final progress = startingTotalDebt <= 0
        ? 0.0
        : ((startingTotalDebt - totalDebt) / startingTotalDebt).clamp(0, 1);

    final semanticLabel = isFullyDebtFree
        ? 'Debt payoff: Fully debt-free! All tracked loans and cards are 100% paid off.'
        : (startingTotalDebt > 0
            ? 'Debt payoff: ${peso(totalDebt)} remaining, ${(progress * 100).toStringAsFixed(0)}% paid off, ${monthsRemaining > 0 ? "$monthsRemaining months remaining" : "paid off"}'
            : 'Debt payoff: No debts tracked. Tap to add a debt.');

    return Semantics(
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFullyDebtFree
                  ? t.colorScheme.primary.withValues(alpha: 0.35)
                  : t.colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: isFullyDebtFree ? 1.2 : 1.0,
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
                      const Text('Debt payoff',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: t.colorScheme.onSurfaceVariant),
                    ],
                  ),
                  if (isFullyDebtFree)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 14, color: t.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Debt-free! 🌿',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.colorScheme.primary,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      monthsRemaining > 0
                          ? '$monthsRemaining mo left'
                          : 'Done!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: monthsRemaining > 0
                            ? t.colorScheme.primary
                            : t.colorScheme.tertiary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  duration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0.0, end: progress.toDouble()),
                  builder: (context, animatedProgress, _) =>
                      LinearProgressIndicator(
                    value: animatedProgress,
                    minHeight: 8,
                    backgroundColor: t.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(t.colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                peso(totalDebt),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                startingTotalDebt > 0
                    ? (isFullyDebtFree
                        ? '100% paid off · All debts cleared!'
                        : '${(progress * 100).toStringAsFixed(0)}% paid off')
                    : 'Add a debt to start tracking',
                style: t.textTheme.bodySmall?.copyWith(
                  color: isFullyDebtFree
                      ? t.colorScheme.primary
                      : t.colorScheme.onSurfaceVariant,
                  fontWeight: isFullyDebtFree ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
