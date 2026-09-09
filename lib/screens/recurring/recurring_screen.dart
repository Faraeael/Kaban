import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/recurring_transaction.dart';
import '../../models/subscription.dart';
import '../../models/transaction.dart';
import '../../models/wallet.dart';
import '../../services/subscription_detector.dart';
import '../../state/data_providers.dart';
import '../../utils/formatters.dart';

const _uuid = Uuid();

class RecurringScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const RecurringScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recurringListProvider.notifier).load();
      ref.read(subscriptionListProvider.notifier).load();
      ref.read(transactionListProvider.notifier).load();
      ref.read(walletListProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final recurring = ref.watch(recurringListProvider);
    final subs = ref.watch(subscriptionListProvider);
    final wallets = ref.watch(walletListProvider);
    final activeWallets = wallets.where((w) => !w.archived).toList();
    final suggestions = ref.watch(subscriptionSuggestionsProvider);
    final totalMonthly =
        subs.fold<double>(0, (s, sub) => s + sub.monthlyEquivalent);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Recurring & Subscriptions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.autorenew_rounded), text: 'Recurring Bills'),
            Tab(icon: Icon(Icons.subscriptions_rounded), text: 'Subscriptions'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final isSubscriptions = _tabController.index == 1;
          return FloatingActionButton.extended(
            onPressed: () {
              if (isSubscriptions) {
                _showAddSubscriptionSheet(context);
              } else {
                _showAddRecurringSheet(context, activeWallets);
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(isSubscriptions ? 'Add subscription' : 'Add recurring'),
          );
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecurringTab(t, recurring, activeWallets),
          _buildSubscriptionsTab(t, subs, suggestions, totalMonthly),
        ],
      ),
    );
  }

  Widget _buildRecurringTab(
      ThemeData t, List<RecurringTransaction> recurring, List<Wallet> wallets) {
    if (recurring.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.autorenew_rounded,
                  size: 56, color: t.colorScheme.outline),
              const SizedBox(height: 12),
              const Text('No recurring transactions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Add your daily commute, work meals, or any repeat '
                'expense — the app logs it automatically when due.',
                textAlign: TextAlign.center,
                style: t.textTheme.bodySmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _showAddRecurringSheet(context, wallets),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add recurring'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: recurring.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final r = recurring[i];
        return _RecurringTile(
          recurring: r,
          onToggle: (enabled) => ref
              .read(recurringListProvider.notifier)
              .update(r.copyWith(enabled: enabled)),
          onTap: () => _showAddRecurringSheet(context, wallets, initial: r),
        );
      },
    );
  }

  Widget _buildSubscriptionsTab(ThemeData t, List<Subscription> subs,
      List<SubscriptionSuggestion> suggestions, double totalMonthly) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        if (subs.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.subscriptions_rounded, color: t.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly subscription cost',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(
                        peso(totalMonthly),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('Detected',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final s in suggestions.take(3))
            Card(
              child: ListTile(
                title: Text(s.merchant,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${s.occurrences} charges · ${peso(s.amount)} avg · day ${s.avgDayOfMonth} of month',
                ),
                trailing: FilledButton.tonal(
                  onPressed: () => _addFromSuggestion(s),
                  child: const Text('Track'),
                ),
              ),
            ),
          const SizedBox(height: 6),
        ],
        if (subs.isEmpty && suggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.subscriptions_outlined,
                    size: 56, color: t.colorScheme.outline),
                const SizedBox(height: 12),
                const Text('No subscriptions tracked yet',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Track Netflix, Spotify, cloud storage, postpaid plans, or gym memberships to see their total monthly impact.',
                  style: t.textTheme.bodySmall
                      ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _showAddSubscriptionSheet(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add subscription'),
                ),
              ],
            ),
          )
        else ...[
          const SizedBox(height: 14),
          const Text('Active',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final s in subs)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: t.colorScheme.secondaryContainer,
                  child: Icon(_iconFor(s.category), size: 18),
                ),
                title: Text(s.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${s.cadence.label} · next ${s.nextBillingDate.toString().split(' ').first}',
                ),
                trailing: Text(
                  peso(s.amount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onLongPress: () => _confirmDelete(s),
              ),
            ),
        ],
      ],
    );
  }

  IconData _iconFor(String cat) {
    switch (cat) {
      case 'Entertainment':
        return Icons.movie_rounded;
      case 'Utilities':
        return Icons.bolt_rounded;
      case 'Health':
        return Icons.favorite_rounded;
      default:
        return Icons.subscriptions_rounded;
    }
  }

  void _addFromSuggestion(SubscriptionSuggestion s) {
    final sub = Subscription(
      id: _uuid.v4(),
      name: s.merchant,
      amount: s.amount,
      cadence: Cadence.monthly,
      nextBillingDate:
          DateTime.now().add(Duration(days: 30 - DateTime.now().day)),
      category: s.category,
      walletId: '',
    );
    ref.read(subscriptionListProvider.notifier).add(sub);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tracking ${s.merchant}')),
    );
  }

  void _confirmDelete(Subscription s) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete subscription?'),
        content: Text('Stop tracking ${s.name}?'),
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
              ref.read(subscriptionListProvider.notifier).delete(s.id);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Delete Subscription'),
          ),
        ],
      ),
    );
  }

  void _showAddRecurringSheet(BuildContext context, List<Wallet> wallets,
      {RecurringTransaction? initial}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RecurringSheet(
        initial: initial,
        wallets: wallets,
        onSave: (r) {
          if (initial == null) {
            ref.read(recurringListProvider.notifier).add(r);
          } else {
            ref.read(recurringListProvider.notifier).update(r);
          }
          Navigator.pop(context);
        },
        onDelete: initial == null
            ? null
            : () {
                ref.read(recurringListProvider.notifier).delete(initial.id);
                Navigator.pop(context);
              },
      ),
    );
  }

  void _showAddSubscriptionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AddSubscriptionSheet(),
    );
  }
}

class _RecurringTile extends StatelessWidget {
  final RecurringTransaction recurring;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  const _RecurringTile({
    required this.recurring,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isExpense = recurring.type == TransactionType.expense;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              recurring.type == TransactionType.income
                  ? Icons.trending_up_rounded
                  : Icons.autorenew_rounded,
              color: isExpense ? t.colorScheme.error : t.colorScheme.primary,
              size: 22,
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
                          recurring.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        peso(recurring.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isExpense
                              ? t.colorScheme.error
                              : t.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${recurring.category} · ${recurring.frequencyLabel} · '
                    'next ${shortDate(recurring.nextDue)}',
                    style: t.textTheme.bodySmall
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Switch(
              value: recurring.enabled,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringSheet extends StatefulWidget {
  final RecurringTransaction? initial;
  final List<Wallet> wallets;
  final void Function(RecurringTransaction) onSave;
  final VoidCallback? onDelete;
  const _RecurringSheet({
    this.initial,
    required this.wallets,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends State<_RecurringSheet> {
  late TextEditingController _name;
  late TextEditingController _amount;
  late TransactionType _type;
  late String _category;
  late int _intervalDays;
  late String? _walletId;

  static const _frequencies = {
    'Daily': 1,
    'Weekly': 7,
    'Every 2 weeks': 14,
    'Monthly': 30,
  };

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _amount = TextEditingController(
        text: widget.initial?.amount.toStringAsFixed(0) ?? '');
    _type = widget.initial?.type ?? TransactionType.expense;
    _category = widget.initial?.category ?? 'Transport';
    _intervalDays = widget.initial?.intervalDays ?? 1;
    final wallets = widget.wallets;
    _walletId =
        widget.initial?.walletId ?? (wallets.isEmpty ? null : wallets.first.id);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.initial == null ? 'Add recurring' : 'Edit recurring',
                style: t.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
                controller: _name,
                decoration:
                    const InputDecoration(labelText: 'Name (e.g., Commute)')),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              decoration:
                  const InputDecoration(labelText: 'Amount', prefixText: '₱ '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Expense'),
                        icon: Icon(Icons.trending_down_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Income'),
                        icon: Icon(Icons.trending_up_rounded, size: 16),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) {
                      final newType = s.first;
                      setState(() {
                        _type = newType;
                        _category = newType == TransactionType.income
                            ? kDefaultIncomeCategories.first
                            : kDefaultExpenseCategories.first;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final categories = _type == TransactionType.income
                    ? kDefaultIncomeCategories
                    : kDefaultExpenseCategories;
                final selectedCat = categories.contains(_category)
                    ? _category
                    : categories.first;
                return DropdownButtonFormField<String>(
                  key: ValueKey(_type),
                  initialValue: selectedCat,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _category = v ?? categories.first),
                );
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _intervalDays,
              decoration: const InputDecoration(labelText: 'Repeats'),
              items: _frequencies.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.value, child: Text(e.key)))
                  .toList(),
              onChanged: (v) => setState(() => _intervalDays = v ?? 1),
            ),
            const SizedBox(height: 10),
            if (widget.wallets.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _walletId,
                decoration: const InputDecoration(labelText: 'Wallet'),
                items: widget.wallets
                    .map<DropdownMenuItem<String>>((w) =>
                        DropdownMenuItem(value: w.id, child: Text(w.name)))
                    .toList(),
                onChanged: (v) => setState(() => _walletId = v),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (widget.onDelete != null)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: t.colorScheme.error),
                      onPressed: widget.onDelete,
                      child: const Text('Delete Recurring'),
                    ),
                  ),
                if (widget.onDelete != null) const SizedBox(width: 12),
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
                    child: Text(widget.initial == null
                        ? 'Add Recurring'
                        : 'Update Recurring'),
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
    final amt = double.tryParse(_amount.text) ?? 0;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recurring bill name.')),
      );
      return;
    }
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter an amount greater than ₱0.')),
      );
      return;
    }
    if (_walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a wallet.')),
      );
      return;
    }
    final r = RecurringTransaction(
      id: widget.initial?.id ?? _uuid.v4(),
      name: _name.text.trim(),
      amount: amt,
      type: _type,
      category: _category,
      intervalDays: _intervalDays,
      nextDue: widget.initial?.nextDue ?? DateTime.now(),
      walletId: _walletId!,
      enabled: widget.initial?.enabled ?? true,
    );
    widget.onSave(r);
  }
}

class _AddSubscriptionSheet extends ConsumerStatefulWidget {
  const _AddSubscriptionSheet();

  @override
  ConsumerState<_AddSubscriptionSheet> createState() =>
      _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends ConsumerState<_AddSubscriptionSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  Cadence _cadence = Cadence.monthly;
  final DateTime _next = DateTime.now().add(const Duration(days: 30));
  String _category = 'Entertainment';
  String? _walletId;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallets =
        ref.watch(walletListProvider).where((w) => !w.archived).toList();
    if (_walletId == null && wallets.isNotEmpty) {
      _walletId = wallets.first.id;
    }
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add subscription',
                style: t.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              decoration:
                  const InputDecoration(labelText: 'Amount', prefixText: '₱ '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<Cadence>(
              initialValue: _cadence,
              decoration: const InputDecoration(labelText: 'Cadence'),
              items: Cadence.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) => setState(() => _cadence = v ?? Cadence.monthly),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                'Entertainment',
                'Utilities',
                'Health',
                'Software',
                'Other'
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? 'Other'),
            ),
            const SizedBox(height: 10),
            if (wallets.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _walletId,
                decoration: const InputDecoration(labelText: 'Wallet'),
                items: wallets
                    .map((w) =>
                        DropdownMenuItem(value: w.id, child: Text(w.name)))
                    .toList(),
                onChanged: (v) => setState(() => _walletId = v),
              ),
            const SizedBox(height: 14),
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
                    child: const Text('Save Subscription'),
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
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a subscription name.')),
      );
      return;
    }
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter an amount greater than ₱0.')),
      );
      return;
    }
    if (_walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a wallet.')),
      );
      return;
    }
    final sub = Subscription(
      id: _uuid.v4(),
      name: _name.text.trim(),
      amount: amt,
      cadence: _cadence,
      nextBillingDate: _next,
      category: _category,
      walletId: _walletId!,
    );
    ref.read(subscriptionListProvider.notifier).add(sub);
    Navigator.pop(context);
  }
}
