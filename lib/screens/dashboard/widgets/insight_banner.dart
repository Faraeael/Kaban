import 'package:flutter/material.dart';
import '../../../services/spending_analyzer.dart';

class InsightBanner extends StatelessWidget {
  final SpendingInsight insight;
  const InsightBanner({super.key, required this.insight});

  Color _color(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    switch (insight.severity) {
      case InsightSeverity.info:
        return s.primary;
      case InsightSeverity.warn:
        return const Color(0xFFD97706);
      case InsightSeverity.alert:
        return s.error;
    }
  }

  IconData _icon() {
    switch (insight.severity) {
      case InsightSeverity.info:
        return Icons.lightbulb_outline_rounded;
      case InsightSeverity.warn:
        return Icons.warning_amber_rounded;
      case InsightSeverity.alert:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon(), color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.detail,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
