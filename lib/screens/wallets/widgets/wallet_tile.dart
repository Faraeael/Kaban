import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../models/wallet.dart';
import '../../../utils/formatters.dart';

class WalletTile extends StatelessWidget {
  final Wallet wallet;
  final double balance;
  final VoidCallback? onTap;
  final bool compact;
  final Widget? trailing;
  final bool obscureBalance;

  const WalletTile({
    super.key,
    required this.wallet,
    required this.balance,
    this.onTap,
    this.compact = false,
    this.trailing,
    this.obscureBalance = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isNegative = balance < 0;

    return Semantics(
      label:
          'Wallet: ${wallet.name}, ${wallet.type.label}, balance: ${obscureBalance ? "hidden" : pesoExact(balance)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: t.colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 40 : 48,
                height: compact ? 40 : 48,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: wallet.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SvgPicture.asset(
                  wallet.logoAsset,
                  fit: BoxFit.contain,
                  placeholderBuilder: (_) => Icon(
                    wallet.type.icon,
                    color: wallet.color,
                    size: compact ? 20 : 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      style: TextStyle(
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      wallet.type.label,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: MediaQuery.of(context).disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Text(
                  obscureBalance ? '₱••••' : pesoExact(balance),
                  key: ValueKey<bool>(obscureBalance),
                  style: TextStyle(
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    color: isNegative
                        ? t.colorScheme.error
                        : t.colorScheme.onSurface,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ] else ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: t.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class WalletLogo extends StatelessWidget {
  final Wallet wallet;
  final double size;
  const WalletLogo({super.key, required this.wallet, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: wallet.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: SvgPicture.asset(
        wallet.logoAsset,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => Icon(
          wallet.type.icon,
          color: wallet.color,
          size: size * 0.5,
        ),
      ),
    );
  }
}
