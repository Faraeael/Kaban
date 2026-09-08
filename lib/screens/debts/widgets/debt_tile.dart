import 'package:flutter/material.dart';
import '../../../models/debt.dart';
import '../../../utils/formatters.dart';

class DebtTile extends StatelessWidget {
  final Debt debt;
  final int monthsToPayoff;
  final double interestPaid;
  final VoidCallback? onTap;

  const DebtTile({
    super.key,
    required this.debt,
    required this.monthsToPayoff,
    required this.interestPaid,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final payoffDate = DateTime.now().add(Duration(days: monthsToPayoff * 30));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: t.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    debt.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: t.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.colorScheme.errorContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${debt.apr.toStringAsFixed(1)}% APR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: t.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                if (debt.schedule == DebtSchedule.fixed &&
                    debt.remainingPayments != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${debt.remainingPayments} mo left${debt.dueDay != null ? ' · due ${debt.dueDay}th' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: t.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  )
                else if (debt.schedule == DebtSchedule.statementCycle &&
                    debt.billingDay != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Billing: ${debt.billingDay}th',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: t.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              peso(debt.balance),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${peso(debt.minPayment)}/mo min · $monthsToPayoff mo to freedom',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${payoffDate.year}-${payoffDate.month.toString().padLeft(2, '0')}',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total interest: ${peso(interestPaid)}',
              style: t.textTheme.labelSmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
