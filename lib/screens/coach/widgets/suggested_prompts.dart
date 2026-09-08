import 'package:flutter/material.dart';

class SuggestedPrompts extends StatelessWidget {
  final List<String> prompts;
  final void Function(String) onTap;
  const SuggestedPrompts(
      {super.key, required this.prompts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (prompts.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try asking',
            style: t.textTheme.bodySmall
                ?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: prompts
                .map((p) => ActionChip(
                      label: Text(p, style: const TextStyle(fontSize: 12)),
                      onPressed: () => onTap(p),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
