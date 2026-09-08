import 'transaction.dart';

class RecurringTransaction {
  final String id;
  final String name;
  final double amount;
  final TransactionType type;
  final String category;
  final int intervalDays;
  final DateTime nextDue;
  final String walletId;
  final bool enabled;

  const RecurringTransaction({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.category,
    required this.intervalDays,
    required this.nextDue,
    required this.walletId,
    this.enabled = true,
  });

  String get frequencyLabel {
    if (intervalDays == 1) return 'Daily';
    if (intervalDays == 7) return 'Weekly';
    if (intervalDays == 14) return 'Every 2 weeks';
    if (intervalDays == 30) return 'Monthly';
    return 'Every $intervalDays days';
  }

  RecurringTransaction copyWith({
    String? id,
    String? name,
    double? amount,
    TransactionType? type,
    String? category,
    int? intervalDays,
    DateTime? nextDue,
    String? walletId,
    bool? enabled,
  }) =>
      RecurringTransaction(
        id: id ?? this.id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        category: category ?? this.category,
        intervalDays: intervalDays ?? this.intervalDays,
        nextDue: nextDue ?? this.nextDue,
        walletId: walletId ?? this.walletId,
        enabled: enabled ?? this.enabled,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'type': type.name,
        'category': category,
        'interval_days': intervalDays,
        'next_due': nextDue.millisecondsSinceEpoch,
        'wallet_id': walletId,
        'enabled': enabled ? 1 : 0,
      };

  factory RecurringTransaction.fromMap(Map<String, Object?> m) =>
      RecurringTransaction(
        id: m['id'] as String,
        name: m['name'] as String,
        amount: (m['amount'] as num).toDouble(),
        type: TransactionType.values.byName(m['type'] as String),
        category: m['category'] as String,
        intervalDays: m['interval_days'] as int,
        nextDue: DateTime.fromMillisecondsSinceEpoch(m['next_due'] as int),
        walletId: m['wallet_id'] as String,
        enabled: (m['enabled'] as int? ?? 1) == 1,
      );
}
