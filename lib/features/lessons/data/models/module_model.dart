import 'package:equatable/equatable.dart';

/// Module model representing a course section/chapter
class ModuleModel extends Equatable {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final int order;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ModuleModel({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.order,
    required this.isPublished,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create ModuleModel from Firestore document
  factory ModuleModel.fromMap(Map<String, dynamic> map, String id) {
    return ModuleModel(
      id: id,
      courseId: map['courseId'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      order: map['order'] as int? ?? 0,
      isPublished: map['isPublished'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  /// Convert ModuleModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'title': title,
      'description': description,
      'order': order,
      'isPublished': isPublished,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  ModuleModel copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    int? order,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ModuleModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    courseId,
    title,
    description,
    order,
    isPublished,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() => 'ModuleModel($id, $title, order: $order)';
}
