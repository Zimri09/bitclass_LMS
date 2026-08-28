import 'package:equatable/equatable.dart';

import '../../data/models/models.dart';

/// Assignment Bloc Events
abstract class AssignmentEvent extends Equatable {
  const AssignmentEvent();

  @override
  List<Object?> get props => [];
}

/// Load assignments for a course
class LoadAssignments extends AssignmentEvent {
  final String courseId;
  final bool includeDrafts;

  const LoadAssignments({required this.courseId, this.includeDrafts = false});

  @override
  List<Object?> get props => [courseId, includeDrafts];
}

/// Load a single assignment detail
class LoadAssignmentDetail extends AssignmentEvent {
  final String assignmentId;
  final String userId;

  const LoadAssignmentDetail({
    required this.assignmentId,
    required this.userId,
  });

  @override
  List<Object?> get props => [assignmentId, userId];
}

/// Update code in editor
class UpdateCode extends AssignmentEvent {
  final String code;

  const UpdateCode({required this.code});

  @override
  List<Object?> get props => [code];
}

/// Save draft submission
class SaveDraft extends AssignmentEvent {
  final String assignmentId;
  final String courseId;
  final String userId;
  final String userDisplayName;
  final String code;
  final List<AssignmentAttachment>? attachments;

  const SaveDraft({
    required this.assignmentId,
    required this.courseId,
    required this.userId,
    required this.userDisplayName,
    required this.code,
    this.attachments,
  });

  @override
  List<Object?> get props => [
    assignmentId,
    courseId,
    userId,
    userDisplayName,
    code,
    attachments,
  ];
}

/// Submit assignment
class SubmitAssignment extends AssignmentEvent {
  final String assignmentId;
  final String courseId;
  final String userId;
  final String userDisplayName;
  final String code;
  final List<AssignmentAttachment>? attachments;

  const SubmitAssignment({
    required this.assignmentId,
    required this.courseId,
    required this.userId,
    required this.userDisplayName,
    required this.code,
    this.attachments,
  });

  @override
  List<Object?> get props => [
    assignmentId,
    courseId,
    userId,
    userDisplayName,
    code,
    attachments,
  ];
}

class MarkAssignmentDone extends AssignmentEvent {
  final String assignmentId;
  final String courseId;
  final String userId;
  final String userDisplayName;
  final String code;
  final List<AssignmentAttachment>? attachments;

  const MarkAssignmentDone({
    required this.assignmentId,
    required this.courseId,
    required this.userId,
    required this.userDisplayName,
    this.code = '',
    this.attachments,
  });

  @override
  List<Object?> get props => [
    assignmentId,
    courseId,
    userId,
    userDisplayName,
    code,
    attachments,
  ];
}

class UnsubmitAssignment extends AssignmentEvent {
  final String assignmentId;
  final String userId;

  const UnsubmitAssignment({required this.assignmentId, required this.userId});

  @override
  List<Object?> get props => [assignmentId, userId];
}

/// Grade a submission (instructor only)
class GradeSubmission extends AssignmentEvent {
  final String submissionId;
  final String assignmentId;
  final double score;
  final List<CriterionScore> criterionScores;
  final String feedback;
  final String gradedBy;

  const GradeSubmission({
    required this.submissionId,
    required this.assignmentId,
    required this.score,
    this.criterionScores = const [],
    required this.feedback,
    required this.gradedBy,
  });

  @override
  List<Object?> get props => [
    submissionId,
    assignmentId,
    score,
    criterionScores,
    feedback,
    gradedBy,
  ];
}

/// Load submissions for an assignment (instructor only)
class LoadSubmissions extends AssignmentEvent {
  final String assignmentId;

  const LoadSubmissions({required this.assignmentId});

  @override
  List<Object?> get props => [assignmentId];
}
