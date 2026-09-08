import 'dart:convert';

/// A one-tap Quick Log preset shown on the dashboard card and the
/// Android Home Screen widget.
class QuickPreset {
  final String id;
  final String icon; // emoji
  final String label;
  final double amount;
  final String category;
  final String? walletId; // null → use default/first wallet

  const QuickPreset({
    required this.id,
    required this.icon,
    required this.label,
    required this.amount,
    required this.category,
    this.walletId,
  });

  QuickPreset copyWith({
    String? id,
    String? icon,
    String? label,
    double? amount,
    String? category,
    String? walletId,
  }) =>
      QuickPreset(
        id: id ?? this.id,
        icon: icon ?? this.icon,
        label: label ?? this.label,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        walletId: walletId ?? this.walletId,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'icon': icon,
        'label': label,
        'amount': amount,
        'category': category,
        'walletId': walletId,
      };

  factory QuickPreset.fromMap(Map<String, Object?> m) => QuickPreset(
        id: m['id'] as String,
        icon: m['icon'] as String,
        label: m['label'] as String,
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String,
        walletId: m['walletId'] as String?,
      );

  String toJson() => json.encode(toMap());
  factory QuickPreset.fromJson(String src) =>
      QuickPreset.fromMap(json.decode(src) as Map<String, Object?>);

  @override
  bool operator ==(Object other) => other is QuickPreset && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Default presets loaded on first run.
final kDefaultQuickPresets = [
  const QuickPreset(
    id: 'jeep13',
    icon: '🚐',
    label: 'Jeep',
    amount: 13,
    category: 'Transport',
  ),
  const QuickPreset(
    id: 'jeep15',
    icon: '🚐',
    label: 'Jeep+',
    amount: 15,
    category: 'Transport',
  ),
  const QuickPreset(
    id: 'trike25',
    icon: '🛺',
    label: 'Trike',
    amount: 25,
    category: 'Transport',
  ),
  const QuickPreset(
    id: 'coffee120',
    icon: '☕',
    label: 'Coffee',
    amount: 120,
    category: 'Food',
  ),
  const QuickPreset(
    id: 'lunch150',
    icon: '🍱',
    label: 'Lunch',
    amount: 150,
    category: 'Food',
  ),
];
