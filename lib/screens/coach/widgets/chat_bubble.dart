import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../models/chat_message.dart';
import '../../../models/wallet.dart';
import '../../../services/coach_actions.dart';
import 'action_card.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final List<Wallet> wallets;
  final List<CoachAction> actions;
  final List<String> warnings;
  final String? selectedWalletId;
  final void Function(String walletId) onWalletChanged;
  final void Function(int actionIndex) onConfirmAction;
  final void Function(int actionIndex) onDismissAction;

  const ChatBubble({
    super.key,
    required this.message,
    this.wallets = const [],
    this.actions = const [],
    this.warnings = const [],
    this.selectedWalletId,
    this.onWalletChanged = _noopWallet,
    this.onConfirmAction = _noopConfirm,
    this.onDismissAction = _noopDismiss,
  });

  static void _noopWallet(String _) {}
  static void _noopConfirm(int _) {}
  static void _noopDismiss(int _) {}

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isUser = message.role == ChatRole.user;
    final hasActions = !isUser && actions.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? t.colorScheme.primary
                    : t.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                ),
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: TextStyle(
                        color: t.colorScheme.onPrimary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    )
                  : MarkdownBody(
                      data: message.content,
                      softLineBreak: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(t).copyWith(
                        p: TextStyle(
                          color: t.colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        listBullet: TextStyle(
                          color: t.colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        strong: TextStyle(
                          color: t.colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        h1: TextStyle(
                          color: t.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        h2: TextStyle(
                          color: t.colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        h3: TextStyle(
                          color: t.colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        code: TextStyle(
                          color: t.colorScheme.onSurface,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: t.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: t.colorScheme.outlineVariant,
                              width: 2,
                            ),
                          ),
                        ),
                        blockquotePadding:
                            const EdgeInsets.only(left: 10, top: 2, bottom: 2),
                      ),
                    ),
            ),
          ),
          if (!isUser && warnings.isNotEmpty)
            for (final w in warnings)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        w,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          if (hasActions)
            for (var i = 0; i < actions.length; i++)
              ActionCard(
                action: actions[i],
                wallets: wallets,
                selectedWalletId: selectedWalletId,
                onWalletChanged: onWalletChanged,
                onConfirm: () => onConfirmAction(i),
                onDismiss: () => onDismissAction(i),
              ),
        ],
      ),
    );
  }
}
