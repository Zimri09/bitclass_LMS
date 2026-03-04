import 'package:equatable/equatable.dart';

/// Lesson progress model tracking user progress on a lesson
class LessonProgressModel extends Equatable {
  final String id;
  final String lessonId;
  final String enrollmentId;
  final String userId;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? lastAccessedAt;
  final Map<String, dynamic>?
  savedState; // For saving code editor state, video position, etc.

  const LessonProgressModel({
    required this.id,
    required this.lessonId,
    required this.enrollmentId,
    required this.userId,
    required this.isCompleted,
    this.completedAt,
    this.lastAccessedAt,
    this.savedState,
  });

  /// Create LessonProgressModel from Firestore document
  factory LessonProgressModel.fromMap(Map<String, dynamic> map, String id) {
    return LessonProgressModel(
      id: id,
      lessonId: map['lessonId'] as String,
      enrollmentId: map['enrollmentId'] as String,
      userId: map['userId'] as String,
      isCompleted: map['isCompleted'] as bool? ?? false,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      lastAccessedAt: map['lastAccessedAt'] != null
          ? DateTime.parse(map['lastAccessedAt'] as String)
          : null,
      savedState: map['savedState'] as Map<String, dynamic>?,
    );
  }

  /// Convert LessonProgressModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'lessonId': lessonId,
      'enrollmentId': enrollmentId,
      'userId': userId,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'lastAccessedAt': lastAccessedAt?.toIso8601String(),
      'savedState': savedState,
    };
  }

  /// Create a copy with updated fields
  LessonProgressModel copyWith({
    String? id,
    String? lessonId,
    String? enrollmentId,
    String? userId,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? lastAccessedAt,
    Map<String, dynamic>? savedState,
  }) {
    return LessonProgressModel(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      enrollmentId: enrollmentId ?? this.enrollmentId,
      userId: userId ?? this.userId,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      savedState: savedState ?? this.savedState,
    );
  }

  @override
  List<Object?> get props => [
    id,
    lessonId,
    enrollmentId,
    userId,
    isCompleted,
    completedAt,
    lastAccessedAt,
    savedState,
  ];

  @override
  String toString() =>
      'LessonProgressModel($id, lessonId: $lessonId, completed: $isCompleted)';
}
