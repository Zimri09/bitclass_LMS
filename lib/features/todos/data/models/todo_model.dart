class TodoModel {
  final String id;
  final String name;
  final bool isCompleted;
  final String? dueAtIso;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TodoModel({
    required this.id,
    required this.name,
    required this.isCompleted,
    this.dueAtIso,
    required this.createdAt,
    this.updatedAt,
  });

  factory TodoModel.fromMap(Map<String, dynamic> map, String id) {
    return TodoModel(
      id: id,
      name: map['name'] as String,
      isCompleted: map['is_completed'] as bool? ?? false,
      dueAtIso: map['due_at']?.toString(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_completed': isCompleted,
      'due_at': dueAtIso,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  TodoModel copyWith({
    String? id,
    String? name,
    bool? isCompleted,
    String? dueAtIso,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isCompleted: isCompleted ?? this.isCompleted,
      dueAtIso: dueAtIso ?? this.dueAtIso,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
