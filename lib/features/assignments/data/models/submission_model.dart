import 'package:equatable/equatable.dart';

/// Submission status enum
enum SubmissionStatus {
  draft,
  submitted,
  grading,
  graded,
  returned;

  static SubmissionStatus fromString(String value) {
    return SubmissionStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => SubmissionStatus.draft,
    );
  }

  String get displayName {
    switch (this) {
      case SubmissionStatus.draft:
        return 'Draft';
      case SubmissionStatus.submitted:
        return 'Submitted';
      case SubmissionStatus.grading:
        return 'Grading';
      case SubmissionStatus.graded:
        return 'Graded';
      case SubmissionStatus.returned:
        return 'Returned';
    }
  }
}

/// Submission model representing a student's submission for an assignment
class SubmissionModel extends Equatable {
  final String id;
  final String assignmentId;
  final String courseId;
  final String userId;
  final String userDisplayName;
  final String code;
  final SubmissionStatus status;
  final int? score;
  final String? feedback;
  final String? gradedBy; // Instructor userId who graded
  final DateTime? gradedAt;
  final bool isLate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;

  const SubmissionModel({
    required this.id,
    required this.assignmentId,
    required this.courseId,
    required this.userId,
    required this.userDisplayName,
    required this.code,
    this.status = SubmissionStatus.draft,
    this.score,
    this.feedback,
    this.gradedBy,
    this.gradedAt,
    this.isLate = false,
    required this.createdAt,
    this.updatedAt,
    this.submittedAt,
  });

  @override
  List<Object?> get props => [
    id,
    assignmentId,
    courseId,
    userId,
    userDisplayName,
    code,
    status,
    score,
    feedback,
    gradedBy,
    gradedAt,
    isLate,
    createdAt,
    updatedAt,
    submittedAt,
  ];

  factory SubmissionModel.fromMap(Map<String, dynamic> map) {
    return SubmissionModel(
      id: map['id'] as String,
      assignmentId: map['assignmentId'] as String,
      courseId: map['courseId'] as String,
      userId: map['userId'] as String,
      userDisplayName: map['userDisplayName'] as String? ?? 'Unknown User',
      code: map['code'] as String? ?? '',
      status: SubmissionStatus.fromString(map['status'] as String? ?? 'draft'),
      score: map['score'] as int?,
      feedback: map['feedback'] as String?,
      gradedBy: map['gradedBy'] as String?,
      gradedAt: map['gradedAt'] != null
          ? DateTime.parse(map['gradedAt'] as String)
          : null,
      isLate: map['isLate'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      submittedAt: map['submittedAt'] != null
          ? DateTime.parse(map['submittedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'assignmentId': assignmentId,
      'courseId': courseId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'code': code,
      'status': status.name,
      'score': score,
      'feedback': feedback,
      'gradedBy': gradedBy,
      'gradedAt': gradedAt?.toIso8601String(),
      'isLate': isLate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
    };
  }

  SubmissionModel copyWith({
    String? id,
    String? assignmentId,
    String? courseId,
    String? userId,
    String? userDisplayName,
    String? code,
    SubmissionStatus? status,
    int? score,
    String? feedback,
    String? gradedBy,
    DateTime? gradedAt,
    bool? isLate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? submittedAt,
  }) {
    return SubmissionModel(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      courseId: courseId ?? this.courseId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      code: code ?? this.code,
      status: status ?? this.status,
      score: score ?? this.score,
      feedback: feedback ?? this.feedback,
      gradedBy: gradedBy ?? this.gradedBy,
      gradedAt: gradedAt ?? this.gradedAt,
      isLate: isLate ?? this.isLate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  /// Check if submission is graded
  bool get isGraded => status == SubmissionStatus.graded;

  /// Check if submission is submitted (not draft)
  bool get isSubmitted =>
      status == SubmissionStatus.submitted ||
      status == SubmissionStatus.grading ||
      status == SubmissionStatus.graded ||
      status == SubmissionStatus.returned;

  /// Get percentage score
  double? getPercentage(int maxPoints) {
    if (score == null || maxPoints == 0) return null;
    return (score! / maxPoints) * 100;
  }
}
