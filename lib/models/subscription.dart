enum Cadence { monthly, quarterly, yearly }

extension CadenceX on Cadence {
  String get label {
    switch (this) {
      case Cadence.monthly:
        return 'Monthly';
      case Cadence.quarterly:
        return 'Quarterly';
      case Cadence.yearly:
        return 'Yearly';
    }
  }

  int get monthsPerCycle {
    switch (this) {
      case Cadence.monthly:
        return 1;
      case Cadence.quarterly:
        return 3;
      case Cadence.yearly:
        return 12;
    }
  }
}

class Subscription {
  final String id;
  final String name;
  final double amount;
  final Cadence cadence;
  final DateTime nextBillingDate;
  final String category;
  final String walletId;

  const Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.cadence,
    required this.nextBillingDate,
    required this.category,
    required this.walletId,
  });

  double get monthlyEquivalent => amount / cadence.monthsPerCycle;

  Subscription copyWith({
    String? id,
    String? name,
    double? amount,
    Cadence? cadence,
    DateTime? nextBillingDate,
    String? category,
    String? walletId,
  }) =>
      Subscription(
        id: id ?? this.id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        cadence: cadence ?? this.cadence,
        nextBillingDate: nextBillingDate ?? this.nextBillingDate,
        category: category ?? this.category,
        walletId: walletId ?? this.walletId,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'cadence': cadence.name,
        'next_billing_date': nextBillingDate.millisecondsSinceEpoch,
        'category': category,
        'wallet_id': walletId,
      };

  factory Subscription.fromMap(Map<String, Object?> m) => Subscription(
        id: m['id'] as String,
        name: m['name'] as String,
        amount: (m['amount'] as num).toDouble(),
        cadence: Cadence.values.byName(m['cadence'] as String),
        nextBillingDate:
            DateTime.fromMillisecondsSinceEpoch(m['next_billing_date'] as int),
        category: m['category'] as String,
        walletId: m['wallet_id'] as String,
      );
}
