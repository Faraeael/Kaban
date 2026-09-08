enum TransactionType { income, expense, transfer }

class Transaction {
  final String id;
  final double amount;
  final TransactionType type;
  final String category;
  final String? note;
  final DateTime date;
  final String walletId;
  final String? transferPairId;
  final bool autoCaptured;

  const Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    this.note,
    required this.date,
    required this.walletId,
    this.transferPairId,
    this.autoCaptured = false,
  });

  Transaction copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? category,
    String? note,
    DateTime? date,
    String? walletId,
    String? transferPairId,
    bool? autoCaptured,
  }) =>
      Transaction(
        id: id ?? this.id,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        category: category ?? this.category,
        note: note ?? this.note,
        date: date ?? this.date,
        walletId: walletId ?? this.walletId,
        transferPairId: transferPairId ?? this.transferPairId,
        autoCaptured: autoCaptured ?? this.autoCaptured,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'amount': amount,
        'type': type.name,
        'category': category,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'wallet_id': walletId,
        'transfer_pair_id': transferPairId,
        'auto_captured': autoCaptured ? 1 : 0,
      };

  factory Transaction.fromMap(Map<String, Object?> m) => Transaction(
        id: m['id'] as String,
        amount: (m['amount'] as num).toDouble(),
        type: TransactionType.values.byName(m['type'] as String),
        category: m['category'] as String,
        note: m['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        walletId: m['wallet_id'] as String,
        transferPairId: m['transfer_pair_id'] as String?,
        autoCaptured: (m['auto_captured'] as int? ?? 0) == 1,
      );
}

const List<String> kDefaultExpenseCategories = [
  'Food',
  'Transport',
  'Housing',
  'Utilities',
  'Entertainment',
  'Health',
  'Shopping',
  'Subscriptions',
  'Other',
];

const List<String> kDefaultIncomeCategories = [
  'Salary',
  'Freelance',
  'Gift',
  'Refund',
  'Investment',
  'Other',
];