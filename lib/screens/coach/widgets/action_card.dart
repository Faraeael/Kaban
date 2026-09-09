import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../models/debt.dart';
import '../../../models/wallet.dart';
import '../../../services/coach_actions.dart';
import '../../../utils/formatters.dart';

class ActionCard extends StatelessWidget {
  final CoachAction action;
  final List<Wallet> wallets;
  final String? selectedWalletId;
  final ValueChanged<String> onWalletChanged;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const ActionCard({
    super.key,
    required this.action,
    this.wallets = const [],
    this.selectedWalletId,
    this.onWalletChanged = _noopWallet,
    required this.onConfirm,
    required this.onDismiss,
  });

  static void _noopWallet(String _) {}

  bool get _writesToWallet =>
      action is LogTransactionAction ||
      action is CreateRecurringAction ||
      action is UpdateDebtBalanceAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    final (icon, title, body) = switch (action) {
      LogTransactionAction a => (
          a.isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          a.isIncome ? 'Log income' : 'Log expense',
          '${a.isIncome ? '+' : '−'}${pesoExact(a.amount)} in ${a.category}${a.walletName != null ? ' (${a.walletName})' : ''}${a.note != null ? ' — ${a.note}' : ''}',
        ),
      AdjustWalletBalanceAction a => (
          Icons.tune_rounded,
          'Adjust balance',
          '${a.walletName} → ${pesoExact(a.targetBalance)} (adjusts balance to match)',
        ),
      UpdateDebtBalanceAction a => (
          Icons.credit_card_rounded,
          'Log debt payment',
          '${pesoExact(a.amount)} toward "${a.debtName}"${a.walletName != null ? ' (from ${a.walletName})' : ''}',
        ),
      AddToGoalAction a => (
          Icons.flag_rounded,
          'Add to goal',
          '${pesoExact(a.amount)} into "${a.goalName}"',
        ),
      CreateDebtAction a => (
          Icons.credit_card_off_rounded,
          'Create new debt',
          [
            '${a.debt.name} · ${pesoExact(a.debt.balance)} · ${a.debt.apr.toStringAsFixed(1)}% APR',
            if (a.debt.schedule == DebtSchedule.fixed && a.debt.dueDay != null)
              'Fixed schedule: due ${a.debt.dueDay}th${a.debt.remainingPayments != null ? ' · ${a.debt.remainingPayments} payments left' : ''}',
            if (a.debt.schedule == DebtSchedule.statementCycle &&
                a.debt.billingDay != null)
              'Statement cycle: billing ${a.debt.billingDay}th${a.debt.graceDays != null ? ' · ${a.debt.graceDays}d grace' : ''}',
          ].join('\n'),
        ),
      UpdateDebtAction a => (
          Icons.edit_note_rounded,
          'Update debt',
          '${a.name}${a.newName != null ? ' → ${a.newName}' : ''}${a.newBalance != null ? ' · balance ${pesoExact(a.newBalance!)}' : ''}${a.newApr != null ? ' · ${a.newApr!.toStringAsFixed(1)}% APR' : ''}${a.newMinPayment != null ? ' · min ${pesoExact(a.newMinPayment!)}' : ''}',
        ),
      DeleteDebtAction a => (
          Icons.delete_outline_rounded,
          'Delete debt',
          'Delete "${a.name}"',
        ),
      CreateGoalAction a => (
          Icons.flag_rounded,
          'Create new goal',
          '${a.goal.name} · target ${pesoExact(a.goal.target)}',
        ),
      UpdateGoalAction a => (
          Icons.flag_rounded,
          'Update goal',
          '${a.name}${a.newName != null ? ' → ${a.newName}' : ''}${a.newTarget != null ? ' · target ${pesoExact(a.newTarget!)}' : ''}',
        ),
      DeleteGoalAction a => (
          Icons.delete_outline_rounded,
          'Delete goal',
          'Delete "${a.name}"',
        ),
      CreateRecurringAction a => (
          Icons.autorenew_rounded,
          'Create recurring',
          '${a.recurring.name} · ${pesoExact(a.recurring.amount)} · '
              '${a.recurring.frequencyLabel} · ${a.recurring.category}',
        ),
      UpdateRecurringAction a => (
          a.delete ? Icons.delete_outline_rounded : Icons.autorenew_rounded,
          a.delete ? 'Delete recurring' : 'Update recurring',
          '${a.name}${a.delete ? ' (will be removed)' : ''}${a.newAmount != null ? ' · ${pesoExact(a.newAmount!)}' : ''}${a.newFrequency != null ? ' · ${a.newFrequency}' : ''}',
        ),
      CreateWalletAction a => (
          Icons.account_balance_wallet_rounded,
          'Create wallet',
          '${a.name}${a.startingBalance > 0 ? ' · ${pesoExact(a.startingBalance)} starting balance' : ''}',
        ),
      UpdateWalletAction a => (
          Icons.account_balance_wallet_rounded,
          'Update wallet',
          '${a.name}${a.newName != null ? ' → ${a.newName}' : ''}${a.newStartingBalance != null ? ' · starting ${pesoExact(a.newStartingBalance!)}' : ''}${a.unarchive ? ' · Unarchive' : ''}',
        ),
      ArchiveWalletAction a => (
          Icons.archive_rounded,
          'Archive wallet',
          'Archive "${a.name}"',
        ),
    };

    final showPicker = _writesToWallet && wallets.length > 1;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: scheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: t.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Action',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: t.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
          if (showPicker) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selectedWalletId ?? wallets.first.id,
              isDense: true,
              decoration: InputDecoration(
                labelText:
                    action is UpdateDebtBalanceAction ? 'Paid from' : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon:
                    const Icon(Icons.account_balance_wallet_outlined, size: 16),
              ),
              items: [
                for (final w in wallets)
                  DropdownMenuItem(
                    value: w.id,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: SvgPicture.asset(
                            w.logoAsset,
                            fit: BoxFit.contain,
                            placeholderBuilder: (_) =>
                                Icon(w.type.icon, size: 14, color: w.color),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          w.name,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onWalletChanged(v);
              },
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onDismiss();
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (context) {
                  final (confirmLabel, isDestructive, confirmIcon) =
                      switch (action) {
                    DeleteDebtAction _ || DeleteGoalAction _ => (
                        'Delete',
                        true,
                        Icons.delete_outline_rounded
                      ),
                    UpdateRecurringAction a when a.delete => (
                        'Delete',
                        true,
                        Icons.delete_outline_rounded
                      ),
                    ArchiveWalletAction _ => (
                        'Archive',
                        false,
                        Icons.archive_rounded
                      ),
                    AdjustWalletBalanceAction _ => (
                        'Adjust',
                        false,
                        Icons.tune_rounded,
                      ),
                    UpdateWalletAction _ ||
                    UpdateDebtAction _ ||
                    UpdateGoalAction _ ||
                    UpdateRecurringAction _ =>
                      ('Update', false, Icons.check_rounded),
                    _ => ('Add', false, Icons.check_rounded),
                  };

                  return Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onConfirm();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: isDestructive ? scheme.error : null,
                        foregroundColor: isDestructive ? scheme.onError : null,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(confirmIcon, size: 16),
                      label: Text(confirmLabel,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
