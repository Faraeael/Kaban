import '../models/transaction.dart';

class ParsedNotification {
  final bool success;
  final double? amount;
  final String? merchant;
  final TransactionType? type;
  final String? category;

  const ParsedNotification({
    required this.success,
    this.amount,
    this.merchant,
    this.type,
    this.category,
  });
}

class NotificationParser {
  static final _amountPattern = RegExp(
    r'(?:₱|PHP|PhP|P|\$|USD)?\s?([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
  );

  static final _ignoreWords = ['balance', 'available', 'remaining', 'as of'];

  ParsedNotification parse({
    required String packageName,
    required String title,
    required String text,
  }) {
    final combined = '$title $text';
    final lower = combined.toLowerCase();

    final isInterest = lower.contains('interest') &&
        (lower.contains('credit') ||
            lower.contains('earned') ||
            lower.contains('received') ||
            lower.contains('added') ||
            lower.contains('deposited'));

    if (!isInterest) {
      for (final w in _ignoreWords) {
        if (lower.startsWith(w) || lower.contains(' your $w')) {
          return const ParsedNotification(success: false);
        }
      }
    }

    final match = _amountPattern.firstMatch(combined);
    if (match == null) {
      return const ParsedNotification(success: false);
    }

    final raw = match.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      return const ParsedNotification(success: false);
    }

    TransactionType type;
    if (isInterest ||
        lower.contains('received') ||
        lower.contains('credited') ||
        lower.contains('cash in') ||
        lower.contains('cash-in')) {
      type = TransactionType.income;
    } else if (lower.contains('inter-bank transfer') ||
        lower.contains('transferred to your other')) {
      type = TransactionType.transfer;
    } else {
      type = TransactionType.expense;
    }

    String? merchant;
    final toMatch = RegExp(r"(?:to|from|at)\s+([A-Z][\w\s&\.\'-]{1,40})")
        .firstMatch(combined);
    if (toMatch != null) {
      merchant = toMatch.group(1)?.trim();
    } else if (isInterest) {
      merchant = 'Interest';
    }

    final category = _guessCategory(lower, merchant);

    return ParsedNotification(
      success: true,
      amount: amount,
      merchant: merchant,
      type: type,
      category: category,
    );
  }

  String _guessCategory(String lower, String? merchant) {
    if (lower.contains('interest') || lower.contains('dividend')) {
      return 'Investment';
    }
    final m = (merchant ?? '').toLowerCase();
    if (m.contains('grab') || m.contains('joyride') || m.contains('angkas')) {
      return 'Transport';
    }
    if (m.contains('jollibee') ||
        m.contains('mcdo') ||
        m.contains('kfc') ||
        m.contains('mcdonald') ||
        m.contains('starbucks')) {
      return 'Food';
    }
    if (m.contains('meralco') ||
        m.contains('pldt') ||
        m.contains('globe') ||
        m.contains('smart')) {
      return 'Utilities';
    }
    if (m.contains('netflix') ||
        m.contains('spotify') ||
        m.contains('youtube')) {
      return 'Subscriptions';
    }
    if (m.contains('7-eleven') ||
        m.contains('ministop') ||
        m.contains('alfamart')) {
      return 'Food';
    }
    if (m.contains('sm ') ||
        m.contains('ayala') ||
        m.contains('puregold') ||
        m.contains('robinsons')) {
      return 'Shopping';
    }
    return 'Other';
  }
}
