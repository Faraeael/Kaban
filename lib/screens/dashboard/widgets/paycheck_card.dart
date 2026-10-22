import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/salary_plan.dart';
import '../../../services/paycheck_planner.dart';
import '../../../state/data_providers.dart';
import '../../../state/settings_provider.dart';
import '../../../utils/formatters.dart';
import 'salary_plan_sheet.dart';

class PaycheckCard extends ConsumerStatefulWidget {
  const PaycheckCard({super.key});

  @override
  ConsumerState<PaycheckCard> createState() => _PaycheckCardState();
}

class _PaycheckCardState extends ConsumerState<PaycheckCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final plan = settings.salaryPlan;

    if (plan == null) {
      return _buildPromptCard(context, t);
    }

    final debts = ref.watch(debtListProvider);
    final recurring = ref.watch(recurringListProvider);

    final window = PaycheckPlanner.calculateFundingWindow(
      salaryPlan: plan,
      debts: debts,
      recurring: recurring,
    );

    final obscure = settings.privacyMode;
    final isOvercommitted = window.safeToSpend < 0;

    return Semantics(
      label: 'Paycheck plan: ${window.label}, Safe to spend: ${obscure ? "hidden" : peso(window.safeToSpend)}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOvercommitted
                ? t.colorScheme.error.withValues(alpha: 0.5)
                : t.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Badge & Edit Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: t.colorScheme.primaryContainer.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              plan.payFrequency == PayFrequency.biMonthly15_30
                                  ? Icons.calendar_view_week_rounded
                                  : Icons.calendar_month_rounded,
                              size: 14,
                              color: t.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              window.label,
                              style: t.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: t.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Funds ${shortDate(window.windowStart)} – ${shortDate(window.windowEnd)}',
                        style: t.textTheme.labelSmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  tooltip: 'Edit Salary Plan',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    showSalaryPlanSheet(context, initial: plan);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Hero Metric: Safe to Spend
            Text(
              'Safe to Spend',
              style: t.textTheme.labelMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              obscure ? '₱••••••' : peso(window.safeToSpend),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: isOvercommitted
                    ? t.colorScheme.error
                    : t.colorScheme.primary,
                letterSpacing: obscure ? 2.0 : -0.5,
              ),
            ),
            const SizedBox(height: 14),
            // Sub-metrics row
            Row(
              children: [
                _metricItem(
                  context,
                  label: 'Net Payday',
                  value: obscure ? '₱••••' : peso(window.netIncomeThisPayday),
                  color: t.colorScheme.onSurface,
                ),
                _divider(),
                _metricItem(
                  context,
                  label: 'Debt Due',
                  value: obscure ? '₱••••' : peso(window.totalDebtDue),
                  color: window.totalDebtDue > 0
                      ? t.colorScheme.error
                      : t.colorScheme.onSurfaceVariant,
                ),
                _divider(),
                _metricItem(
                  context,
                  label: 'Bills Due',
                  value: obscure ? '₱••••' : peso(window.totalBillsDue),
                  color: window.totalBillsDue > 0
                      ? t.colorScheme.tertiary
                      : t.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            // Obligations Expandable Section
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _expanded = !_expanded);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: t.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        window.obligations.isEmpty
                          ? 'No obligations due in this cycle'
                          : '${window.obligations.length} obligation${window.obligations.length == 1 ? '' : 's'} funded by this pay',
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded && window.obligations.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: window.obligations.map((ob) {
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        ob.isDebt
                            ? Icons.credit_card_outlined
                            : Icons.receipt_long_outlined,
                        size: 20,
                        color: ob.isDebt
                            ? t.colorScheme.error
                            : t.colorScheme.tertiary,
                      ),
                      title: Text(
                        ob.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Due ${shortDate(ob.dueDate)}${ob.subtitle != null ? " • ${ob.subtitle}" : ""}',
                        style: TextStyle(
                          fontSize: 11,
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Text(
                        obscure ? '₱••••' : peso(ob.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: ob.isDebt
                              ? t.colorScheme.error
                              : t.colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard(BuildContext context, ThemeData t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: t.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: t.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.payments_outlined,
              color: t.colorScheme.onPrimaryContainer,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set Up Paycheck Plan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Track PH statutory deductions & see safe-to-spend per payday.',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () {
              HapticFeedback.selectionClick();
              showSalaryPlanSheet(context);
            },
            child: const Text('Configure'),
          ),
        ],
      ),
    );
  }

  Widget _metricItem(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final t = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: t.textTheme.labelSmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.grey.withValues(alpha: 0.25),
    );
  }
}
