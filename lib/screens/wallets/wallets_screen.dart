import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/wallet.dart';
import '../../state/data_providers.dart';
import '../../state/settings_provider.dart';
import '../../utils/formatters.dart';
import 'widgets/wallet_tile.dart';
import '../../services/qr_crop_service.dart';

const _uuid = Uuid();

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  WalletType? _selectedCategory;

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
    final settings = ref.watch(settingsProvider);
    final active = wallets.where((w) => !w.archived).toList();
    final archived = wallets.where((w) => w.archived).toList();

    double balanceFor(Wallet w) => balances[w.id] ?? 0;

    final totalActiveBalance =
        active.fold<double>(0, (s, w) => s + balanceFor(w));

    final qrWallets = active.where((w) => w.hasQrImage).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
        actions: [
          if (!settings.privacyMode && qrWallets.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.qr_code_2_rounded),
              tooltip: 'QR Deck',
              onPressed: () => _showQrDeck(
                context,
                qrWallets,
                initialWalletId: qrWallets.first.id,
              ),
            ),
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
                      _buildCategoryFilterStrip(context),
                      const SizedBox(height: 14),
                      ..._buildCategorizedWallets(
                        context,
                        active: active,
                        balanceFor: balanceFor,
                        obscureBalance: settings.privacyMode,
                        isWide: isWide,
                      ),
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
                      for (final w in archived) ...[
                        _walletTile(
                            context, w, balanceFor(w), settings.privacyMode),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCategoryFilterStrip(BuildContext context) {
    final t = Theme.of(context);
    const filters = <(WalletType?, String)>[
      (null, 'All'),
      (WalletType.ewallet, 'E-Wallets'),
      (WalletType.bank, 'Banks'),
      (WalletType.cash, 'Cash'),
      (WalletType.credit, 'Credit Cards'),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (type, label) = filters[i];
          final selected = _selectedCategory == type;
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _selectedCategory = type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? t.colorScheme.primary
                    : t.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? t.colorScheme.primary
                      : t.colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? t.colorScheme.onPrimary
                      : t.colorScheme.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildCategorizedWallets(
    BuildContext context, {
    required List<Wallet> active,
    required double Function(Wallet) balanceFor,
    required bool obscureBalance,
    required bool isWide,
  }) {
    final t = Theme.of(context);
    const order = [
      WalletType.ewallet,
      WalletType.bank,
      WalletType.cash,
      WalletType.credit,
    ];
    final typesToShow = _selectedCategory != null
        ? [_selectedCategory!]
        : order;
    final sections = <Widget>[];

    for (final type in typesToShow) {
      final group = active.where((w) => w.type == type).toList();
      if (group.isEmpty) continue;
      final subtotal = group.fold<double>(0, (s, w) => s + balanceFor(w));
      final headerLabel = switch (type) {
        WalletType.ewallet => 'E-WALLETS (${group.length})',
        WalletType.bank => 'BANKS (${group.length})',
        WalletType.cash => 'CASH (${group.length})',
        WalletType.credit => 'CREDIT CARDS (${group.length})',
      };

      sections.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                headerLabel,
                style: t.textTheme.labelSmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                obscureBalance ? '₱••••' : peso(subtotal),
                style: t.textTheme.labelSmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );

      if (isWide) {
        sections.add(
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 210,
            ),
            itemCount: group.length,
            itemBuilder: (_, i) => _walletTile(
              context,
              group[i],
              balanceFor(group[i]),
              obscureBalance,
            ),
          ),
        );
        sections.add(const SizedBox(height: 14));
      } else {
        for (final w in group) {
          sections.add(_walletTile(context, w, balanceFor(w), obscureBalance));
          sections.add(const SizedBox(height: 12));
        }
      }
    }

    if (sections.isEmpty) {
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              'No ${_selectedCategory?.label.toLowerCase() ?? ''} wallets yet.',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    return sections;
  }

  Widget _walletTile(
      BuildContext context, Wallet w, double balance, bool obscureBalance) {
    final t = Theme.of(context);
    final qrWallets = ref
        .read(walletListProvider)
        .where((x) => !x.archived && x.hasQrImage)
        .toList();
    return WalletTile(
      wallet: w,
      balance: balance,
      obscureBalance: obscureBalance,
      onTap: () => context.go('/transactions?walletId=${w.id}'),
      onShowQr: w.hasQrImage
          ? () => _showQrDeck(
                context,
                qrWallets.isNotEmpty ? qrWallets : [w],
                initialWalletId: w.id,
              )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Customize card',
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: t.colorScheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
            onPressed: () => _showEditSheet(context, w),
          ),
          IconButton(
            tooltip: w.archived ? 'Restore wallet' : 'Archive wallet',
            icon: Icon(
              w.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
              size: 18,
            ),
            color: w.archived
                ? t.colorScheme.primary
                : t.colorScheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              final ok = await _confirmArchive(context, w);
              if (!ok || !context.mounted) return;
              ref
                  .read(walletListProvider.notifier)
                  .update(w.copyWith(archived: !w.archived));
            },
          ),
        ],
      ),
    );
  }

  void _showQrDeck(
    BuildContext context,
    List<Wallet> qrWallets, {
    String? initialWalletId,
  }) {
    if (qrWallets.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QrDeckSheet(
        wallets: qrWallets,
        initialWalletId: initialWalletId,
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
    final Wallet draft;
    if (name == 'Custom') {
      draft = Wallet(
        id: _uuid.v4(),
        name: '',
        type: WalletType.bank,
        startingBalance: 0,
        colorValue: 0xFF1B7F5F,
        logoAsset: 'assets/logos/custom.svg',
      );
    } else {
      final preset = kWalletPresets.firstWhere((p) => p.name == name);
      draft = preset.toWallet(_uuid.v4());
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) => _EditWalletSheet(
        wallet: draft,
        isNew: true,
        onSave: (configured) {
          Navigator.pop(sheetCtx);
          widget.onSave(configured);
        },
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
              padding: logoAsset != null &&
                      WalletLogo.isFullBleedBadge(logoAsset!)
                  ? EdgeInsets.zero
                  : const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: logoAsset != null
                    ? (WalletLogo.isFullBleedBadge(logoAsset!)
                        ? Colors.transparent
                        : WalletLogo.badgeBackgroundFor(logoAsset!))
                    : t.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.4),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: logoAsset != null
                  ? SvgPicture.asset(
                      logoAsset!,
                      fit: WalletLogo.isFullBleedBadge(logoAsset!)
                          ? BoxFit.cover
                          : BoxFit.contain,
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
  final bool isNew;
  final void Function(Wallet) onSave;
  final VoidCallback? onDelete;
  const _EditWalletSheet({
    required this.wallet,
    this.isNew = false,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_EditWalletSheet> createState() => _EditWalletSheetState();
}

class _EditWalletSheetState extends State<_EditWalletSheet> {
  late TextEditingController _name;
  late TextEditingController _balance;
  late TextEditingController _accountNumber;
  late TextEditingController _accountName;
  late TextEditingController _accountLabel;
  late WalletType _type;
  String? _qrImagePath;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.wallet.name);
    _balance = TextEditingController(
      text: widget.wallet.startingBalance == 0 && widget.isNew
          ? ''
          : formatInputAmount(widget.wallet.startingBalance),
    );
    _accountNumber =
        TextEditingController(text: widget.wallet.accountNumber ?? '');
    _accountName = TextEditingController(text: widget.wallet.accountName ?? '');
    _accountLabel =
        TextEditingController(text: widget.wallet.accountLabel ?? '');
    _type = widget.wallet.type;
    _qrImagePath = widget.wallet.qrImagePath;
  }

  Future<void> _pickQrImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 100,
      );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final qrDir = Directory('${appDir.path}/wallet_qrs');
      if (!await qrDir.exists()) {
        await qrDir.create(recursive: true);
      }
      final destPath =
          '${qrDir.path}/qr_${widget.wallet.id}_${DateTime.now().millisecondsSinceEpoch}.png';

      final tempPickedFile = File(picked.path);

      // Attempt automatic QR finder detection and quiet-zone crop
      File? finalQrFile = await QrCropService.autoDetectAndCrop(
        sourceImageFile: tempPickedFile,
        destPath: destPath,
      );

      // If auto-detection cannot locate finder patterns, offer interactive cropper
      if (finalQrFile == null && mounted) {
        final croppedBytes = await Navigator.push<Uint8List?>(
          context,
          MaterialPageRoute(
            builder: (_) => InteractiveQrCropperModal(imageFile: tempPickedFile),
          ),
        );
        if (croppedBytes != null) {
          finalQrFile = File(destPath);
          await finalQrFile.writeAsBytes(croppedBytes);
        }
      }

      if (finalQrFile != null && mounted) {
        setState(() => _qrImagePath = finalQrFile!.path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code cropped and saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick QR image: $e')),
        );
      }
    }
  }
  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _accountNumber.dispose();
    _accountName.dispose();
    _accountLabel.dispose();
    super.dispose();
  }

  Wallet _previewWallet() {
    final enteredName = _name.text.trim();
    final enteredBal =
        double.tryParse(_balance.text.replaceAll(',', '')) ??
            widget.wallet.startingBalance;
    final rawAcctNum = _accountNumber.text.trim();
    final acctNum = _type == WalletType.credit && rawAcctNum.length > 4
        ? rawAcctNum.substring(rawAcctNum.length - 4)
        : rawAcctNum;
    final acctName = _accountName.text.trim();
    final acctLabel = _accountLabel.text.trim();
    final isCash = _type == WalletType.cash;
    final supportsQr = _type == WalletType.bank || _type == WalletType.ewallet;
    return widget.wallet.copyWith(
      name: enteredName.isEmpty
          ? (widget.wallet.name.isEmpty ? _type.label : widget.wallet.name)
          : enteredName,
      type: _type,
      startingBalance: enteredBal,
      accountNumber: (isCash || acctNum.isEmpty) ? null : acctNum,
      accountName: (isCash || acctName.isEmpty) ? null : acctName,
      accountLabel: (isCash || acctLabel.isEmpty) ? null : acctLabel,
      qrImagePath: supportsQr ? _qrImagePath : null,
      clearAccountDetails: isCash,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final preview = _previewWallet();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
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
            const SizedBox(height: 12),
            Text(
              widget.isNew ? 'Set up card' : 'Customize card',
              style: t.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            WalletTile(
              wallet: preview,
              balance: preview.startingBalance,
              compact: true,
            ),
            const SizedBox(height: 16),
            Text(
              'WALLET CATEGORY',
              style: t.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in const [
                  WalletType.ewallet,
                  WalletType.bank,
                  WalletType.cash,
                  WalletType.credit,
                ])
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _name,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Wallet name'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _balance,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Starting balance',
                      prefixText: '₱ ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            if (_type != WalletType.cash) ...[
              const SizedBox(height: 16),
              Text(
                'CARD / ACCOUNT DETAILS (OPTIONAL)',
                style: t.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: t.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _accountNumber,
                onChanged: (_) => setState(() {}),
                maxLength: _type == WalletType.credit ? 4 : null,
                inputFormatters: _type == WalletType.credit
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
                decoration: InputDecoration(
                  labelText: _type == WalletType.credit
                      ? 'Card last 4 digits only'
                      : (_type == WalletType.ewallet
                          ? 'Mobile / Account No. (masked on card)'
                          : 'Account No. (masked as •••• 1024)'),
                  hintText: _type == WalletType.credit
                      ? 'e.g. 1024'
                      : (_type == WalletType.ewallet
                          ? 'e.g. 0917 123 4567'
                          : 'e.g. 0041 2839 1024'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _accountName,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Account holder name',
                        hintText: 'e.g. Juan Dela Cruz',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _accountLabel,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Subtype / Label',
                        hintText: 'e.g. Savings',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: t.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 15, color: t.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'For InstaPay / GCash sharing only. Never enter PIN, CVV, or passwords.',
                        style: t.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_type == WalletType.bank || _type == WalletType.ewallet) ...[
                const SizedBox(height: 16),
                Text(
                  'RECEIVE QR CODE (INSTAPAY / QR PH)',
                  style: t.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: t.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          t.colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_qrImagePath != null &&
                          File(_qrImagePath!).existsSync())
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 56,
                            height: 56,
                            color: Colors.white,
                            padding: const EdgeInsets.all(4),
                            child: Image.file(
                              File(_qrImagePath!),
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: t.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            size: 28,
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _qrImagePath != null
                                  ? 'Receive QR bound ✓'
                                  : 'Bind your receive QR code',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Save your QR from GCash, Maya, or bank app and attach it here for quick scanning.',
                              style: t.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: t.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: _pickQrImage,
                                  icon: const Icon(Icons.photo_library_outlined,
                                      size: 15),
                                  label: Text(
                                    _qrImagePath != null
                                        ? 'Change QR'
                                        : 'Attach QR',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                if (_qrImagePath != null)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: t.colorScheme.error,
                                    ),
                                    onPressed: () =>
                                        setState(() => _qrImagePath = null),
                                    child: const Text('Remove',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.onDelete != null && !widget.isNew) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: t.colorScheme.error),
                      onPressed: widget.onDelete,
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
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
                      final name = _name.text.trim();
                      if (name.isEmpty && widget.wallet.name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter a wallet name.')),
                        );
                        return;
                      }
                      widget.onSave(_previewWallet());
                    },
                    child: const Text('Save Card'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QrDeckSheet extends StatefulWidget {
  final List<Wallet> wallets;
  final String? initialWalletId;
  const _QrDeckSheet({
    required this.wallets,
    this.initialWalletId,
  });

  @override
  State<_QrDeckSheet> createState() => _QrDeckSheetState();
}

class _QrDeckSheetState extends State<_QrDeckSheet> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    final found = widget.initialWalletId != null
        ? widget.wallets.indexWhere((w) => w.id == widget.initialWalletId)
        : 0;
    _index = found >= 0 ? found : 0;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    setState(() => _index = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final current = widget.wallets[_index];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: t.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receive via QR',
                      style: t.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.wallets.length > 1)
                      Text(
                        'Swipe left or right to switch wallet QR',
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (widget.wallets.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.wallets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final w = widget.wallets[i];
                  final selected = i == _index;
                  return ChoiceChip(
                    label: Text(w.name),
                    selected: selected,
                    onSelected: (_) => _goTo(i),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 370,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.wallets.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final w = widget.wallets[i];
                final path = w.qrImagePath;
                final hasFile = path != null && File(path).existsSync();
                final sub = [
                  if (w.accountName != null &&
                      w.accountName!.trim().isNotEmpty)
                    w.accountName!.trim().toUpperCase(),
                  if (w.maskedAccountNumber != null) w.maskedAccountNumber!,
                ].join(' · ');

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: w.color.withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          WalletLogo(wallet: w, size: 30),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              w.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (sub.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          sub,
                          style: t.textTheme.bodySmall?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: t.colorScheme.outlineVariant
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: hasFile
                                  ? Image.file(
                                      File(path),
                                      fit: BoxFit.contain,
                                    )
                                  : Center(
                                      child: Icon(
                                        Icons.qr_code_2_rounded,
                                        size: 96,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (widget.wallets.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.wallets.length; i++)
                  Container(
                    width: i == _index ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _index
                          ? t.colorScheme.primary
                          : t.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
          if (current.canCopyDetails) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  await Clipboard.setData(
                    ClipboardData(text: current.copyableDetails),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Copied ${current.name} details to clipboard'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text('Copy ${current.name} Account Details'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
