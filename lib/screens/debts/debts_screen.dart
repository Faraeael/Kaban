import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/debt.dart';
import '../../models/wallet.dart';
import '../../state/data_providers.dart';
import '../../state/settings_provider.dart';
import '../../utils/formatters.dart';
import 'widgets/debt_tile.dart';

const _uuid = Uuid();

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  double _extraPayment = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(debtListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final debts = ref.watch(debtListProvider);
    final calc = ref.watch(payoffCalculatorProvider);
    final strategy =
        ref.watch(settingsProvider.select((s) => s.defaultStrategy));

    final result = calc.simulate(
      debts: debts,
      extraMonthlyPayment: _extraPayment,
      strategy: strategy,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts'),
        actions: [
          PopupMenuButton<DebtStrategy>(
            tooltip: 'Change debt payoff strategy',
            icon: const Icon(Icons.tune_rounded),
            onSelected: (s) {
              final current = ref.read(settingsProvider);
              ref
                  .read(settingsProvider.notifier)
                  .update(current.copyWith(defaultStrategy: s));
            },
            itemBuilder: (_) => [
              for (final s in DebtStrategy.values)
                PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Icon(
                        s == strategy
                            ? Icons.check_rounded
                            : Icons.circle_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(s.label),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDebt(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add debt'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          final simulationPanel = Container(
            margin: EdgeInsets.fromLTRB(16, 8, isWide ? 8 : 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: t.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded,
                            size: 16, color: t.colorScheme.primary),
                        const SizedBox(width: 6),
                        const Text('Strategy',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        strategy.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: t.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Extra payment',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(
                      peso(_extraPayment),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _extraPayment > 0 ? t.colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Semantics(
                  label: 'Extra monthly payment: ${peso(_extraPayment)}',
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: _extraPayment,
                      min: 0,
                      max: 10000,
                      divisions: 100,
                      label: peso(_extraPayment),
                      onChanged: (v) => setState(() => _extraPayment = v),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _QuickAmountChip(
                        label: '+₱500',
                        semanticLabel: 'Add ₱500 extra payment',
                        onTap: () => setState(() => _extraPayment =
                            (_extraPayment + 500).clamp(0, 10000)),
                      ),
                      const SizedBox(width: 6),
                      _QuickAmountChip(
                        label: '+₱1,000',
                        semanticLabel: 'Add ₱1,000 extra payment',
                        onTap: () => setState(() => _extraPayment =
                            (_extraPayment + 1000).clamp(0, 10000)),
                      ),
                      const SizedBox(width: 6),
                      _QuickAmountChip(
                        label: '+₱2,500',
                        semanticLabel: 'Add ₱2,500 extra payment',
                        onTap: () => setState(() => _extraPayment =
                            (_extraPayment + 2500).clamp(0, 10000)),
                      ),
                      if (_extraPayment > 0) ...[
                        const SizedBox(width: 6),
                        _QuickAmountChip(
                          label: 'Reset',
                          semanticLabel: 'Reset extra payment to zero',
                          isReset: true,
                          onTap: () => setState(() => _extraPayment = 0),
                        ),
                      ],
                    ],
                  ),
                ),
                if (debts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  if (debts.every((d) => d.paidOff || d.balance <= 0))
                    Semantics(
                      label:
                          'All debts are fully settled and paid off! You are completely debt-free.',
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.colorScheme.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                t.colorScheme.primary.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.eco_rounded,
                                size: 24, color: t.colorScheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '100% Debt-Free! 🎉',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: t.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'All tracked loans and cards have been settled.',
                                    style: t.textTheme.bodySmall?.copyWith(
                                      color: t.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Semantics(
                      label:
                          'Payoff estimate: Debt-free in ${result.totalMonths} months. Total interest paid ${peso(result.totalInterestPaid)}.',
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.colorScheme.surface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Debt-free in',
                                      style: t.textTheme.labelSmall?.copyWith(
                                          color:
                                              t.colorScheme.onSurfaceVariant)),
                                  const SizedBox(height: 2),
                                  AnimatedSwitcher(
                                    duration:
                                        MediaQuery.of(context).disableAnimations
                                            ? Duration.zero
                                            : const Duration(milliseconds: 200),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeOutCubic,
                                    transitionBuilder: (child, animation) =>
                                        FadeTransition(
                                            opacity: animation, child: child),
                                    child: Text(
                                      '${result.totalMonths} months',
                                      key: ValueKey<int>(result.totalMonths),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: t.colorScheme.outlineVariant
                                  .withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total interest',
                                      style: t.textTheme.labelSmall?.copyWith(
                                          color:
                                              t.colorScheme.onSurfaceVariant)),
                                  const SizedBox(height: 2),
                                  AnimatedSwitcher(
                                    duration:
                                        MediaQuery.of(context).disableAnimations
                                            ? Duration.zero
                                            : const Duration(milliseconds: 200),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeOutCubic,
                                    transitionBuilder: (child, animation) =>
                                        FadeTransition(
                                            opacity: animation, child: child),
                                    child: Text(
                                      peso(result.totalInterestPaid),
                                      key: ValueKey<double>(
                                          result.totalInterestPaid),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: t.colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );

          final debtsList = debts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 56, color: t.colorScheme.outline),
                        const SizedBox(height: 14),
                        const Text('No debts tracked',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          'Add credit cards or loans to plan your payoff and simulate interest savings.',
                          style: t.textTheme.bodyMedium
                              ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => _showAddDebt(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add your first debt'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                      isWide ? 8 : 16, isWide ? 8 : 0, 16, 100),
                  itemCount: result.entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final e = result.entries[i];
                    return DebtTile(
                      debt: e.debt,
                      monthsToPayoff: e.monthsToPayoff,
                      interestPaid: e.interestPaid,
                      onTap: () => _showEditDebt(context, e.debt),
                    );
                  },
                );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    child: simulationPanel,
                  ),
                ),
                Expanded(
                  child: debtsList,
                ),
              ],
            );
          }

          return Column(
            children: [
              simulationPanel,
              Expanded(child: debtsList),
            ],
          );
        },
      ),
    );
  }

  void _showAddDebt(BuildContext context) {
    final wallets =
        ref.read(walletListProvider).where((w) => !w.archived).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DebtSheet(
        wallets: wallets,
        onSave: (d) {
          ref.read(debtListProvider.notifier).add(d);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditDebt(BuildContext context, Debt d) {
    final wallets =
        ref.read(walletListProvider).where((w) => !w.archived).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DebtSheet(
        initial: d,
        wallets: wallets,
        onSave: (next) {
          ref.read(debtListProvider.notifier).update(next);
          Navigator.pop(context);
        },
        onDelete: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (dialogCtx) => AlertDialog(
              title: Text('Delete "${d.name}"?'),
              content: const Text(
                  'This permanently removes this debt from your payoff plan. Cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('Delete Debt'),
                ),
              ],
            ),
          );
          if (ok == true && context.mounted) {
            ref.read(debtListProvider.notifier).delete(d.id);
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}

class _DebtSheet extends StatefulWidget {
  final Debt? initial;
  final List<Wallet> wallets;
  final void Function(Debt) onSave;
  final VoidCallback? onDelete;
  const _DebtSheet({
    this.initial,
    this.wallets = const [],
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends State<_DebtSheet> {
  late TextEditingController _name;
  late TextEditingController _balance;
  late TextEditingController _apr;
  late TextEditingController _min;
  late TextEditingController _remainingPayments;
  late TextEditingController _dueDay;
  late TextEditingController _billingDay;
  late TextEditingController _graceDays;
  late DebtSchedule _schedule;
  String? _linkedWalletId;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _linkedWalletId = init?.linkedWalletId;
    _name = TextEditingController(text: init?.name ?? '');

    String formatNum(double? val) {
      if (val == null) return '';
      return val % 1 == 0 ? val.toStringAsFixed(0) : val.toStringAsFixed(2);
    }

    _balance = TextEditingController(text: formatNum(init?.balance));
    _apr = TextEditingController(
        text: init?.apr != null
            ? (init!.apr % 1 == 0
                ? init.apr.toStringAsFixed(0)
                : init.apr.toStringAsFixed(1))
            : '');
    _min = TextEditingController(text: formatNum(init?.minPayment));
    _remainingPayments =
        TextEditingController(text: init?.remainingPayments?.toString() ?? '');
    _dueDay = TextEditingController(text: init?.dueDay?.toString() ?? '');
    _billingDay =
        TextEditingController(text: init?.billingDay?.toString() ?? '');
    _graceDays = TextEditingController(text: init?.graceDays?.toString() ?? '');
    _schedule = init?.schedule ?? DebtSchedule.none;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _apr.dispose();
    _min.dispose();
    _remainingPayments.dispose();
    _dueDay.dispose();
    _billingDay.dispose();
    _graceDays.dispose();
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
            Text(widget.initial == null ? 'Add debt' : 'Edit debt',
                style: t.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Name (e.g., MariLoan, BDO Card)')),
            const SizedBox(height: 10),
            TextField(
              controller: _balance,
              decoration:
                  const InputDecoration(labelText: 'Balance', prefixText: '₱ '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _apr,
              decoration:
                  const InputDecoration(labelText: 'APR (%)', suffixText: '%'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _min,
              decoration: const InputDecoration(
                  labelText: 'Minimum payment / month', prefixText: '₱ '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<DebtSchedule>(
              initialValue: _schedule,
              decoration:
                  const InputDecoration(labelText: 'Repayment schedule'),
              items: const [
                DropdownMenuItem(
                  value: DebtSchedule.none,
                  child: Text('No schedule'),
                ),
                DropdownMenuItem(
                  value: DebtSchedule.fixed,
                  child: Text('Fixed monthly loan'),
                ),
                DropdownMenuItem(
                  value: DebtSchedule.statementCycle,
                  child: Text('Statement cycle (credit card)'),
                ),
              ],
              onChanged: (s) {
                if (s != null) setState(() => _schedule = s);
              },
            ),
            if (_schedule == DebtSchedule.fixed) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _remainingPayments,
                      decoration: const InputDecoration(
                        labelText: 'Months remaining',
                        hintText: 'e.g. 9',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _dueDay,
                      decoration: const InputDecoration(
                        labelText: 'Due day of month',
                        hintText: '1–31',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
            if (_schedule == DebtSchedule.statementCycle) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _billingDay,
                      decoration: const InputDecoration(
                        labelText: 'Billing day',
                        hintText: '1–31',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _graceDays,
                      decoration: const InputDecoration(
                        labelText: 'Grace days',
                        hintText: 'e.g. 21',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
            if (widget.wallets.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: widget.wallets.any((w) => w.id == _linkedWalletId)
                    ? _linkedWalletId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Default payment wallet (optional)',
                  prefixIcon:
                      Icon(Icons.account_balance_wallet_outlined, size: 16),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None (ask each time)'),
                  ),
                  for (final w in widget.wallets)
                    DropdownMenuItem<String?>(
                      value: w.id,
                      child: Text(w.name),
                    ),
                ],
                onChanged: (v) => setState(() => _linkedWalletId = v),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                if (widget.initial != null)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: t.colorScheme.error),
                      onPressed: () {
                        widget.onDelete?.call();
                      },
                      child: const Text('Delete Debt'),
                    ),
                  ),
                if (widget.initial != null) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(
                        widget.initial != null ? 'Update Debt' : 'Add Debt'),
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
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a debt name.')),
      );
      return;
    }
    final balance = double.tryParse(_balance.text.replaceAll(',', '')) ?? 0;
    final apr = double.tryParse(_apr.text) ?? 0;
    final min = double.tryParse(_min.text.replaceAll(',', '')) ?? 0;
    final remaining = int.tryParse(_remainingPayments.text.trim());
    final due = int.tryParse(_dueDay.text.trim());
    final billing = int.tryParse(_billingDay.text.trim());
    final grace = int.tryParse(_graceDays.text.trim());

    final d = Debt(
      id: widget.initial?.id ?? _uuid.v4(),
      name: _name.text.trim(),
      balance: balance,
      apr: apr,
      minPayment: min,
      strategy: widget.initial?.strategy ?? DebtStrategy.avalanche,
      linkedWalletId: _linkedWalletId,
      schedule: _schedule,
      dueDay: _schedule == DebtSchedule.fixed ? due : null,
      remainingPayments: _schedule == DebtSchedule.fixed ? remaining : null,
      billingDay: _schedule == DebtSchedule.statementCycle ? billing : null,
      graceDays: _schedule == DebtSchedule.statementCycle ? grace : null,
      paidOff: (balance > 0) ? false : (widget.initial?.paidOff ?? false),
    );
    widget.onSave(d);
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final String? semanticLabel;
  final VoidCallback onTap;
  final bool isReset;

  const _QuickAmountChip({
    required this.label,
    this.semanticLabel,
    required this.onTap,
    this.isReset = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isReset
                ? t.colorScheme.error.withValues(alpha: 0.1)
                : t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isReset
                  ? t.colorScheme.error.withValues(alpha: 0.3)
                  : t.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isReset ? t.colorScheme.error : t.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
