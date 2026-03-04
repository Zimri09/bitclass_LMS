import 'package:equatable/equatable.dart';

/// Assignment Bloc Events
abstract class AssignmentEvent extends Equatable {
  const AssignmentEvent();

  @override
  List<Object?> get props => [];
}

/// Load assignments for a course
class LoadAssignments extends AssignmentEvent {
  final String courseId;

  const LoadAssignments({required this.courseId});

  @override
  List<Object?> get props => [courseId];
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

  const SaveDraft({
    required this.assignmentId,
    required this.courseId,
    required this.userId,
    required this.userDisplayName,
    required this.code,
  });

  @override
  List<Object?> get props => [
    assignmentId,
    courseId,
    userId,
    userDisplayName,
    code,
  ];
}

/// Submit assignment
class SubmitAssignment extends AssignmentEvent {
  final String assignmentId;
  final String courseId;
  final String userId;
  final String userDisplayName;
  final String code;

  const SubmitAssignment({
    required this.assignmentId,
    required this.courseId,
    required this.userId,
    required this.userDisplayName,
    required this.code,
  });

  @override
  List<Object?> get props => [
    assignmentId,
    courseId,
    userId,
    userDisplayName,
    code,
  ];
}

/// Grade a submission (instructor only)
class GradeSubmission extends AssignmentEvent {
  final String submissionId;
  final String assignmentId;
  final int score;
  final String feedback;
  final String gradedBy;

  const GradeSubmission({
    required this.submissionId,
    required this.assignmentId,
    required this.score,
    required this.feedback,
    required this.gradedBy,
  });

  @override
  List<Object?> get props => [
    submissionId,
    assignmentId,
    score,
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
