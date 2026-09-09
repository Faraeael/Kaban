import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/wallet.dart';
import '../../state/data_providers.dart';
import '../../state/settings_provider.dart';
import '../../utils/formatters.dart';
import 'widgets/wallet_tile.dart';

const _uuid = Uuid();

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletListProvider.notifier).load();
      ref.read(transactionListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletListProvider);
    final balances = ref.watch(walletBalancesProvider);
    final calc = ref.watch(balanceRecalculatorProvider);
    final txns = ref.watch(transactionListProvider);
    final settings = ref.watch(settingsProvider);
    final active = wallets.where((w) => !w.archived).toList();
    final archived = wallets.where((w) => w.archived).toList();

    double balanceFor(Wallet w) {
      if (w.archived) {
        return calc.compute(w, txns.where((t) => t.walletId == w.id).toList());
      }
      return balances[w.id] ?? 0;
    }

    final totalActiveBalance =
        active.fold<double>(0, (s, w) => s + balanceFor(w));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Transfer',
            onPressed: () => context.push('/transactions/transfer'),
          ),
          IconButton(
            icon: Icon(settings.privacyMode
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            tooltip: settings.privacyMode ? 'Show balances' : 'Hide balances',
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(settingsProvider.notifier).update(
                    settings.copyWith(privacyMode: !settings.privacyMode),
                  );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add wallet'),
      ),
      body: wallets.isEmpty
          ? _EmptyState(onTap: () => _showAddSheet(context))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    if (active.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Total wallet balance',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        ref
                                            .read(settingsProvider.notifier)
                                            .update(
                                              settings.copyWith(
                                                  privacyMode:
                                                      !settings.privacyMode),
                                            );
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          settings.privacyMode
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${active.length} active',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            AnimatedSwitcher(
                              duration: MediaQuery.of(context).disableAnimations
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeOutCubic,
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                      opacity: animation, child: child),
                              child: Text(
                                settings.privacyMode
                                    ? '₱••••••'
                                    : peso(totalActiveBalance),
                                key: ValueKey<bool>(settings.privacyMode),
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: totalActiveBalance < 0
                                      ? Theme.of(context).colorScheme.error
                                      : Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                  letterSpacing:
                                      settings.privacyMode ? 2.0 : -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isWide)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 84,
                          ),
                          itemCount: active.length,
                          itemBuilder: (_, i) => _walletTile(
                            context,
                            active[i],
                            balanceFor(active[i]),
                            settings.privacyMode,
                          ),
                        )
                      else
                        for (final w in active) ...[
                          _walletTile(
                              context, w, balanceFor(w), settings.privacyMode),
                          const SizedBox(height: 10),
                        ],
                    ],
                    if (archived.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'ARCHIVED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (isWide)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 84,
                          ),
                          itemCount: archived.length,
                          itemBuilder: (_, i) => _walletTile(
                            context,
                            archived[i],
                            balanceFor(archived[i]),
                            settings.privacyMode,
                          ),
                        )
                      else
                        for (final w in archived) ...[
                          _walletTile(
                              context, w, balanceFor(w), settings.privacyMode),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _walletTile(
      BuildContext context, Wallet w, double balance, bool obscureBalance) {
    final t = Theme.of(context);
    return WalletTile(
      wallet: w,
      balance: balance,
      obscureBalance: obscureBalance,
      onTap: () => _showEditSheet(context, w),
      trailing: IconButton(
        tooltip: w.archived ? 'Restore wallet' : 'Archive wallet',
        icon: Icon(
          w.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
          size: 20,
        ),
        color:
            w.archived ? t.colorScheme.primary : t.colorScheme.onSurfaceVariant,
        visualDensity: VisualDensity.compact,
        onPressed: () async {
          final ok = await _confirmArchive(context, w);
          if (!ok || !context.mounted) return;
          ref
              .read(walletListProvider.notifier)
              .update(w.copyWith(archived: !w.archived));
        },
      ),
    );
  }

  Future<bool> _confirmArchive(BuildContext context, Wallet w) async {
    if (w.archived) {
      return await showDialog<bool>(
            context: context,
            builder: (dialogCtx) => AlertDialog(
              title: const Text('Restore wallet?'),
              content: Text('${w.name} will show on the dashboard again.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('Restore Wallet'),
                ),
              ],
            ),
          ) ??
          false;
    }
    return await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Archive wallet?'),
            content: const Text(
                'This hides it from the dashboard but keeps all history.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Archive Wallet'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddWalletSheet(
        onSave: (wallet) {
          ref.read(walletListProvider.notifier).add(wallet);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditSheet(BuildContext context, Wallet w) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditWalletSheet(
        wallet: w,
        onSave: (next) {
          ref.read(walletListProvider.notifier).update(next);
          Navigator.pop(context);
        },
        onDelete: () => _confirmDelete(context, w),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Wallet w) async {
    final t = Theme.of(context);
    final txns = ref.read(transactionListProvider);
    final count = txns.where((t) => t.walletId == w.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete wallet?'),
        content: Text(
          count > 0
              ? '${w.name} has $count transaction(s). Deleting it permanently '
                  'removes the wallet, its transactions, linked subscriptions, '
                  'and linked debts. This cannot be undone.'
              : 'Deleting ${w.name} permanently removes it. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: t.colorScheme.error),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete Wallet'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(walletListProvider.notifier).delete(w.id);
    await ref.read(transactionListProvider.notifier).load();
    await ref.read(debtListProvider.notifier).load();
    await ref.read(subscriptionListProvider.notifier).load();
    if (context.mounted) Navigator.pop(context);
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 56, color: t.colorScheme.outline),
            const SizedBox(height: 14),
            const Text('No wallets yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Add your bank accounts, e-wallets, and cash to start tracking.',
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add your first wallet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddWalletSheet extends StatefulWidget {
  final void Function(Wallet) onSave;
  const _AddWalletSheet({required this.onSave});

  @override
  State<_AddWalletSheet> createState() => _AddWalletSheetState();
}

class _AddWalletSheetState extends State<_AddWalletSheet> {
  String? _selectedName;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add wallet',
              style: t.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Pick from common PH wallets or add a custom one.',
            style: t.textTheme.bodySmall
                ?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 340,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: kWalletPresets.length + 1,
              itemBuilder: (_, i) {
                if (i == kWalletPresets.length) {
                  return _PresetTile(
                    label: 'Custom',
                    color: t.colorScheme.outline,
                    icon: Icons.edit_rounded,
                    selected: _selectedName == 'Custom',
                    onTap: () => setState(() => _selectedName = 'Custom'),
                  );
                }
                final p = kWalletPresets[i];
                return _PresetTile(
                  label: p.name,
                  color: Color(p.colorValue),
                  icon: p.type.icon,
                  logoAsset: p.logoAsset,
                  selected: _selectedName == p.name,
                  onTap: () => setState(() => _selectedName = p.name),
                );
              },
            ),
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
                  onPressed: _selectedName == null
                      ? null
                      : () => _confirmAndSave(_selectedName!),
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSave(String name) async {
    if (name == 'Custom') {
      _showCustomDialog();
      return;
    }
    final preset = kWalletPresets.firstWhere((p) => p.name == name);
    final wallet = preset.toWallet(_uuid.v4());
    widget.onSave(wallet);
  }

  void _showCustomDialog() {
    final nameC = TextEditingController();
    final balanceC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: balanceC,
              decoration:
                  const InputDecoration(labelText: 'Starting balance (₱)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameC.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a wallet name.')),
                );
                return;
              }
              final bal = double.tryParse(balanceC.text) ?? 0;
              widget.onSave(Wallet(
                id: _uuid.v4(),
                name: name,
                type: WalletType.bank,
                startingBalance: bal,
                colorValue: 0xFF37474F,
                logoAsset: 'assets/logos/custom.svg',
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Add Wallet'),
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final String? logoAsset;
  final bool selected;
  final VoidCallback onTap;
  const _PresetTile({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    this.logoAsset,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : t.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: t.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: logoAsset != null
                  ? SvgPicture.asset(
                      logoAsset!,
                      fit: BoxFit.contain,
                      placeholderBuilder: (_) =>
                          Icon(icon, color: color, size: 24),
                    )
                  : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditWalletSheet extends StatefulWidget {
  final Wallet wallet;
  final void Function(Wallet) onSave;
  final VoidCallback? onDelete;
  const _EditWalletSheet({
    required this.wallet,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_EditWalletSheet> createState() => _EditWalletSheetState();
}

class _EditWalletSheetState extends State<_EditWalletSheet> {
  late TextEditingController _name;
  late TextEditingController _balance;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.wallet.name);
    _balance = TextEditingController(
        text: widget.wallet.startingBalance.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit wallet',
              style: t.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          TextField(
            controller: _balance,
            decoration:
                const InputDecoration(labelText: 'Adjust starting balance (₱)'),
            keyboardType: TextInputType.number,
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
                    child: const Text('Delete'),
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
                  onPressed: () {
                    final bal = double.tryParse(_balance.text) ??
                        widget.wallet.startingBalance;
                    widget.onSave(widget.wallet.copyWith(
                      name: _name.text.trim().isEmpty
                          ? widget.wallet.name
                          : _name.text.trim(),
                      startingBalance: bal,
                    ));
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
