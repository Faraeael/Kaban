import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/ai/ai_provider_config.dart';
import '../../../services/ai/model_discovery_service.dart';

enum _ModelFilter { all, freeOnly, visionOnly }

class ModelPicker extends StatefulWidget {
  final String currentModelId;
  final ValueChanged<String> onSelected;
  final List<ModelPreset> presets;
  final String headerHint;
  final AIProvider? provider;
  final String? apiKey;
  final String? baseUrl;

  const ModelPicker({
    super.key,
    required this.currentModelId,
    required this.onSelected,
    required this.presets,
    required this.headerHint,
    this.provider,
    this.apiKey,
    this.baseUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentModelId,
    required ValueChanged<String> onSelected,
    required List<ModelPreset> presets,
    required String headerHint,
    AIProvider? provider,
    String? apiKey,
    String? baseUrl,
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
        provider: provider,
        apiKey: apiKey,
        baseUrl: baseUrl,
      ),
    );
  }

  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<ModelPicker> {
  late String _selected = widget.currentModelId;
  late List<ModelPreset> _models = widget.presets;
  bool _isLoading = false;
  bool _isLiveFetched = false;
  _ModelFilter _filter = _ModelFilter.all;

  final TextEditingController _customController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _customController.text = widget.currentModelId;
    if (widget.provider != null && widget.provider != AIProvider.local) {
      _loadLiveModels(forceRefresh: false);
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadLiveModels({bool forceRefresh = false}) async {
    if (widget.provider == null || widget.provider == AIProvider.local) return;
    setState(() => _isLoading = true);

    try {
      final results = await ModelDiscoveryService.instance.getModels(
        provider: widget.provider!,
        apiKey: widget.apiKey,
        baseUrl: widget.baseUrl,
        forceRefresh: forceRefresh,
      );

      if (mounted && results.isNotEmpty) {
        setState(() {
          _models = results;
          _isLiveFetched = true;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<ModelPreset> get _filteredModels {
    switch (_filter) {
      case _ModelFilter.freeOnly:
        return _models.where((m) => m.isFree).toList();
      case _ModelFilter.visionOnly:
        return _models.where((m) => m.supportsVision).toList();
      case _ModelFilter.all:
        return _models;
    }
  }

  Map<String, List<ModelPreset>> get _grouped {
    final m = <String, List<ModelPreset>>{};
    for (final p in _filteredModels) {
      m.putIfAbsent(p.family, () => []).add(p);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final groups = _grouped;
    final familyOrder = groups.keys.toList()..sort();
    final canFetch =
        widget.provider != null && widget.provider != AIProvider.local;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
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
                if (canFetch)
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh live models from provider',
                    onPressed: _isLoading
                        ? null
                        : () => _loadLiveModels(forceRefresh: true),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _isLiveFetched
                        ? 'Live • ${_filteredModels.length}'
                        : '${_filteredModels.length} options',
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
            const SizedBox(height: 12),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == _ModelFilter.all,
                    onSelected: (v) {
                      if (v) setState(() => _filter = _ModelFilter.all);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Text('🎁', style: TextStyle(fontSize: 12)),
                    label: const Text('Free only'),
                    selected: _filter == _ModelFilter.freeOnly,
                    onSelected: (v) {
                      if (v) setState(() => _filter = _ModelFilter.freeOnly);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Text('📸', style: TextStyle(fontSize: 12)),
                    label: const Text('Analyzes photos'),
                    selected: _filter == _ModelFilter.visionOnly,
                    onSelected: (v) {
                      if (v) setState(() => _filter = _ModelFilter.visionOnly);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Models list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.52,
              ),
              child: _filteredModels.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No models match this filter.',
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView(
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
                                setState(() {
                                  _selected = p.id;
                                  _customController.text = p.id;
                                  _showCustomInput = false;
                                });
                              },
                            ),
                            const SizedBox(height: 6),
                          ],
                        ],

                        // Custom Model Input Toggle
                        const SizedBox(height: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(
                              () => _showCustomInput = !_showCustomInput),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  _showCustomInput
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.edit_note_rounded,
                                  size: 18,
                                  color: t.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Enter custom model ID...',
                                  style: t.textTheme.bodySmall?.copyWith(
                                    color: t.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_showCustomInput) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                            child: TextField(
                              controller: _customController,
                              decoration: InputDecoration(
                                hintText:
                                    'e.g. meta-llama/llama-3.3-70b-instruct:free',
                                isDense: true,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.check_rounded),
                                  onPressed: () {
                                    final trimmed =
                                        _customController.text.trim();
                                    if (trimmed.isNotEmpty) {
                                      setState(() => _selected = trimmed);
                                    }
                                  },
                                ),
                              ),
                              onChanged: (v) =>
                                  setState(() => _selected = v.trim()),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final chosen = _customController.text.trim().isNotEmpty
                          ? _customController.text.trim()
                          : _selected;
                      widget.onSelected(chosen);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                color: selected ? t.colorScheme.primary : t.colorScheme.outline,
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

                    // Badges Row for Free and Vision
                    if (preset.isFree || preset.supportsVision) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (preset.isFree)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '🎁 Free',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (preset.supportsVision)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: t.colorScheme.primary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: t.colorScheme.primary
                                      .withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.photo_camera_rounded,
                                    size: 11,
                                    color: t.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Analyzes photos',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: t.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 4),
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
