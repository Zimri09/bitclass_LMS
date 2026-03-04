import 'package:equatable/equatable.dart';

/// Programming language type for code assignments
enum ProgrammingLanguage {
  dart,
  python,
  javascript,
  java,
  cpp,
  csharp,
  go,
  rust,
  typescript,
  sql,
  html,
  css,
  plaintext;

  static ProgrammingLanguage fromString(String value) {
    return ProgrammingLanguage.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ProgrammingLanguage.plaintext,
    );
  }

  String get displayName {
    switch (this) {
      case ProgrammingLanguage.dart:
        return 'Dart';
      case ProgrammingLanguage.python:
        return 'Python';
      case ProgrammingLanguage.javascript:
        return 'JavaScript';
      case ProgrammingLanguage.java:
        return 'Java';
      case ProgrammingLanguage.cpp:
        return 'C++';
      case ProgrammingLanguage.csharp:
        return 'C#';
      case ProgrammingLanguage.go:
        return 'Go';
      case ProgrammingLanguage.rust:
        return 'Rust';
      case ProgrammingLanguage.typescript:
        return 'TypeScript';
      case ProgrammingLanguage.sql:
        return 'SQL';
      case ProgrammingLanguage.html:
        return 'HTML';
      case ProgrammingLanguage.css:
        return 'CSS';
      case ProgrammingLanguage.plaintext:
        return 'Plain Text';
    }
  }

  String get fileExtension {
    switch (this) {
      case ProgrammingLanguage.dart:
        return '.dart';
      case ProgrammingLanguage.python:
        return '.py';
      case ProgrammingLanguage.javascript:
        return '.js';
      case ProgrammingLanguage.java:
        return '.java';
      case ProgrammingLanguage.cpp:
        return '.cpp';
      case ProgrammingLanguage.csharp:
        return '.cs';
      case ProgrammingLanguage.go:
        return '.go';
      case ProgrammingLanguage.rust:
        return '.rs';
      case ProgrammingLanguage.typescript:
        return '.ts';
      case ProgrammingLanguage.sql:
        return '.sql';
      case ProgrammingLanguage.html:
        return '.html';
      case ProgrammingLanguage.css:
        return '.css';
      case ProgrammingLanguage.plaintext:
        return '.txt';
    }
  }
}

/// Assignment model representing a code-based assignment in a course
class AssignmentModel extends Equatable {
  final String id;
  final String courseId;
  final String? lessonId;
  final String title;
  final String description;
  final String? instructions; // Markdown instructions
  final ProgrammingLanguage language;
  final String? starterCode; // Initial code provided to students
  final String? solutionCode; // Reference solution (hidden from students)
  final int maxPoints;
  final DateTime? dueDate;
  final bool allowLateSubmission;
  final int latePenaltyPercent; // Percentage deducted for late submission
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AssignmentModel({
    required this.id,
    required this.courseId,
    this.lessonId,
    required this.title,
    required this.description,
    this.instructions,
    required this.language,
    this.starterCode,
    this.solutionCode,
    this.maxPoints = 100,
    this.dueDate,
    this.allowLateSubmission = true,
    this.latePenaltyPercent = 10,
    this.isPublished = false,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    courseId,
    lessonId,
    title,
    description,
    instructions,
    language,
    starterCode,
    solutionCode,
    maxPoints,
    dueDate,
    allowLateSubmission,
    latePenaltyPercent,
    isPublished,
    createdAt,
    updatedAt,
  ];

  factory AssignmentModel.fromMap(Map<String, dynamic> map) {
    return AssignmentModel(
      id: map['id'] as String,
      courseId: map['courseId'] as String,
      lessonId: map['lessonId'] as String?,
      title: map['title'] as String,
      description: map['description'] as String,
      instructions: map['instructions'] as String?,
      language: ProgrammingLanguage.fromString(
        map['language'] as String? ?? 'plaintext',
      ),
      starterCode: map['starterCode'] as String?,
      solutionCode: map['solutionCode'] as String?,
      maxPoints: map['maxPoints'] as int? ?? 100,
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'] as String)
          : null,
      allowLateSubmission: map['allowLateSubmission'] as bool? ?? true,
      latePenaltyPercent: map['latePenaltyPercent'] as int? ?? 10,
      isPublished: map['isPublished'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'lessonId': lessonId,
      'title': title,
      'description': description,
      'instructions': instructions,
      'language': language.name,
      'starterCode': starterCode,
      'solutionCode': solutionCode,
      'maxPoints': maxPoints,
      'dueDate': dueDate?.toIso8601String(),
      'allowLateSubmission': allowLateSubmission,
      'latePenaltyPercent': latePenaltyPercent,
      'isPublished': isPublished,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  AssignmentModel copyWith({
    String? id,
    String? courseId,
    String? lessonId,
    String? title,
    String? description,
    String? instructions,
    ProgrammingLanguage? language,
    String? starterCode,
    String? solutionCode,
    int? maxPoints,
    DateTime? dueDate,
    bool? allowLateSubmission,
    int? latePenaltyPercent,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssignmentModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      title: title ?? this.title,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      language: language ?? this.language,
      starterCode: starterCode ?? this.starterCode,
      solutionCode: solutionCode ?? this.solutionCode,
      maxPoints: maxPoints ?? this.maxPoints,
      dueDate: dueDate ?? this.dueDate,
      allowLateSubmission: allowLateSubmission ?? this.allowLateSubmission,
      latePenaltyPercent: latePenaltyPercent ?? this.latePenaltyPercent,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if assignment is past due date
  bool get isPastDue {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Get time remaining until due date
  Duration? get timeRemaining {
    if (dueDate == null) return null;
    final now = DateTime.now();
    if (now.isAfter(dueDate!)) return Duration.zero;
    return dueDate!.difference(now);
  }
}
