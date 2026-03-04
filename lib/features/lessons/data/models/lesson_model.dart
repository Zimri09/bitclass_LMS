import 'package:equatable/equatable.dart';

/// Lesson type enum
enum LessonType {
  text,
  video,
  code,
  quiz;

  static LessonType fromString(String value) {
    return LessonType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LessonType.text,
    );
  }
}

/// Lesson model representing a single lesson within a module
class LessonModel extends Equatable {
  final String id;
  final String courseId;
  final String moduleId;
  final String title;
  final String? description;
  final int order;
  final LessonType type;
  final String? content; // Markdown content
  final String? videoUrl;
  final int durationMinutes;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const LessonModel({
    required this.id,
    required this.courseId,
    required this.moduleId,
    required this.title,
    this.description,
    required this.order,
    required this.type,
    this.content,
    this.videoUrl,
    required this.durationMinutes,
    required this.isPublished,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create LessonModel from Firestore document
  factory LessonModel.fromMap(Map<String, dynamic> map, String id) {
    return LessonModel(
      id: id,
      courseId: map['courseId'] as String,
      moduleId: map['moduleId'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      order: map['order'] as int? ?? 0,
      type: LessonType.fromString(map['type'] as String? ?? 'text'),
      content: map['content'] as String?,
      videoUrl: map['videoUrl'] as String?,
      durationMinutes: map['durationMinutes'] as int? ?? 5,
      isPublished: map['isPublished'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  /// Convert LessonModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'moduleId': moduleId,
      'title': title,
      'description': description,
      'order': order,
      'type': type.name,
      'content': content,
      'videoUrl': videoUrl,
      'durationMinutes': durationMinutes,
      'isPublished': isPublished,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  LessonModel copyWith({
    String? id,
    String? courseId,
    String? moduleId,
    String? title,
    String? description,
    int? order,
    LessonType? type,
    String? content,
    String? videoUrl,
    int? durationMinutes,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LessonModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      moduleId: moduleId ?? this.moduleId,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      type: type ?? this.type,
      content: content ?? this.content,
      videoUrl: videoUrl ?? this.videoUrl,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    courseId,
    moduleId,
    title,
    description,
    order,
    type,
    content,
    videoUrl,
    durationMinutes,
    isPublished,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() => 'LessonModel($id, $title, type: ${type.name})';
}
