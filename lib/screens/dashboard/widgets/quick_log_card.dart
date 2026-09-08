import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/quick_preset.dart';
import '../../../models/transaction.dart';
import '../../../state/data_providers.dart';
import '../../../state/quick_preset_provider.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Public card widget
// ---------------------------------------------------------------------------

/// A customizable "Quick Log" card on the Dashboard.
///
/// Shows up to 4 emoji preset chips that log a transaction with a single tap.
/// Long-press any chip to edit or delete it.  An edit icon opens the full
/// preset manager sheet.
class QuickLogCard extends ConsumerWidget {
  const QuickLogCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(quickPresetProvider);
    final t = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: t.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Log',
                style: t.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              InkWell(
                onTap: () => _openManager(context, ref),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (presets.isEmpty)
            _EmptyState(onAdd: () => _openManager(context, ref))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...presets.take(4).map(
                      (p) => _PresetChip(
                        preset: p,
                        onLog: () => _log(context, ref, p),
                        onEdit: () =>
                            _openEditSheet(context, ref, preset: p),
                      ),
                    ),
                if (presets.length < 4)
                  _AddChip(
                      onTap: () =>
                          _openEditSheet(context, ref, preset: null)),
              ],
            ),
        ],
      ),
    );
  }

  // ---------- helpers -------------------------------------------------------

  Future<void> _log(
      BuildContext context, WidgetRef ref, QuickPreset p) async {
    final wallets =
        ref.read(walletListProvider).where((w) => !w.archived).toList();
    if (wallets.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a wallet first!')),
      );
      return;
    }

    final wallet = p.walletId != null
        ? wallets.firstWhere((w) => w.id == p.walletId,
            orElse: () => wallets.first)
        : wallets.first;

    final txn = Transaction(
      id: _uuid.v4(),
      amount: p.amount,
      type: TransactionType.expense,
      category: p.category,
      note: p.label,
      date: DateTime.now(),
      walletId: wallet.id,
    );
    await ref.read(transactionListProvider.notifier).add(txn);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('${p.icon} ${p.label} ₱${p.amount.toStringAsFixed(0)} logged'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openManager(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PresetManagerSheet(),
    );
  }

  void _openEditSheet(BuildContext context, WidgetRef ref,
      {required QuickPreset? preset}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PresetEditSheet(preset: preset),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip widgets
// ---------------------------------------------------------------------------

class _PresetChip extends StatelessWidget {
  final QuickPreset preset;
  final VoidCallback onLog;
  final VoidCallback onEdit;

  const _PresetChip({
    required this.preset,
    required this.onLog,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return GestureDetector(
      onTap: onLog,
      onLongPress: onEdit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: t.colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(preset.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 2),
            Text(
              preset.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: t.colorScheme.onPrimaryContainer,
              ),
            ),
            Text(
              '₱${preset.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 11,
                color: t.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                t.colorScheme.outlineVariant.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded,
                size: 20, color: t.colorScheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'preset',
              style: TextStyle(
                fontSize: 11,
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return GestureDetector(
      onTap: onAdd,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Tap ⚙ to add your quick presets',
            style: TextStyle(
                fontSize: 13, color: t.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preset Manager Sheet (full list + reorder)
// ---------------------------------------------------------------------------

class _PresetManagerSheet extends ConsumerWidget {
  const _PresetManagerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(quickPresetProvider);
    final t = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: t.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quick Log Presets',
                    style: t.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset'),
                      onPressed: () async {
                        await ref
                            .read(quickPresetProvider.notifier)
                            .reset();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'New preset',
                      onPressed: () => _openEdit(context, null),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: presets.isEmpty
                ? Center(
                    child: Text('No presets yet',
                        style: TextStyle(
                            color: t.colorScheme.onSurfaceVariant)),
                  )
                : ReorderableListView.builder(
                    scrollController: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: presets.length,
                    // ignore: deprecated_member_use
                    onReorder: (o, n) => ref
                        .read(quickPresetProvider.notifier)
                        .reorder(o, n),
                    itemBuilder: (_, i) {
                      final p = presets[i];
                      return ListTile(
                        key: ValueKey(p.id),
                        leading: Text(p.icon,
                            style: const TextStyle(fontSize: 24)),
                        title: Text(
                          '${p.label}  ₱${p.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(p.category),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18),
                              onPressed: () => _openEdit(context, p),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 18,
                                  color: t.colorScheme.error),
                              onPressed: () => ref
                                  .read(quickPresetProvider.notifier)
                                  .remove(p.id),
                            ),
                            const Icon(Icons.drag_handle_rounded,
                                size: 20),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openEdit(BuildContext context, QuickPreset? preset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PresetEditSheet(preset: preset),
    );
  }
}

// ---------------------------------------------------------------------------
// Preset Edit Sheet
// ---------------------------------------------------------------------------

class _PresetEditSheet extends ConsumerStatefulWidget {
  final QuickPreset? preset;
  const _PresetEditSheet({this.preset});

  @override
  ConsumerState<_PresetEditSheet> createState() => _PresetEditSheetState();
}

class _PresetEditSheetState extends ConsumerState<_PresetEditSheet> {
  late final TextEditingController _icon;
  late final TextEditingController _label;
  late final TextEditingController _amount;
  late String _category;
  String? _walletId;

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    _icon = TextEditingController(text: p?.icon ?? '💸');
    _label = TextEditingController(text: p?.label ?? '');
    _amount = TextEditingController(
        text: p != null ? p.amount.toStringAsFixed(0) : '');
    _category = p?.category ?? kDefaultExpenseCategories.first;
    _walletId = p?.walletId;
  }

  @override
  void dispose() {
    _icon.dispose();
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final wallets =
        ref.watch(walletListProvider).where((w) => !w.archived).toList();
    final isNew = widget.preset == null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(isNew ? 'New Preset' : 'Edit Preset',
                style: t.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _icon,
                    decoration: const InputDecoration(
                        labelText: 'Icon', hintText: '💸'),
                    style: const TextStyle(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _label,
                    decoration:
                        const InputDecoration(labelText: 'Label'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: 'Amount (₱)',
                prefixText: '₱ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: kDefaultExpenseCategories.contains(_category)
                  ? _category
                  : kDefaultExpenseCategories.first,
              decoration:
                  const InputDecoration(labelText: 'Category'),
              items: kDefaultExpenseCategories
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            if (wallets.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _walletId,
                decoration: const InputDecoration(
                    labelText: 'Wallet (optional)'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Default wallet')),
                  ...wallets.map((w) =>
                      DropdownMenuItem(value: w.id, child: Text(w.name))),
                ],
                onChanged: (v) => setState(() => _walletId = v),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(isNew ? 'Add Preset' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0 || _label.text.trim().isEmpty) return;

    final notifier = ref.read(quickPresetProvider.notifier);
    if (widget.preset == null) {
      await notifier.add(QuickPreset(
        id: _uuid.v4(),
        icon: _icon.text.trim().isEmpty ? '💸' : _icon.text.trim(),
        label: _label.text.trim(),
        amount: amount,
        category: _category,
        walletId: _walletId,
      ));
    } else {
      await notifier.update(widget.preset!.copyWith(
        icon: _icon.text.trim().isEmpty ? '💸' : _icon.text.trim(),
        label: _label.text.trim(),
        amount: amount,
        category: _category,
        walletId: _walletId,
      ));
    }
    if (mounted) Navigator.pop(context);
  }
}
