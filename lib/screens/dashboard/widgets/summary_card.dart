import 'package:flutter/material.dart';
import '../../../utils/formatters.dart';

class SummaryCard extends StatelessWidget {
  final double income;
  final double expense;
  final bool obscure;
  const SummaryCard({
    super.key,
    required this.income,
    required this.expense,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final total = income + expense;
    final hasIncome = income > 0;
    final hasExpense = expense > 0;

    return Semantics(
      label:
          'This month: Income ${obscure ? "hidden" : peso(income)}, Expense ${obscure ? "hidden" : peso(expense)}',
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
            const Text('This month',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: t.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('Income', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: MediaQuery.of(context).disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: Text(
                          obscure ? '₱••••' : peso(income),
                          key: ValueKey<bool>(obscure),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: t.colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('Expense', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: MediaQuery.of(context).disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: Text(
                          obscure ? '₱••••' : peso(expense),
                          key: ValueKey<bool>(obscure),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (total <= 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 8,
                  color: t.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                ),
              )
            else if (hasIncome && !hasExpense)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 8,
                  color: t.colorScheme.primary,
                ),
              )
            else if (!hasIncome && hasExpense)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 8,
                  color: t.colorScheme.error.withValues(alpha: 0.85),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    flex: ((income / total) * 1000).toInt().clamp(1, 999),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: t.colorScheme.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: ((expense / total) * 1000).toInt().clamp(1, 999),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: t.colorScheme.error.withValues(alpha: 0.85),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
