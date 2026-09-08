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
    final progress = startingTotalDebt <= 0
        ? 0.0
        : ((startingTotalDebt - totalDebt) / startingTotalDebt).clamp(0, 1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: t.colorScheme.outlineVariant.withValues(alpha: 0.2)),
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
                Text(
                  monthsRemaining > 0 ? '$monthsRemaining mo left' : 'Done!',
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
              child: LinearProgressIndicator(
                value: progress.toDouble(),
                minHeight: 8,
                backgroundColor: t.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(t.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              peso(totalDebt),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              startingTotalDebt > 0
                  ? '${(progress * 100).toStringAsFixed(0)}% paid off'
                  : 'Add a debt to start tracking',
              style: t.textTheme.bodySmall
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
