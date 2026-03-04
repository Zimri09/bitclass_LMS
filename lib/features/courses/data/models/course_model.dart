import 'package:equatable/equatable.dart';

/// Course model representing a course in the system
class CourseModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String category;
  final String instructorId;
  final String instructorName;
  final String? thumbnailUrl;
  final int enrollmentCount;
  final int lessonCount;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.instructorId,
    required this.instructorName,
    this.thumbnailUrl,
    this.enrollmentCount = 0,
    this.lessonCount = 0,
    this.isPublished = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create CourseModel from Firestore document
  factory CourseModel.fromMap(Map<String, dynamic> map, String id) {
    return CourseModel(
      id: id,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      instructorId: map['instructorId'] as String,
      instructorName: map['instructorName'] as String? ?? 'Unknown',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      enrollmentCount: map['enrollmentCount'] as int? ?? 0,
      lessonCount: map['lessonCount'] as int? ?? 0,
      isPublished: map['isPublished'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  /// Convert CourseModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'instructorId': instructorId,
      'instructorName': instructorName,
      'thumbnailUrl': thumbnailUrl,
      'enrollmentCount': enrollmentCount,
      'lessonCount': lessonCount,
      'isPublished': isPublished,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Alias for toMap for JSON compatibility
  Map<String, dynamic> toJson() => {'id': id, ...toMap()};

  /// Create CourseModel from JSON
  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel.fromMap(json, json['id'] as String);
  }

  /// Create a copy with updated fields
  CourseModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? instructorId,
    String? instructorName,
    String? thumbnailUrl,
    int? enrollmentCount,
    int? lessonCount,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CourseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      instructorId: instructorId ?? this.instructorId,
      instructorName: instructorName ?? this.instructorName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      enrollmentCount: enrollmentCount ?? this.enrollmentCount,
      lessonCount: lessonCount ?? this.lessonCount,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    category,
    instructorId,
    instructorName,
    thumbnailUrl,
    enrollmentCount,
    lessonCount,
    isPublished,
    createdAt,
    updatedAt,
  ];
}

/// Enrollment model representing a student's enrollment in a course
class EnrollmentModel extends Equatable {
  final String id;
  final String courseId;
  final String userId;
  final String? studentName;
  final String? studentEmail;
  final double progress; // 0.0 to 1.0
  final int completedLessons;
  final int totalLessons;
  final DateTime enrolledAt;
  final DateTime? completedAt;
  final DateTime? lastAccessedAt;

  const EnrollmentModel({
    required this.id,
    required this.courseId,
    required this.userId,
    this.studentName,
    this.studentEmail,
    this.progress = 0.0,
    this.completedLessons = 0,
    this.totalLessons = 0,
    required this.enrolledAt,
    this.completedAt,
    this.lastAccessedAt,
  });

  /// Create EnrollmentModel from Firestore document
  factory EnrollmentModel.fromMap(Map<String, dynamic> map, String id) {
    return EnrollmentModel(
      id: id,
      courseId: map['courseId'] as String,
      userId: map['userId'] as String,
      studentName: map['studentName'] as String?,
      studentEmail: map['studentEmail'] as String?,
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      completedLessons: map['completedLessons'] as int? ?? 0,
      totalLessons: map['totalLessons'] as int? ?? 0,
      enrolledAt: map['enrolledAt'] != null
          ? DateTime.parse(map['enrolledAt'] as String)
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      lastAccessedAt: map['lastAccessedAt'] != null
          ? DateTime.parse(map['lastAccessedAt'] as String)
          : null,
    );
  }

  /// Convert EnrollmentModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'userId': userId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'progress': progress,
      'completedLessons': completedLessons,
      'totalLessons': totalLessons,
      'enrolledAt': enrolledAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'lastAccessedAt': lastAccessedAt?.toIso8601String(),
    };
  }

  /// Check if course is completed
  bool get isCompleted => completedAt != null || progress >= 1.0;

  /// Get progress percentage
  int get progressPercent => (progress * 100).toInt();

  @override
  List<Object?> get props => [
    id,
    courseId,
    userId,
    studentName,
    studentEmail,
    progress,
    completedLessons,
    totalLessons,
    enrolledAt,
    completedAt,
    lastAccessedAt,
  ];
}
