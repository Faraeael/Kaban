import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_message.dart';
import '../../models/debt.dart';
import '../../models/goal.dart';
import '../../models/transaction.dart';
import '../../models/wallet.dart';
import '../../services/ai/ai_provider_config.dart';
import '../../services/ai/coach_service.dart';
import '../../services/coach_actions.dart';
import '../../state/data_providers.dart';
import '../../state/settings_provider.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/suggested_prompts.dart';
import '../../utils/formatters.dart';

const _uuid = Uuid();

/// In-flight coach session state, lifted out of the widget so it survives
/// tab switches (the ShellRoute disposes the screen's element when it is not
/// the active tab). Chat messages themselves are persisted in the DB; only
/// this transient UI state (busy flag, error, pending action cards, and the
/// in-flight AI request) needs to live at the provider layer.
class _CoachSession {
  bool busy = false;
  String? error;
  String draftText = '';
  final pendingActions = <String, List<CoachAction>>{};
  final pendingWarnings = <String, List<String>>{};
  final selectedWallets = <String, String>{};
  final recentlyCreatedDebtNames = <String>{};
  Future<void>? inFlight;
}

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _parser = CoachActionParser();
  // Eager initial state: never write to this provider during build. The
  // session object itself is mutated in place (and repainted via setState),
  // so the provider is only a place to hold the object across tab switches.
  static final _sessionProvider =
      StateProvider<_CoachSession>((_) => _CoachSession());
  _CoachSession get _session => ref.read(_sessionProvider);

  bool _didInitialScroll = false;
  XFile? _attachedImage;
  Uint8List? _attachedImageBytes;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _attachedImage = picked;
          _attachedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo / Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery / Screenshot'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom({bool animate = true, bool checkCards = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      final target = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
      if (checkCards) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted &&
              _scroll.hasClients &&
              _scroll.position.maxScrollExtent > target) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final draft = _session.draftText;
    if (draft.isNotEmpty) {
      _input.text = draft;
      _input.selection = TextSelection.fromPosition(
        TextPosition(offset: draft.length),
      );
    }
    _input.addListener(_onInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatListProvider.notifier).load();
    });
  }

  void _onInputChanged() {
    _session.draftText = _input.text;
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  FinanceSnapshot _buildSnapshot() {
    final wallets = ref.read(walletListProvider);
    final balances = ref.read(walletBalancesProvider);
    final walletNameBalances = <String, double>{
      for (final w in wallets)
        if (!w.archived) w.name: balances[w.id] ?? w.startingBalance,
    };
    final debts = ref.read(debtListProvider);
    final month = ref.read(monthSummaryProvider);
    final settings = ref.read(settingsProvider);

    return FinanceSnapshot(
      walletBalances: walletNameBalances,
      totalDebt: debts.fold(0, (s, d) => s + d.balance),
      monthIncome: month.income,
      monthExpense: month.expense,
      monthExpenseByCategory: month.byCategory,
      debts: debts
          .map((d) => DebtSnapshot(
                id: d.id,
                name: d.name,
                balance: d.balance,
                apr: d.apr,
                minPayment: d.minPayment,
                strategy: d.strategy.shortLabel,
                schedule: d.schedule.name,
                dueDay: d.dueDay,
                remainingPayments: d.remainingPayments,
                paidOff: d.paidOff,
                billingDay: d.billingDay,
                graceDays: d.graceDays,
              ))
          .toList(),
      suggestions: [
        if (wallets.isEmpty) 'Add a wallet to get started.',
        if (debts.isNotEmpty) 'You have ${debts.length} debt(s) tracked.',
        if (settings.aiProvider != AIProvider.local)
          'Enable "Allow remote AI" in Settings for richer answers.',
      ],
      remoteConfigured: settings.aiProvider != AIProvider.local,
    );
  }

  Future<void> _applyAction(String messageId, CoachAction action) async {
    final selectedWalletId = _session.selectedWallets[messageId];
    switch (action) {
      case LogTransactionAction a:
        final wallets = ref.read(walletListProvider);
        final vis = wallets.where((w) => !w.archived).toList();
        final wallet = selectedWalletId != null
            ? (vis.where((w) => w.id == selectedWalletId).firstOrNull ??
                vis.firstOrNull)
            : (a.walletName != null
                ? (vis.where((w) {
                      final q = a.walletName!.trim().toLowerCase();
                      final name = w.name.toLowerCase();
                      return name == q || name.contains(q);
                    }).firstOrNull ??
                    vis.firstOrNull)
                : vis.firstOrNull);
        if (wallet == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Add a wallet first, then log the transaction.')),
          );
          return;
        }
        final txn = Transaction(
          id: _uuid.v4(),
          amount: a.amount,
          type: a.isIncome ? TransactionType.income : TransactionType.expense,
          category: a.category,
          note: a.note,
          date: DateTime.now(),
          walletId: wallet.id,
        );
        await ref.read(transactionListProvider.notifier).add(txn);
      case UpdateDebtBalanceAction a:
        final debts = ref.read(debtListProvider);
        final query = a.debtName.trim().toLowerCase();
        Debt? target;
        for (final d in debts) {
          if (d.name.toLowerCase() == query ||
              d.name.toLowerCase().contains(query)) {
            target = d;
            break;
          }
        }
        if (target == null) {
          // C3 fix: never silently substitute another debt. If the user said
          // "pay my BDO card" and there's no BDO debt, ask them what to do.
          if (debts.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Add a debt first, then update its balance.')),
            );
          } else {
            final names = debts.map((d) => d.name).join(', ');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('No debt named "${a.debtName}". You have: $names.')),
            );
          }
          return;
        }
        final debt = target;
        var next = debt.copyWith(
          balance: (debt.balance - a.amount).clamp(0, double.infinity),
        );
        if (debt.schedule == DebtSchedule.fixed) {
          final current = debt.remainingPayments ?? 1;
          final remaining = (current - 1).clamp(0, 9999);
          if (remaining == 0) {
            next = next.copyWith(
              paidOff: true,
              schedule: DebtSchedule.none,
              clearDueDay: true,
              clearRemainingPayments: true,
            );
          } else {
            next = next.copyWith(remainingPayments: remaining);
          }
        }
        await ref.read(debtListProvider.notifier).update(next);
        final wallets = ref.read(walletListProvider);
        final vis = wallets.where((w) => !w.archived).toList();
        final payingWallet = selectedWalletId != null
            ? vis.where((w) => w.id == selectedWalletId).firstOrNull
            : (debt.linkedWalletId != null
                ? vis.where((w) => w.id == debt.linkedWalletId).firstOrNull
                : (a.walletName != null
                    ? (vis.where((w) {
                          final q = a.walletName!.trim().toLowerCase();
                          return w.name.toLowerCase() == q ||
                              w.name.toLowerCase().contains(q);
                        }).firstOrNull ??
                        vis.firstOrNull)
                    : vis.firstOrNull));
        if (payingWallet != null) {
          final txn = Transaction(
            id: _uuid.v4(),
            amount: a.amount,
            type: TransactionType.expense,
            category: 'Debt Payment',
            note: 'Payment to ${debt.name}',
            date: DateTime.now(),
            walletId: payingWallet.id,
          );
          await ref.read(transactionListProvider.notifier).add(txn);
        }
      case UpdateDebtAction a:
        final debts = ref.read(debtListProvider);
        final query = a.name.trim().toLowerCase();
        final target = debts
            .where((d) =>
                d.name.toLowerCase() == query ||
                d.name.toLowerCase().contains(query))
            .firstOrNull;
        if (target == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No debt named "${a.name}".')),
          );
          return;
        }
        final updated = target.copyWith(
          name: a.newName ?? target.name,
          balance: a.newBalance ?? target.balance,
          paidOff: (a.newBalance != null && a.newBalance! > 0)
              ? false
              : target.paidOff,
          apr: a.newApr ?? target.apr,
          minPayment: a.newMinPayment ?? target.minPayment,
          schedule: a.newSchedule ?? target.schedule,
          dueDay: a.newDueDay ?? target.dueDay,
          remainingPayments: a.newRemainingPayments ?? target.remainingPayments,
          billingDay: a.newBillingDay ?? target.billingDay,
          graceDays: a.newGraceDays ?? target.graceDays,
        );
        await ref.read(debtListProvider.notifier).update(updated);
      case DeleteDebtAction a:
        final debts = ref.read(debtListProvider);
        final query = a.name.trim().toLowerCase();
        final target = debts
            .where((d) =>
                d.name.toLowerCase() == query ||
                d.name.toLowerCase().contains(query))
            .firstOrNull;
        if (target == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No debt named "${a.name}".')),
          );
          return;
        }
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('Delete "${target.name}"?'),
            content: const Text('This removes this debt. Cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok ?? false) {
          await ref.read(debtListProvider.notifier).delete(target.id);
        } else {
          return;
        }
      case AddToGoalAction a:
        final goals = ref.read(goalListProvider);
        final query = a.goalName.trim().toLowerCase();
        Goal? target;
        for (final g in goals) {
          if (g.name.toLowerCase() == query ||
              g.name.toLowerCase().contains(query)) {
            target = g;
            break;
          }
        }
        if (target == null) {
          if (goals.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Add a goal first, then add to it.')),
            );
          } else {
            final names = goals.map((g) => g.name).join(', ');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('No goal named "${a.goalName}". You have: $names.')),
            );
          }
          return;
        }
        final next = target.copyWith(saved: target.saved + a.amount);
        await ref.read(goalListProvider.notifier).update(next);
        if (selectedWalletId != null) {
          final wallets = ref.read(walletListProvider);
          final wallet =
              wallets.where((w) => w.id == selectedWalletId).firstOrNull;
          if (wallet != null) {
            final txn = Transaction(
              id: _uuid.v4(),
              amount: a.amount,
              type: TransactionType.expense,
              category: 'Other',
              note: 'Contribution to ${target.name}',
              date: DateTime.now(),
              walletId: wallet.id,
            );
            await ref.read(transactionListProvider.notifier).add(txn);
          }
        }
      case CreateDebtAction a:
        await ref.read(debtListProvider.notifier).add(a.debt);
        _session.recentlyCreatedDebtNames.add(a.debt.name.toLowerCase().trim());
      case CreateGoalAction a:
        await ref.read(goalListProvider.notifier).add(a.goal);
      case UpdateGoalAction a:
        final goals = ref.read(goalListProvider);
        final query = a.name.trim().toLowerCase();
        final target = goals
            .where((g) =>
                g.name.toLowerCase() == query ||
                g.name.toLowerCase().contains(query))
            .firstOrNull;
        if (target == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No goal named "${a.name}".')),
          );
          return;
        }
        final updated = target.copyWith(
          name: a.newName ?? target.name,
          target: a.newTarget ?? target.target,
          saved: a.newSaved ?? target.saved,
        );
        await ref.read(goalListProvider.notifier).update(updated);
      case DeleteGoalAction a:
        final goals = ref.read(goalListProvider);
        final query = a.name.trim().toLowerCase();
        final target = goals
            .where((g) =>
                g.name.toLowerCase() == query ||
                g.name.toLowerCase().contains(query))
            .firstOrNull;
        if (target == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No goal named "${a.name}".')),
          );
          return;
        }
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('Delete "${target.name}"?'),
            content: const Text('This removes this goal. Cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok ?? false) {
          await ref.read(goalListProvider.notifier).delete(target.id);
        } else {
          return;
        }
      case CreateRecurringAction a:
        final wallets = ref.read(walletListProvider);
        final vis = wallets.where((w) => !w.archived).toList();
        if (vis.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Add a wallet first, then create the recurring entry.')),
          );
          return;
        }
        final wallet = selectedWalletId != null
            ? (vis.where((w) => w.id == selectedWalletId).firstOrNull ??
                vis.first)
            : vis.first;
        final entry = a.recurring.copyWith(
          id: _uuid.v4(),
          walletId: wallet.id,
          nextDue: DateTime.now(),
        );
        await ref.read(recurringListProvider.notifier).add(entry);
      case UpdateRecurringAction a:
        final recurring = ref.read(recurringListProvider);
        final query = a.name.trim().toLowerCase();
        final target = recurring
            .where((r) =>
                r.name.toLowerCase() == query ||
                r.name.toLowerCase().contains(query))
            .firstOrNull;
        if (target == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('No recurring transaction named "${a.name}".')),
          );
          return;
        }
        if (a.delete) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (dialogCtx) => AlertDialog(
              title: Text('Delete "${target.name}"?'),
              content: const Text(
                  'This removes this recurring transaction. Cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (ok ?? false) {
            await ref.read(recurringListProvider.notifier).delete(target.id);
          } else {
            return;
          }
        } else {
          int? intervalDays;
          if (a.newFrequency != null) {
            intervalDays = switch (a.newFrequency!.toLowerCase()) {
              'day' || 'daily' => 1,
              'week' || 'weekly' => 7,
              'bi-weekly' || 'biweekly' || 'fortnight' => 14,
              'year' || 'yearly' => 365,
              _ => 30,
            };
          }
          final updated = target.copyWith(
            amount: a.newAmount ?? target.amount,
            intervalDays: intervalDays ?? target.intervalDays,
            enabled: a.newEnabled ?? target.enabled,
          );
          await ref.read(recurringListProvider.notifier).update(updated);
        }
      case CreateWalletAction a:
        WalletPreset? preset;
        for (final p in kWalletPresets) {
          if (p.name.toLowerCase() == a.name.toLowerCase()) {
            preset = p;
            break;
          }
        }
        final Wallet wallet;
        if (preset != null) {
          wallet = preset.toWallet(_uuid.v4());
        } else {
          final type = a.name.toLowerCase().contains('card')
              ? WalletType.credit
              : WalletType.ewallet;
          wallet = Wallet(
            id: _uuid.v4(),
            name: a.name,
            type: type,
            startingBalance: a.startingBalance,
            colorValue: type == WalletType.credit ? 0xFF7C3AED : 0xFF0D9488,
            logoAsset: type == WalletType.credit
                ? 'assets/logos/credit_card.svg'
                : 'assets/logos/cash.svg',
          );
        }
        final saved = a.startingBalance > 0
            ? wallet.copyWith(startingBalance: a.startingBalance)
            : wallet;
        await ref.read(walletListProvider.notifier).add(saved);
      case UpdateWalletAction a:
        final wallets = ref.read(walletListProvider);
        final query = a.name.trim().toLowerCase();
        final target = wallets
            .where((w) =>
                w.name.toLowerCase() == query ||
                w.name.toLowerCase().contains(query))
            .firstOrNull;
        if (target == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No wallet named "${a.name}".')),
          );
          return;
        }
        final updated = target.copyWith(
          name: a.newName ?? target.name,
          startingBalance: a.newStartingBalance ?? target.startingBalance,
          archived: a.unarchive ? false : target.archived,
        );
        await ref.read(walletListProvider.notifier).update(updated);
      case ArchiveWalletAction a:
        final wallets = ref.read(walletListProvider);
        final query = a.name.trim().toLowerCase();
        final target = wallets
            .where((w) =>
                w.name.toLowerCase() == query ||
                w.name.toLowerCase().contains(query))
            .firstOrNull;
        if (target == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No wallet named "${a.name}".')),
          );
          return;
        }
        await ref
            .read(walletListProvider.notifier)
            .update(target.copyWith(archived: true));
      case AdjustWalletBalanceAction a:
        final wallets = ref.read(walletListProvider);
        final query = a.walletName.trim().toLowerCase();
        final target = wallets
            .where((w) =>
                w.name.toLowerCase() == query ||
                w.name.toLowerCase().contains(query))
            .firstOrNull;
        if (target == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No wallet named "${a.walletName}".')),
          );
          return;
        }
        final balances = ref.read(walletBalancesProvider);
        final currentBalance = balances[target.id] ?? target.startingBalance;
        final diff = a.targetBalance - currentBalance;
        if (diff.abs() < 0.005) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '${target.name} balance is already ${pesoExact(a.targetBalance)}.')),
          );
          return;
        }
        final isSurplus = diff > 0;
        final txn = Transaction(
          id: _uuid.v4(),
          amount: diff.abs(),
          type: isSurplus ? TransactionType.income : TransactionType.expense,
          category: isSurplus ? 'Investment' : 'Adjustment',
          note: isSurplus
              ? 'Interest / Balance adjustment'
              : 'Balance adjustment',
          date: DateTime.now(),
          walletId: target.id,
        );
        await ref.read(transactionListProvider.notifier).add(txn);
    }

    await ref.read(walletListProvider.notifier).load();
    await ref.read(transactionListProvider.notifier).load();
    await ref.read(debtListProvider.notifier).load();
    await ref.read(goalListProvider.notifier).load();
    await ref.read(recurringListProvider.notifier).load();

    if (mounted) {
      final label = switch (action) {
        DeleteDebtAction _ || DeleteGoalAction _ => 'Deleted.',
        UpdateRecurringAction a when a.delete => 'Deleted.',
        ArchiveWalletAction _ => 'Archived.',
        AdjustWalletBalanceAction _ => 'Adjusted.',
        UpdateWalletAction _ ||
        UpdateDebtAction _ ||
        UpdateGoalAction _ ||
        UpdateRecurringAction _ =>
          'Updated.',
        _ => 'Added.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(label)),
      );
    }
    _removeAction(messageId, action);
  }

  void _removeAction(String messageId, CoachAction action) {
    final list = _session.pendingActions[messageId];
    if (list != null) {
      final updated = List<CoachAction>.from(list)..remove(action);
      setState(() {
        if (updated.isEmpty) {
          _session.pendingActions.remove(messageId);
        } else {
          _session.pendingActions[messageId] = updated;
        }
      });
      _scrollToBottom(animate: true);
    }
  }

  // Returns a Future that resolves when the in-flight request completes.
  // If the screen was disposed mid-flight (e.g. the user switched tabs),
  // the continuation is dropped — but the shared session survives, so the
  // assistant reply and action cards still land and appear on return.
  Future<void> _sendNow(String text) async {
    final trimmed = text.trim();
    final hasImage = _attachedImageBytes != null;
    if (trimmed.isEmpty && !hasImage) return;

    final imageBytes = _attachedImageBytes;
    final imageMime = _attachedImage != null &&
            _attachedImage!.name.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    setState(() {
      _attachedImage = null;
      _attachedImageBytes = null;
    });

    final isConfirmIntent = RegExp(
      r'^(?:confirm|approve|accept|yes|save\s+it|save\s+them|do\s+it|proceed)\b',
      caseSensitive: false,
    ).hasMatch(trimmed);

    // If user text confirms and there are pending action cards, auto-confirm them
    if (isConfirmIntent && _session.pendingActions.isNotEmpty) {
      final allPending =
          Map<String, List<CoachAction>>.from(_session.pendingActions);
      for (final entry in allPending.entries) {
        for (final act in List<CoachAction>.from(entry.value)) {
          await _applyAction(entry.key, act);
        }
      }
    }

    final messageContent = trimmed.isNotEmpty
        ? (hasImage ? '📷 [Receipt attached]\n$trimmed' : trimmed)
        : '📷 [Scanned receipt / screenshot]';

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      content: messageContent,
      timestamp: DateTime.now(),
    );
    await ref.read(chatListProvider.notifier).add(userMsg);
    _scrollToBottom(animate: true);

    final snapshot = _buildSnapshot();
    final settings = ref.read(settingsProvider);

    try {
      final service = await ref.read(coachServiceProvider.future);
      final coachReply = await service.ask(
        trimmed,
        snapshot,
        imageBytes: imageBytes,
        imageMimeType: imageMime,
      );
      List<CoachAction> actions = coachReply.actions;
      if (actions.isEmpty) {
        final userActions =
            _parser.parse(assistantReply: '', userMessage: trimmed);
        actions = userActions.isNotEmpty
            ? userActions
            : _parser.parse(assistantReply: coachReply.text);
      }

      // If actions are still empty, check if user was requesting cards or confirming
      if (actions.isEmpty) {
        final isRequestingCards = RegExp(
              r'(?:send|show|give|resend|where|accept|confirm|not here).*?(?:card|action|panel|debt|loan|it|spay)',
              caseSensitive: false,
            ).hasMatch(trimmed) ||
            isConfirmIntent;

        if (isRequestingCards) {
          final history = ref.read(chatListProvider);
          for (final prev in history.reversed.take(8)) {
            final recovered = _parser.parse(
              assistantReply:
                  prev.role == ChatRole.assistant ? prev.content : '',
              userMessage: prev.role == ChatRole.user ? prev.content : null,
            );
            final currentDebts = ref.read(debtListProvider);
            final currentGoals = ref.read(goalListProvider);
            final valid = recovered.where((act) {
              if (act is CreateDebtAction) {
                return !currentDebts.any(
                    (d) => d.name.toLowerCase() == act.debt.name.toLowerCase());
              }
              if (act is CreateGoalAction) {
                return !currentGoals.any(
                    (g) => g.name.toLowerCase() == act.goal.name.toLowerCase());
              }
              if (act is UpdateDebtBalanceAction) {
                final exists = currentDebts.any(
                    (d) => d.name.toLowerCase() == act.debtName.toLowerCase());
                final isNewlyCreated = _session.recentlyCreatedDebtNames
                    .contains(act.debtName.toLowerCase().trim());
                return exists && !isNewlyCreated;
              }
              return true;
            }).toList();

            if (valid.isNotEmpty) {
              actions = valid;
              break;
            }
          }
        }
      }

      // Suppress duplicate debt payment if debt was just created in this session
      // and user's current message didn't explicitly request to pay
      actions = actions.where((act) {
        if (act is UpdateDebtBalanceAction) {
          final isNewlyCreated = _session.recentlyCreatedDebtNames
              .contains(act.debtName.toLowerCase().trim());
          final hasExplicitPayWord = RegExp(
            r'\b(?:pay|paid|paying|payment)\b',
            caseSensitive: false,
          ).hasMatch(trimmed);
          if (isNewlyCreated && !hasExplicitPayWord) {
            return false;
          }
        }
        return true;
      }).toList();

      final assistantMsg = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        content: coachReply.text,
        timestamp: DateTime.now(),
      );
      await ref.read(chatListProvider.notifier).add(assistantMsg);
      if (actions.isNotEmpty) {
        _session.pendingActions[assistantMsg.id] = actions;
        final allWallets = ref.read(walletListProvider);
        for (final act in actions) {
          String? wName;
          if (act is LogTransactionAction && act.walletName != null) {
            wName = act.walletName;
          } else if (act is AdjustWalletBalanceAction) {
            wName = act.walletName;
          } else if (act is UpdateDebtBalanceAction && act.walletName != null) {
            wName = act.walletName;
          }
          if (wName != null) {
            final match = allWallets.where((w) {
              if (w.archived) return false;
              final q = wName!.trim().toLowerCase();
              final n = w.name.toLowerCase();
              return n == q || n.contains(q);
            }).firstOrNull;
            if (match != null) {
              _session.selectedWallets[assistantMsg.id] = match.id;
              break;
            }
          }
        }
        if (!_session.selectedWallets.containsKey(assistantMsg.id)) {
          final firstActive = allWallets.where((w) => !w.archived).firstOrNull;
          if (firstActive != null) {
            _session.selectedWallets[assistantMsg.id] = firstActive.id;
          }
        }
      }
      if (coachReply.warnings.isNotEmpty) {
        _session.pendingWarnings[assistantMsg.id] = coachReply.warnings;
      }
      _scrollToBottom(animate: true);
    } catch (e) {
      _session.error = e.toString();
      final assistantMsg = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        content:
            'Sorry, I couldn\'t reach the AI provider. ${settings.aiProvider == AIProvider.local ? '' : 'Check your API key and base URL in Settings.'}',
        timestamp: DateTime.now(),
      );
      await ref.read(chatListProvider.notifier).add(assistantMsg);
      _scrollToBottom(animate: true);
    }
  }

  // Busy-guard wrapper used by the UI; dedupes taps while a request is in
  // flight and keeps the single shared in-flight future so a rebuild or
  // tab switch never spawns a duplicate request. Busy state lives in the
  // shared session, so a request that completes while this tab is hidden
  // still clears the spinner before the user returns.
  void _send(String text) {
    if (_session.busy || _session.inFlight != null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty && _attachedImageBytes == null) return;
    final session = _session;
    _input.clear();
    session.draftText = '';
    session.busy = true;
    session.error = null;
    if (mounted) setState(() {});
    try {
      session.inFlight = _sendNow(trimmed).whenComplete(() {
        session.inFlight = null;
        session.busy = false;
        if (mounted) setState(() {});
      });
    } catch (_) {
      // Defensive: never leave the UI stuck in the busy state even if an
      // error escapes _sendNow's own error handling.
      session.inFlight = null;
      session.busy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatListProvider);
    final settings = ref.watch(settingsProvider);
    final service = ref.watch(coachServiceProvider).valueOrNull;
    final session = ref.watch(_sessionProvider);

    ref.listen<List<ChatMessage>>(chatListProvider, (prev, next) {
      if (next.isNotEmpty) {
        final isFirst = prev == null || prev.isEmpty;
        _scrollToBottom(animate: !isFirst);
      }
    });

    if (!_didInitialScroll && messages.isNotEmpty) {
      _didInitialScroll = true;
      _scrollToBottom(animate: false);
    }

    // Self-heal: if a previous session ever wedged busy=true (e.g. a crash
    // or hot reload during an older build), don't leave the input disabled
    // forever. Only clear it when no request is actually in flight.
    if (session.busy && session.inFlight == null) {
      session.busy = false;
    }

    final snapshot = _buildSnapshot();
    final prompts = service?.suggestedPrompts(snapshot) ?? const <String>[];
    final t = Theme.of(context);

    final isRemote = settings.aiProvider != AIProvider.local;
    final remoteEnabled = settings.allowRemoteAI;
    final providerLabel = isRemote
        ? '${kAIProviders[settings.aiProvider]!.displayName}${remoteEnabled ? '' : ' (off)'}'
        : 'On-device rules';

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => context.push('/settings'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology_outlined,
                        color: t.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('AI Coach',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isRemote
                            ? (remoteEnabled
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B))
                            : t.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      providerLabel,
                      style: t.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: t.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 13,
                      color:
                          t.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Clear chat',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  title: const Text('Clear conversation?'),
                  content: const Text(
                      'This removes all messages but keeps your data.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: const Text('Clear')),
                  ],
                ),
              );
              if (ok ?? false) {
                _didInitialScroll = false;
                _session.pendingActions.clear();
                _session.pendingWarnings.clear();
                _session.selectedWallets.clear();
                _session.recentlyCreatedDebtNames.clear();
                _session.draftText = '';
                _input.clear();
                try {
                  await ref.read(chatListProvider.notifier).clear();
                  ref.invalidate(coachServiceProvider);
                } catch (_) {
                  // ignore — state will be reset by the notifier anyway
                }
                if (mounted) setState(() {});
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_session.error != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: t.colorScheme.errorContainer.withValues(alpha: 0.6),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 16, color: t.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _session.error!,
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: t.colorScheme.onErrorContainer),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: t.colorScheme.onErrorContainer,
                    tooltip: 'Dismiss',
                    onPressed: () => setState(() => _session.error = null),
                  ),
                ],
              ),
            ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.psychology_outlined,
                              size: 56, color: t.colorScheme.outline),
                          const SizedBox(height: 12),
                          const Text('Ask anything about your money',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            prompts.isEmpty
                                ? 'Your messages will appear here. Ask a question below to start.'
                                : 'Powered by ${settings.aiProvider == AIProvider.local ? 'on-device rules' : settings.aiProvider.name}. '
                                    'Tap a prompt below to start.',
                            textAlign: TextAlign.center,
                            style: t.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final actions =
                          _session.pendingActions[msg.id] ?? const [];
                      final warnings =
                          _session.pendingWarnings[msg.id] ?? const [];
                      return ChatBubble(
                        message: msg,
                        wallets: ref.read(walletListProvider),
                        actions: actions,
                        warnings: warnings,
                        selectedWalletId: _session.selectedWallets[msg.id],
                        onWalletChanged: (walletId) {
                          setState(() =>
                              _session.selectedWallets[msg.id] = walletId);
                        },
                        onConfirmAction: (idx) {
                          if (idx < actions.length) {
                            _applyAction(msg.id, actions[idx]);
                          }
                        },
                        onDismissAction: (idx) {
                          if (idx < actions.length) {
                            final list = List<CoachAction>.from(actions)
                              ..removeAt(idx);
                            setState(() {
                              if (list.isEmpty) {
                                _session.pendingActions.remove(msg.id);
                              } else {
                                _session.pendingActions[msg.id] = list;
                              }
                            });
                          }
                        },
                      );
                    },
                  ),
          ),
          if (messages.isEmpty && prompts.isNotEmpty)
            SuggestedPrompts(prompts: prompts, onTap: _send),
          if (_attachedImageBytes != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: t.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: t.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _attachedImageBytes!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Receipt / screenshot attached',
                          style: t.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: t.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Tap send to scan and auto-create action card',
                          style: t.textTheme.labelSmall?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Remove',
                    onPressed: () => setState(() {
                      _attachedImage = null;
                      _attachedImageBytes = null;
                    }),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _session.busy ? null : _showImageSourceSheet,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    tooltip: 'Scan receipt / screenshot',
                    color: t.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_session.busy,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      onTap: () => _scrollToBottom(animate: true),
                      decoration: InputDecoration(
                        hintText: _session.busy
                            ? 'Thinking...'
                            : (_attachedImageBytes != null
                                ? 'Add a note or tap send...'
                                : 'Ask a question or scan receipt...'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _session.busy
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            _send(_input.text);
                          },
                    icon: _session.busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
