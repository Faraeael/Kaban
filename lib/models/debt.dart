enum DebtStrategy { avalanche, snowball }

extension DebtStrategyX on DebtStrategy {
  String get label {
    switch (this) {
      case DebtStrategy.avalanche:
        return 'Avalanche (highest APR first)';
      case DebtStrategy.snowball:
        return 'Snowball (smallest balance first)';
    }
  }

  String get shortLabel {
    switch (this) {
      case DebtStrategy.avalanche:
        return 'Avalanche';
      case DebtStrategy.snowball:
        return 'Snowball';
    }
  }
}

enum DebtSchedule { none, fixed, statementCycle }

extension DebtScheduleX on DebtSchedule {
  String get label => switch (this) {
        DebtSchedule.none => 'No schedule',
        DebtSchedule.fixed => 'Fixed monthly',
        DebtSchedule.statementCycle => 'Statement cycle (credit card)',
      };
}

class Debt {
  final String id;
  final String name;
  final double balance;
  final double apr;
  final double minPayment;
  final DebtStrategy strategy;
  final String? linkedWalletId;
  final DebtSchedule schedule;
  final int? dueDay;
  final int? remainingPayments;
  final bool paidOff;
  final int? billingDay;
  final int? graceDays;

  const Debt({
    required this.id,
    required this.name,
    required this.balance,
    required this.apr,
    required this.minPayment,
    required this.strategy,
    this.linkedWalletId,
    this.schedule = DebtSchedule.none,
    this.dueDay,
    this.remainingPayments,
    this.paidOff = false,
    this.billingDay,
    this.graceDays,
  });

  Debt copyWith({
    String? id,
    String? name,
    double? balance,
    double? apr,
    double? minPayment,
    DebtStrategy? strategy,
    String? linkedWalletId,
    bool clearLinkedWallet = false,
    DebtSchedule? schedule,
    int? dueDay,
    bool clearDueDay = false,
    int? remainingPayments,
    bool clearRemainingPayments = false,
    bool? paidOff,
    int? billingDay,
    bool clearBillingDay = false,
    int? graceDays,
    bool clearGraceDays = false,
  }) =>
      Debt(
        id: id ?? this.id,
        name: name ?? this.name,
        balance: balance ?? this.balance,
        apr: apr ?? this.apr,
        minPayment: minPayment ?? this.minPayment,
        strategy: strategy ?? this.strategy,
        linkedWalletId:
            clearLinkedWallet ? null : (linkedWalletId ?? this.linkedWalletId),
        schedule: schedule ?? this.schedule,
        dueDay: clearDueDay ? null : (dueDay ?? this.dueDay),
        remainingPayments: clearRemainingPayments
            ? null
            : (remainingPayments ?? this.remainingPayments),
        paidOff: paidOff ?? this.paidOff,
        billingDay: clearBillingDay ? null : (billingDay ?? this.billingDay),
        graceDays: clearGraceDays ? null : (graceDays ?? this.graceDays),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'balance': balance,
        'apr': apr,
        'min_payment': minPayment,
        'strategy': strategy.name,
        'linked_wallet_id': linkedWalletId,
        'schedule': schedule.name,
        'due_day': dueDay,
        'remaining_payments': remainingPayments,
        'paid_off': paidOff ? 1 : 0,
        'billing_day': billingDay,
        'grace_days': graceDays,
      };

  factory Debt.fromMap(Map<String, Object?> m) => Debt(
        id: m['id'] as String,
        name: m['name'] as String,
        balance: (m['balance'] as num).toDouble(),
        apr: (m['apr'] as num).toDouble(),
        minPayment: (m['min_payment'] as num).toDouble(),
        strategy: DebtStrategy.values.byName(m['strategy'] as String),
        linkedWalletId: m['linked_wallet_id'] as String?,
        schedule:
            DebtSchedule.values.byName(m['schedule'] as String? ?? 'none'),
        dueDay: m['due_day'] as int?,
        remainingPayments: m['remaining_payments'] as int?,
        paidOff: (m['paid_off'] as int? ?? 0) == 1,
        billingDay: m['billing_day'] as int?,
        graceDays: m['grace_days'] as int?,
      );
}
