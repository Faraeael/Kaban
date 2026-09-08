import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/transaction.dart';
import '../../../utils/formatters.dart';

const _chartPalette = [
  Color(0xFF1B7F5F),
  Color(0xFF0E7490),
  Color(0xFF7C3AED),
  Color(0xFFD97706),
  Color(0xFFDC2626),
  Color(0xFF2563EB),
  Color(0xFF64748B),
];

class SpendingPieChart extends StatelessWidget {
  final Map<String, double> byCategory;
  const SpendingPieChart({super.key, required this.byCategory});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    return _ChartCard(
      title: 'This month by category',
      child: total <= 0
          ? const _ChartHint(text: 'No expenses recorded this month yet.')
          : Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 34,
                      sections: _sections(entries, total),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < entries.length && i < 7; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color:
                                      _chartPalette[i % _chartPalette.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entries[i].key,
                                  style: t.textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                peso(entries[i].value),
                                style: t.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<PieChartSectionData> _sections(
      List<MapEntry<String, double>> entries, double total) {
    final top = entries.take(6).toList();
    final restValue = entries.skip(6).fold<double>(0, (s, e) => s + e.value);
    if (restValue > 0) {
      top.add(MapEntry('Other', restValue));
    }
    return [
      for (var i = 0; i < top.length; i++)
        PieChartSectionData(
          value: top[i].value,
          color: _chartPalette[i % _chartPalette.length],
          radius: 30,
          showTitle: false,
        ),
    ];
  }
}

class CashflowBarChart extends StatelessWidget {
  final List<Transaction> txns;
  const CashflowBarChart({super.key, required this.txns});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final now = DateTime.now();
    final months = <DateTime>[
      for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i, 1),
    ];
    final incomes = List<double>.filled(6, 0);
    final expenses = List<double>.filled(6, 0);
    for (final txn in txns) {
      for (var i = 0; i < 6; i++) {
        final m = months[i];
        if (txn.date.year == m.year && txn.date.month == m.month) {
          if (txn.type == TransactionType.income) {
            incomes[i] += txn.amount;
          } else if (txn.type == TransactionType.expense) {
            expenses[i] += txn.amount;
          }
          break;
        }
      }
    }
    final maxVal = [
      ...incomes,
      ...expenses,
    ].fold<double>(0, (s, v) => v > s ? v : s);

    return _ChartCard(
      title: 'Last 6 months',
      child: maxVal <= 0
          ? const _ChartHint(
              text: 'Log income and expenses to see your cashflow.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 150,
                  child: BarChart(
                    BarChartData(
                      maxY: maxVal * 1.2,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxVal / 3,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: t.colorScheme.outlineVariant
                              .withValues(alpha: 0.3),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateFormat('MMM').format(months[value.toInt()]),
                                style: t.textTheme.labelSmall?.copyWith(
                                  color: t.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < 6; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 4,
                            barRods: [
                              BarChartRodData(
                                toY: incomes[i],
                                color: t.colorScheme.primary,
                                width: 10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: expenses[i],
                                color:
                                    t.colorScheme.error.withValues(alpha: 0.75),
                                width: 10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _LegendDot(
                        color: t.colorScheme.primary, label: 'Income', t: t),
                    const SizedBox(width: 14),
                    _LegendDot(
                        color: t.colorScheme.error.withValues(alpha: 0.75),
                        label: 'Expense',
                        t: t),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ChartHint extends StatelessWidget {
  final String text;
  const _ChartHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Icon(Icons.bar_chart_rounded, size: 18, color: t.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: t.textTheme.bodySmall
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final ThemeData t;
  const _LegendDot({required this.color, required this.label, required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: t.textTheme.bodySmall
              ?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
