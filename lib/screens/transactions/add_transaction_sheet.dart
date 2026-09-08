import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/transaction.dart';
import '../../state/data_providers.dart';
import 'widgets/category_chip.dart';

const _uuid = Uuid();

class AddTransactionSheet extends ConsumerStatefulWidget {
  final Transaction? initial;
  const AddTransactionSheet({super.key, this.initial});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late TransactionType _type;
  late TextEditingController _amount;
  late TextEditingController _note;
  String? _category;
  String? _walletId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _type = widget.initial?.type ?? TransactionType.expense;
    _amount = TextEditingController(
        text: widget.initial?.amount.toStringAsFixed(0) ?? '');
    _note = TextEditingController(text: widget.initial?.note ?? '');
    _category = widget.initial?.category;
    _walletId = widget.initial?.walletId;
    _date = widget.initial?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallets =
        ref.watch(walletListProvider).where((w) => !w.archived).toList();
    final t = Theme.of(context);

    if (_walletId == null && wallets.isNotEmpty) {
      _walletId = wallets.first.id;
    }

    final categories = _type == TransactionType.income
        ? kDefaultIncomeCategories
        : kDefaultExpenseCategories;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
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
            const SizedBox(height: 14),
            Row(
              children: [
                _typeButton(
                    'Expense', TransactionType.expense, t.colorScheme.error),
                const SizedBox(width: 8),
                _typeButton(
                    'Income', TransactionType.income, t.colorScheme.primary),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₱ ',
              ),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            const Text('Category',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in categories)
                  CategoryChip(
                    label: c,
                    selected: _category == c,
                    onTap: () => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Wallet',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _walletId,
              decoration: const InputDecoration(),
              items: wallets
                  .map(
                      (w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                  .toList(),
              onChanged: (v) => setState(() => _walletId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(_date.toString().split(' ').first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(String label, TransactionType type, Color color) {
    final t = Theme.of(context);
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          _category = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : t.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? color : t.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt <= 0 || _walletId == null || _category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in amount, category, and wallet.')),
      );
      return;
    }
    final txn = Transaction(
      id: widget.initial?.id ?? _uuid.v4(),
      amount: amt,
      type: _type,
      category: _category!,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      date: _date,
      walletId: _walletId!,
      transferPairId: widget.initial?.transferPairId,
      autoCaptured: widget.initial?.autoCaptured ?? false,
    );
    ref.read(transactionListProvider.notifier).add(txn);
    Navigator.pop(context);
  }
}
