class Goal {
  final String id;
  final String name;
  final double target;
  final double saved;
  final DateTime? deadline;

  const Goal({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    this.deadline,
  });

  double get progress => target <= 0 ? 0 : (saved / target).clamp(0, 1);

  Goal copyWith({
    String? id,
    String? name,
    double? target,
    double? saved,
    DateTime? deadline,
    bool clearDeadline = false,
  }) =>
      Goal(
        id: id ?? this.id,
        name: name ?? this.name,
        target: target ?? this.target,
        saved: saved ?? this.saved,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'target': target,
        'saved': saved,
        'deadline': deadline?.millisecondsSinceEpoch,
      };

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as String,
        name: m['name'] as String,
        target: (m['target'] as num).toDouble(),
        saved: (m['saved'] as num).toDouble(),
        deadline: m['deadline'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['deadline'] as int),
      );
}
