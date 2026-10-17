import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/transaction.dart';
import '../../models/wallet.dart';
import '../../state/data_providers.dart';
import '../../utils/formatters.dart';
import 'add_transaction_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  final String? initialWalletId;
  final String? initialCategory;
  const TransactionsScreen({
    super.key,
    this.initialWalletId,
    this.initialCategory,
  });

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  DateTime _filterMonth = DateTime.now();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedWalletId;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialWalletId;
    _selectedCategory = widget.initialCategory;
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionListProvider.notifier).load();
      ref.read(walletListProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final txns = ref.watch(transactionListProvider);
    final wallets = ref.watch(walletListProvider);
    final walletMap = {for (final w in wallets) w.id: w};

    final start = DateTime(_filterMonth.year, _filterMonth.month, 1);
    final end = DateTime(_filterMonth.year, _filterMonth.month + 1, 1);
    final queryLower = _searchQuery.toLowerCase();

    final filtered = txns.where((t) {
      // Month window
      if (t.date.isBefore(start) || !t.date.isBefore(end)) return false;
      // Wallet filter
      if (_selectedWalletId != null && t.walletId != _selectedWalletId) {
        return false;
      }
      // Category filter
      if (_selectedCategory != null && t.category != _selectedCategory) {
        return false;
      }
      // Search query (matches note, category, or amount)
      if (queryLower.isNotEmpty) {
        final noteMatch = t.note?.toLowerCase().contains(queryLower) ?? false;
        final catMatch = t.category.toLowerCase().contains(queryLower);
        final amtMatch = t.amount.toString().contains(queryLower) ||
            t.amount.toStringAsFixed(0).contains(queryLower);
        if (!noteMatch && !catMatch && !amtMatch) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    double monthInflow = 0;
    double monthOutflow = 0;
    for (final t in filtered) {
      if (t.type == TransactionType.income) {
        monthInflow += t.amount;
      } else if (t.type == TransactionType.expense) {
        monthOutflow += t.amount;
      }
    }

    final grouped = <String, List<Transaction>>{};
    for (final t in filtered) {
      final key = shortDate(t.date);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final groupKeys = grouped.keys.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Transfer',
            onPressed: () => context.push('/transactions/transfer'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAdd(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add transaction'),
      ),
      body: Column(
        children: [
          // ── Search Bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search note, merchant, or amount...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Filter Chips (Wallet & Category) ─────────────────────────
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_selectedWalletId != null ||
                    _selectedCategory != null ||
                    _searchQuery.isNotEmpty) ...[
                  ActionChip(
                    avatar: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text('Reset filters',
                        style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedWalletId = null;
                        _selectedCategory = null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                // Wallet Filter Dropdown Chip
                PopupMenuButton<String?>(
                  tooltip: 'Filter by wallet',
                  initialValue: _selectedWalletId,
                  onSelected: (wId) => setState(() => _selectedWalletId = wId),
                  itemBuilder: (_) => [
                    const PopupMenuItem<String?>(
                      value: null,
                      child: Text('All Wallets'),
                    ),
                    for (final w in wallets)
                      PopupMenuItem<String?>(
                        value: w.id,
                        child: Row(
                          children: [
                            Text(w.name),
                            if (w.id == _selectedWalletId) ...[
                              const Spacer(),
                              const Icon(Icons.check_rounded, size: 16),
                            ],
                          ],
                        ),
                      ),
                  ],
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 14,
                      color: _selectedWalletId != null
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    label: Text(
                      _selectedWalletId != null
                          ? (walletMap[_selectedWalletId]?.name ?? 'Wallet')
                          : 'All Wallets',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _selectedWalletId != null
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedWalletId != null
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    deleteIcon: _selectedWalletId != null
                        ? const Icon(Icons.close_rounded, size: 14)
                        : null,
                    onDeleted: _selectedWalletId != null
                        ? () => setState(() => _selectedWalletId = null)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                // Category Filter Dropdown Chip
                PopupMenuButton<String?>(
                  tooltip: 'Filter by category',
                  initialValue: _selectedCategory,
                  onSelected: (cat) => setState(() => _selectedCategory = cat),
                  itemBuilder: (_) {
                    final existingCategories = txns
                        .where((t) => t.date.isAfter(start) && t.date.isBefore(end))
                        .map((t) => t.category)
                        .toSet()
                        .toList()
                      ..sort();
                    return [
                      const PopupMenuItem<String?>(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      for (final c in existingCategories)
                        PopupMenuItem<String?>(
                          value: c,
                          child: Row(
                            children: [
                              Text(c),
                              if (c == _selectedCategory) ...[
                                const Spacer(),
                                const Icon(Icons.check_rounded, size: 16),
                              ],
                            ],
                          ),
                        ),
                    ];
                  },
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      Icons.category_outlined,
                      size: 14,
                      color: _selectedCategory != null
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    label: Text(
                      _selectedCategory ?? 'All Categories',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _selectedCategory != null
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedCategory != null
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    deleteIcon: _selectedCategory != null
                        ? const Icon(Icons.close_rounded, size: 14)
                        : null,
                    onDeleted: _selectedCategory != null
                        ? () => setState(() => _selectedCategory = null)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // ── Month Selector ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    _filterMonth =
                        DateTime(_filterMonth.year, _filterMonth.month - 1, 1);
                  }),
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  monthLabel(_filterMonth),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                IconButton(
                  onPressed: () {
                    final next =
                        DateTime(_filterMonth.year, _filterMonth.month + 1, 1);
                    if (!next.isAfter(
                        DateTime.now().add(const Duration(days: 31)))) {
                      setState(() => _filterMonth = next);
                    }
                  },
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Semantics(
              label:
                  'Monthly cashflow for ${monthLabel(_filterMonth)}: Inflow ${peso(monthInflow)}, Outflow ${peso(monthOutflow)}',
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'In: ${peso(monthInflow)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.4),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Out: ${peso(monthOutflow)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 56,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No transactions this month',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap the button below to log your expenses and income for ${monthLabel(_filterMonth)}.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () => _showAdd(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add transaction'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: groupKeys.length,
                    itemBuilder: (_, i) {
                      final key = groupKeys[i];
                      final list = grouped[key]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...list.map((t) => _TransactionRow(
                                txn: t,
                                wallet: walletMap[t.walletId],
                                onTap: () => _showDetails(
                                    context, t, walletMap[t.walletId]),
                                onLongPress: () => _confirmDelete(context, t),
                              )),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddTransactionSheet(),
    );
  }

  void _showDetails(BuildContext context, Transaction t, Wallet? wallet) {
    final theme = Theme.of(context);
    final isIncome = t.type == TransactionType.income;
    final isTransfer = t.type == TransactionType.transfer;
    final isTransferIn = isTransfer && t.category == 'Transfer In';
    final color = isTransfer
        ? theme.colorScheme.tertiary
        : (isIncome ? theme.colorScheme.primary : theme.colorScheme.error);
    final prefix = (isIncome || isTransferIn) ? '+' : '−';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isTransfer
                        ? Icons.swap_horiz_rounded
                        : (isIncome
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.category,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        wallet?.name ?? 'Unknown Wallet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$prefix ${pesoExact(t.amount)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Date & Time',
              value:
                  '${shortDate(t.date)} at ${TimeOfDay.fromDateTime(t.date).format(context)}',
            ),
            if (t.note != null && t.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailRow(label: 'Note', value: t.note!),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _confirmDelete(context, t);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ),
                if (!isTransfer) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => AddTransactionSheet(initial: t),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Transaction t) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(t.type == TransactionType.transfer
            ? 'This will reverse both halves of the transfer.'
            : 'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              if (t.transferPairId != null) {
                ref
                    .read(transactionListProvider.notifier)
                    .deleteTransferPair(t.transferPairId!);
              } else {
                ref.read(transactionListProvider.notifier).delete(t.id);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Delete Transaction'),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Transaction txn;
  final Wallet? wallet;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;
  const _TransactionRow({
    required this.txn,
    required this.wallet,
    this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isIncome = txn.type == TransactionType.income;
    final isTransfer = txn.type == TransactionType.transfer;
    final isTransferIn = isTransfer && txn.category == 'Transfer In';
    final color = isTransfer
        ? t.colorScheme.tertiary
        : (isIncome ? t.colorScheme.primary : t.colorScheme.error);
    final prefix = (isIncome || isTransferIn) ? '+' : '−';
    final semanticType =
        isTransfer ? 'Transfer' : (isIncome ? 'Income' : 'Expense');
    final semanticLabel =
        '$semanticType: ${txn.category}, ${pesoExact(txn.amount)}, ${wallet?.name ?? "Unknown wallet"}${txn.note != null && txn.note!.isNotEmpty ? ", note: ${txn.note}" : ""}';

    return Semantics(
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isTransfer
                      ? Icons.swap_horiz_rounded
                      : (isIncome
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.category,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        wallet?.name ?? 'Unknown',
                        if (txn.note != null) txn.note!,
                      ].join(' • '),
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '$prefix ${pesoExact(txn.amount)}',
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: t.textTheme.bodySmall
                ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
