import 'package:equatable/equatable.dart';

import 'assignment_attachment.dart';
import 'assignment_model.dart';
import 'criterion_score.dart';

/// Submission status enum
enum SubmissionStatus {
  draft,
  submitted,
  grading,
  graded,
  returned,
  done;

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
      case SubmissionStatus.done:
        return 'Done';
    }
  }
}

enum ClassroomSubmissionStatus {
  assigned,
  submitted,
  done,
  missing,
  late;

  String get displayName {
    switch (this) {
      case ClassroomSubmissionStatus.assigned:
        return 'Assigned';
      case ClassroomSubmissionStatus.submitted:
        return 'Submitted';
      case ClassroomSubmissionStatus.done:
        return 'Done';
      case ClassroomSubmissionStatus.missing:
        return 'Missing';
      case ClassroomSubmissionStatus.late:
        return 'Late';
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
  final ProgrammingLanguage language;
  final List<AssignmentAttachment> attachments;
  final SubmissionStatus status;
  final double? score;
  final List<CriterionScore> criterionScores;
  final String? assignmentTitle;
  final int? assignmentMaxPoints;
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
    this.language = ProgrammingLanguage.plaintext,
    this.attachments = const [],
    this.status = SubmissionStatus.draft,
    this.score,
    this.criterionScores = const [],
    this.assignmentTitle,
    this.assignmentMaxPoints,
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
    language,
    attachments,
    status,
    score,
    criterionScores,
    assignmentTitle,
    assignmentMaxPoints,
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
      language: ProgrammingLanguage.fromString(
        map['language'] as String? ?? 'plaintext',
      ),
      attachments: ((map['attachments'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                AssignmentAttachment.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      status: SubmissionStatus.fromString(map['status'] as String? ?? 'draft'),
      score: (map['score'] as num?)?.toDouble(),
      criterionScores: ((map['criterionScores'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => CriterionScore.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      assignmentTitle: map['assignmentTitle'] as String?,
      assignmentMaxPoints: (map['assignmentMaxPoints'] as num?)?.toInt(),
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
      'language': language.name,
      'attachments': attachments.map((item) => item.toMap()).toList(),
      'status': status.name,
      'score': score,
      'criterionScores': criterionScores.map((item) => item.toMap()).toList(),
      'assignmentTitle': assignmentTitle,
      'assignmentMaxPoints': assignmentMaxPoints,
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
    ProgrammingLanguage? language,
    List<AssignmentAttachment>? attachments,
    SubmissionStatus? status,
    double? score,
    List<CriterionScore>? criterionScores,
    String? assignmentTitle,
    int? assignmentMaxPoints,
    String? feedback,
    String? gradedBy,
    DateTime? gradedAt,
    bool? isLate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? submittedAt,
    bool clearSubmittedAt = false,
  }) {
    return SubmissionModel(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      courseId: courseId ?? this.courseId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      code: code ?? this.code,
      language: language ?? this.language,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
      score: score ?? this.score,
      criterionScores: criterionScores ?? this.criterionScores,
      assignmentTitle: assignmentTitle ?? this.assignmentTitle,
      assignmentMaxPoints: assignmentMaxPoints ?? this.assignmentMaxPoints,
      feedback: feedback ?? this.feedback,
      gradedBy: gradedBy ?? this.gradedBy,
      gradedAt: gradedAt ?? this.gradedAt,
      isLate: isLate ?? this.isLate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: clearSubmittedAt ? null : submittedAt ?? this.submittedAt,
    );
  }

  /// Check if submission is graded
  bool get isGraded => status == SubmissionStatus.graded;

  /// Check if submission is submitted (not draft)
  bool get isSubmitted =>
      status == SubmissionStatus.submitted ||
      status == SubmissionStatus.grading ||
      status == SubmissionStatus.graded ||
      status == SubmissionStatus.returned ||
      status == SubmissionStatus.done;

  bool get isCompleted => isSubmitted;

  /// Maximum points from the related saved assignment.
  ///
  /// The fallback keeps older/demo submissions compatible. Grade queries
  /// populate [assignmentMaxPoints] directly from the assignments table.
  int get resolvedMaxPoints => assignmentMaxPoints ?? 100;

  String get assignmentDisplayTitle {
    final title = assignmentTitle?.trim();
    return title == null || title.isEmpty ? 'Activity Submission' : title;
  }

  ClassroomSubmissionStatus classroomStatus(
    AssignmentModel assignment, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    if (isCompleted) {
      if (isLate) return ClassroomSubmissionStatus.late;
      if (status == SubmissionStatus.done) {
        return ClassroomSubmissionStatus.done;
      }
      return ClassroomSubmissionStatus.submitted;
    }
    if (assignment.dueDate != null &&
        currentTime.isAfter(assignment.dueDate!)) {
      return ClassroomSubmissionStatus.missing;
    }
    return ClassroomSubmissionStatus.assigned;
  }

  bool canUnsubmit(AssignmentModel assignment, {DateTime? now}) {
    if (status != SubmissionStatus.submitted &&
        status != SubmissionStatus.done) {
      return false;
    }
    final dueDate = assignment.dueDate;
    return dueDate == null || !(now ?? DateTime.now()).isAfter(dueDate);
  }

  /// Get percentage score
  double? getPercentage(int maxPoints) {
    if (score == null || maxPoints == 0) return null;
    return (score! / maxPoints) * 100;
  }
}
