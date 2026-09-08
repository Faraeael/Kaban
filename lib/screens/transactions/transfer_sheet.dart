import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/transaction.dart';
import '../../state/data_providers.dart';

const _uuid = Uuid();

class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key});

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  String? _fromId;
  String? _toId;
  final _amount = TextEditingController();
  final _note = TextEditingController();

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

    if (_fromId == null && wallets.isNotEmpty) _fromId = wallets.first.id;
    if (_toId == null && wallets.length > 1) _toId = wallets[1].id;

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
            Text(
              'Transfer between wallets',
              style:
                  t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Net worth stays the same. Both balances adjust.',
              style: t.textTheme.bodySmall
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            const Text('From',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _fromId,
              items: wallets
                  .map(
                      (w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                  .toList(),
              onChanged: (v) => setState(() => _fromId = v),
            ),
            const SizedBox(height: 12),
            const Text('To',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _toId,
              items: wallets
                  .where((w) => w.id != _fromId)
                  .map(
                      (w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                  .toList(),
              onChanged: (v) => setState(() => _toId = v),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Amount', prefixText: '₱ '),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 16),
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
                    child: const Text('Transfer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt <= 0 || _fromId == null || _toId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter an amount and choose both wallets.')),
      );
      return;
    }
    if (_fromId == _toId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source and destination must differ.')),
      );
      return;
    }
    final wallets = ref.read(walletListProvider);
    final fromWallet = wallets.where((w) => w.id == _fromId).firstOrNull;
    final toWallet = wallets.where((w) => w.id == _toId).firstOrNull;
    final userNote = _note.text.trim();
    final fromNote = userNote.isNotEmpty
        ? userNote
        : (toWallet != null ? 'Transfer to ${toWallet.name}' : null);
    final toNote = userNote.isNotEmpty
        ? userNote
        : (fromWallet != null ? 'Transfer from ${fromWallet.name}' : null);

    final pairId = _uuid.v4();
    final now = DateTime.now();
    final txns = [
      Transaction(
        id: _uuid.v4(),
        amount: amt,
        type: TransactionType.transfer,
        category: 'Transfer Out',
        note: fromNote,
        date: now,
        walletId: _fromId!,
        transferPairId: pairId,
      ),
      Transaction(
        id: _uuid.v4(),
        amount: amt,
        type: TransactionType.transfer,
        category: 'Transfer In',
        note: toNote,
        date: now,
        walletId: _toId!,
        transferPairId: pairId,
      ),
    ];
    ref.read(transactionListProvider.notifier).addMany(txns);
    Navigator.pop(context);
  }
}
