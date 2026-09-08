import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/budget.dart';
import '../../models/goal.dart';
import '../../state/data_providers.dart';
import '../../utils/formatters.dart';

const _uuid = Uuid();

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _quincenaMode = false; // true = split month into 1st–15th / 16th–end

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(goalListProvider.notifier).load();
      ref.read(budgetListProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalListProvider);
    final budgets = ref.watch(budgetListProvider);
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Goals & Budgets'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.flag_outlined), text: 'Goals'),
            Tab(icon: Icon(Icons.donut_small_rounded), text: 'Budgets'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (ctx, _) {
          final isGoals = _tabController.index == 0;
          return FloatingActionButton.extended(
            onPressed: () =>
                isGoals ? _showAddGoal(context) : _showAddBudget(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(isGoals ? 'Add goal' : 'Add budget'),
          );
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _goalsTab(goals, t),
          _budgetsTab(budgets, t),
        ],
      ),
    );
  }

  Widget _goalsTab(List<Goal> goals, ThemeData t) {
    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag_outlined, size: 56, color: t.colorScheme.outline),
              const SizedBox(height: 12),
              const Text('No goals yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Set a savings target with a deadline to keep yourself on track.',
                style: t.textTheme.bodySmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _showAddGoal(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add goal'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: goals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final g = goals[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(g.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  if (g.deadline != null)
                    Text(
                      'by ${g.deadline!.year}-${g.deadline!.month.toString().padLeft(2, '0')}-${g.deadline!.day.toString().padLeft(2, '0')}',
                      style: t.textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: g.progress,
                  minHeight: 8,
                  backgroundColor: t.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(t.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(peso(g.saved),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(' / ${peso(g.target)}', style: t.textTheme.bodySmall),
                  const Spacer(),
                  Text('${(g.progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _budgetsTab(List<Budget> budgets, ThemeData t) {
    if (budgets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.donut_small_rounded,
                  size: 56, color: t.colorScheme.outline),
              const SizedBox(height: 12),
              const Text('No category budgets yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Cap monthly spending for Food, Transport, Bills, or shopping. '
                'The dashboard alerts you before you go over.',
                style: t.textTheme.bodySmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _showAddBudget(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add budget'),
              ),
            ],
          ),
        ),
      );
    }

    final txns = ref.watch(transactionListProvider);
    final now = DateTime.now();

    // ── Quincena date window ────────────────────────────────────────────────
    final DateTime windowStart;
    final DateTime windowEnd;
    final double limitMultiplier; // fraction of monthly limit to use

    if (_quincenaMode) {
      final cutoff = now.day <= 15 ? 15 : 31;
      windowStart = DateTime(now.year, now.month, 1);
      windowEnd = cutoff == 15
          ? DateTime(now.year, now.month, 15, 23, 59, 59)
          : DateTime(now.year, now.month + 1, 1)
              .subtract(const Duration(seconds: 1));
      limitMultiplier = 0.5;
    } else {
      windowStart = DateTime(now.year, now.month, 1);
      windowEnd = DateTime(now.year, now.month + 1, 1)
          .subtract(const Duration(seconds: 1));
      limitMultiplier = 1.0;
    }

    // Sum expenses by category inside the window
    Map<String, double> spent = {};
    for (final tx in txns) {
      if (tx.type.name != 'expense') continue;
      if (tx.date.isBefore(windowStart) || tx.date.isAfter(windowEnd)) continue;
      spent[tx.category] = (spent[tx.category] ?? 0) + tx.amount;
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: budgets.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == 0) {
          // ── Header row with Quincena toggle ────────────────────────────
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _quincenaMode
                        ? (now.day <= 15
                            ? 'Quincena 1 (1st – 15th)'
                            : 'Quincena 2 (16th – end)')
                        : 'Full month  •  tap ⚡ for quincena view',
                    style: t.textTheme.bodySmall,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _quincenaMode = !_quincenaMode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _quincenaMode
                          ? t.colorScheme.primaryContainer
                          : t.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _quincenaMode
                            ? t.colorScheme.primary.withValues(alpha: 0.5)
                            : t.colorScheme.outlineVariant
                                .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚡',
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          'Quincena',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _quincenaMode
                                ? t.colorScheme.onPrimaryContainer
                                : t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final b = budgets[i - 1];
        final effectiveLimit = b.monthlyLimit * limitMultiplier;
        final usedAmount = spent[b.category] ?? 0;
        final ratio = effectiveLimit > 0
            ? (usedAmount / effectiveLimit).clamp(0.0, 1.0)
            : 0.0;
        final isOver = usedAmount > effectiveLimit;
        final isWarning = ratio >= 0.8 && !isOver;

        final Color barColor;
        if (isOver) {
          barColor = t.colorScheme.error;
        } else if (isWarning) {
          barColor = Colors.orange.shade600;
        } else {
          barColor = t.colorScheme.primary;
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isOver
                ? t.colorScheme.errorContainer.withValues(alpha: 0.3)
                : t.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: isOver
                ? Border.all(
                    color: t.colorScheme.error.withValues(alpha: 0.4))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      b.category,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isOver ? t.colorScheme.error : null,
                      ),
                    ),
                  ),
                  if (isOver)
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: t.colorScheme.error),
                  const SizedBox(width: 4),
                  Text(
                    '${peso(usedAmount)} / ${peso(effectiveLimit)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isOver
                          ? t.colorScheme.error
                          : isWarning
                              ? Colors.orange.shade700
                              : t.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor:
                      t.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    isOver
                        ? '₱${(usedAmount - effectiveLimit).toStringAsFixed(0)} over budget'
                        : '₱${(effectiveLimit - usedAmount).toStringAsFixed(0)} remaining',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOver
                          ? t.colorScheme.error
                          : t.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(ratio * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddGoal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _GoalSheet(),
    );
  }

  void _showAddBudget(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BudgetSheet(),
    );
  }
}

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet();

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _saved = TextEditingController();
  DateTime? _deadline;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
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
            Text('Add goal',
                style: t.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(
              controller: _target,
              decoration:
                  const InputDecoration(labelText: 'Target', prefixText: '₱ '),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _saved,
              decoration: const InputDecoration(
                  labelText: 'Already saved', prefixText: '₱ '),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) setState(() => _deadline = picked);
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(_deadline == null
                        ? 'Pick deadline'
                        : 'Due ${_deadline!.toString().split(' ').first}'),
                  ),
                ),
              ],
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

  void _save() {
    final target = double.tryParse(_target.text) ?? 0;
    final saved = double.tryParse(_saved.text) ?? 0;
    if (_name.text.trim().isEmpty || target <= 0) return;
    final g = Goal(
      id: _uuid.v4(),
      name: _name.text.trim(),
      target: target,
      saved: saved,
      deadline: _deadline,
    );
    ref.read(goalListProvider.notifier).add(g);
    Navigator.pop(context);
  }
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet();

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  final _amount = TextEditingController();
  String _category = 'Food';

  @override
  void dispose() {
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
            Text('Add budget',
                style: t.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                'Food',
                'Transport',
                'Entertainment',
                'Shopping',
                'Utilities',
                'Health',
                'Subscriptions',
                'Other',
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? 'Other'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              decoration: const InputDecoration(
                  labelText: 'Monthly limit', prefixText: '₱ '),
              keyboardType: TextInputType.number,
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

  void _save() {
    final amt = double.tryParse(_amount.text) ?? 0;
    if (amt <= 0) return;
    final b = Budget(
      id: _uuid.v4(),
      category: _category,
      monthlyLimit: amt,
    );
    ref.read(budgetListProvider.notifier).upsert(b);
    Navigator.pop(context);
  }
}
