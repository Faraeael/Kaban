import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../models/wallet.dart';
import '../../../utils/formatters.dart';

class WalletBalanceCard extends StatelessWidget {
  final Wallet wallet;
  final double balance;
  final VoidCallback? onTap;
  final bool obscureBalance;

  const WalletBalanceCard({
    super.key,
    required this.wallet,
    required this.balance,
    this.onTap,
    this.obscureBalance = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      label:
          'Wallet: ${wallet.name}, balance: ${obscureBalance ? "hidden" : pesoExact(balance)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 136,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: wallet.color.withValues(alpha: 0.25), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: wallet.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SvgPicture.asset(
                      wallet.logoAsset,
                      colorFilter:
                          const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      fit: BoxFit.contain,
                      placeholderBuilder: (_) => Icon(
                        wallet.type.icon,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      wallet.name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
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
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
