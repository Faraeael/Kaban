import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/ai/ai_provider_config.dart';

class ModelPicker extends StatefulWidget {
  final String currentModelId;
  final ValueChanged<String> onSelected;
  final List<ModelPreset> presets;
  final String headerHint;
  const ModelPicker({
    super.key,
    required this.currentModelId,
    required this.onSelected,
    required this.presets,
    required this.headerHint,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentModelId,
    required ValueChanged<String> onSelected,
    required List<ModelPreset> presets,
    required String headerHint,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ModelPicker(
        currentModelId: currentModelId,
        onSelected: onSelected,
        presets: presets,
        headerHint: headerHint,
      ),
    );
  }

  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<ModelPicker> {
  late String _selected = widget.currentModelId;

  Map<String, List<ModelPreset>> get _grouped {
    final m = <String, List<ModelPreset>>{};
    for (final p in widget.presets) {
      m.putIfAbsent(p.family, () => []).add(p);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final groups = _grouped;
    final familyOrder = groups.keys.toList()..sort();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose a model',
                    style: t.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${widget.presets.length} options',
                    style: t.textTheme.labelSmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.headerHint,
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final family in familyOrder) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                      child: Text(
                        family.toUpperCase(),
                        style: t.textTheme.labelSmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final p in groups[family]!) ...[
                      _ModelRow(
                        preset: p,
                        selected: _selected == p.id,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selected = p.id);
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      widget.onSelected(_selected);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Use this'),
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

class _ModelRow extends StatelessWidget {
  final ModelPreset preset;
  final bool selected;
  final VoidCallback onTap;
  const _ModelRow({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? t.colorScheme.primaryContainer.withValues(alpha: 0.55)
                : t.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? t.colorScheme.primary
                  : t.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? t.colorScheme.primary
                    : t.colorScheme.outline,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preset.name,
                            style: t.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Text(
                          preset.id,
                          style: t.textTheme.labelSmall?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preset.tagline,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}