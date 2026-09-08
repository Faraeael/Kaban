class Budget {
  final String id;
  final String category;
  final double monthlyLimit;

  const Budget({
    required this.id,
    required this.category,
    required this.monthlyLimit,
  });

  Budget copyWith({String? id, String? category, double? monthlyLimit}) =>
      Budget(
        id: id ?? this.id,
        category: category ?? this.category,
        monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'category': category,
        'monthly_limit': monthlyLimit,
      };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        id: m['id'] as String,
        category: m['category'] as String,
        monthlyLimit: (m['monthly_limit'] as num).toDouble(),
      );
}
