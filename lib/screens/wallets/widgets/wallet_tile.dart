import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../models/wallet.dart';
import '../../../utils/formatters.dart';

class WalletTile extends StatelessWidget {
  final Wallet wallet;
  final double balance;
  final VoidCallback? onTap;
  final VoidCallback? onShowQr;
  final bool compact;
  final Widget? trailing;
  final bool obscureBalance;

  const WalletTile({
    super.key,
    required this.wallet,
    required this.balance,
    this.onTap,
    this.onShowQr,
    this.compact = false,
    this.trailing,
    this.obscureBalance = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isNegative = balance < 0;
    final isBankOrCard =
        wallet.type == WalletType.bank || wallet.type == WalletType.credit;
    final maskedNumber = wallet.maskedAccountNumber;
    final holderName = wallet.accountName?.trim();
    final subtypeLabel =
        (wallet.accountLabel != null && wallet.accountLabel!.trim().isNotEmpty)
            ? wallet.accountLabel!.trim().toUpperCase()
            : wallet.type.label.toUpperCase();

    return Semantics(
      label:
          'Wallet: ${wallet.name}, ${wallet.type.label}, balance: ${obscureBalance ? "hidden" : pesoExact(balance)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(compact ? 14 : 18),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              wallet.color.withValues(alpha: 0.05),
              t.colorScheme.surfaceContainerLow,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: wallet.color.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Logo + Name + Category Badge + Archive trailing
              Row(
                children: [
                  WalletLogo(wallet: wallet, size: compact ? 34 : 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      wallet.name,
                      style: TextStyle(
                        fontSize: compact ? 15 : 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: wallet.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: wallet.color.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      wallet.type.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: t.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 4),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // Middle Row: EMV Chip + Contactless (Bank/Credit) + Balance
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isBankOrCard) ...[
                    const _EmvChip(),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.contactless_outlined,
                      size: 18,
                      color:
                          t.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    const Spacer(),
                  ],
                  Expanded(
                    flex: isBankOrCard ? 0 : 1,
                    child: Column(
                      crossAxisAlignment: isBankOrCard
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AVAILABLE BALANCE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: MediaQuery.of(context).disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Text(
                            obscureBalance ? '₱••••••' : pesoExact(balance),
                            key: ValueKey<bool>(obscureBalance),
                            style: TextStyle(
                              fontSize: compact ? 20 : 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: isNegative
                                  ? t.colorScheme.error
                                  : t.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (maskedNumber != null ||
                  (holderName != null && holderName.isNotEmpty) ||
                  wallet.type != WalletType.cash) ...[
                const SizedBox(height: 10),
                // Account Number & Action Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        maskedNumber != null
                            ? (obscureBalance
                                ? '••••  ••••  ••••'
                                : maskedNumber)
                            : 'Tap card to add account details',
                        style: TextStyle(
                          fontSize: maskedNumber != null ? 14 : 12,
                          fontWeight: maskedNumber != null
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: maskedNumber != null ? 1.2 : 0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: maskedNumber != null
                              ? t.colorScheme.onSurface
                              : t.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (wallet.hasQrImage &&
                        !obscureBalance &&
                        onShowQr != null) ...[
                      Semantics(
                        button: true,
                        label: 'Show ${wallet.name} QR code',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onShowQr!();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: t.colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 14,
                                  color: t.colorScheme.onPrimary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'QR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: t.colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (wallet.canCopyDetails) const SizedBox(width: 6),
                    ],
                    if (wallet.canCopyDetails && !obscureBalance)
                      Semantics(
                        button: true,
                        label: 'Copy ${wallet.name} account details',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            await Clipboard.setData(
                              ClipboardData(text: wallet.copyableDetails),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Copied ${wallet.name} details to clipboard'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: t.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: t.colorScheme.primary
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: t.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: t.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              if ((holderName != null && holderName.isNotEmpty) ||
                  (wallet.accountLabel != null &&
                      wallet.accountLabel!.trim().isNotEmpty)) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wallet.type == WalletType.ewallet
                                ? 'REGISTERED NAME'
                                : 'ACCOUNT HOLDER',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              color: t.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            obscureBalance
                                ? '••••••••'
                                : (holderName != null && holderName.isNotEmpty
                                    ? holderName.toUpperCase()
                                    : '—'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TYPE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtypeLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmvChip extends StatelessWidget {
  const _EmvChip();

  @override
  Widget build(BuildContext context) {
    const chipColor = Color(0xFFD97706);
    return Container(
      width: 36,
      height: 26,
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.65),
          width: 1.2,
        ),
      ),
      child: CustomPaint(
        painter: _EmvChipPainter(color: chipColor.withValues(alpha: 0.55)),
      ),
    );
  }
}

class _EmvChipPainter extends CustomPainter {
  final Color color;
  const _EmvChipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(0, size.height * 0.36), Offset(size.width, size.height * 0.36), paint);
    canvas.drawLine(
        Offset(0, size.height * 0.66), Offset(size.width, size.height * 0.66), paint);
    canvas.drawLine(
        Offset(size.width * 0.36, 0), Offset(size.width * 0.36, size.height), paint);
    canvas.drawLine(
        Offset(size.width * 0.64, 0), Offset(size.width * 0.64, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _EmvChipPainter oldDelegate) =>
      oldDelegate.color != color;
}

class WalletLogo extends StatelessWidget {
  final Wallet wallet;
  final double size;
  const WalletLogo({super.key, required this.wallet, this.size = 48});

  static bool isFullBleedBadge(String asset) {
    return asset.endsWith('cash.svg') ||
        asset.endsWith('credit_card.svg') ||
        asset.endsWith('custom.svg');
  }

  static Color badgeBackgroundFor(String asset) {
    if (asset.endsWith('maya.svg')) {
      return const Color(0xFF141F1A);
    }
    return const Color(0xFFF8FAFC);
  }

  @override
  Widget build(BuildContext context) {
    final asset = wallet.logoAsset;
    final fullBleed = isFullBleedBadge(asset);
    final radius = BorderRadius.circular(size * 0.26);
    return Container(
      width: size,
      height: size,
      padding: fullBleed ? EdgeInsets.zero : EdgeInsets.all(size * 0.13),
      decoration: BoxDecoration(
        color: fullBleed ? Colors.transparent : badgeBackgroundFor(asset),
        borderRadius: radius,
        border: fullBleed
            ? null
            : Border.all(
                color: wallet.color.withValues(alpha: 0.35),
                width: 1,
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SvgPicture.asset(
        asset,
        fit: fullBleed ? BoxFit.cover : BoxFit.contain,
        placeholderBuilder: (_) => Icon(
          wallet.type.icon,
          color: wallet.color,
          size: size * 0.5,
        ),
      ),
    );
  }
}
