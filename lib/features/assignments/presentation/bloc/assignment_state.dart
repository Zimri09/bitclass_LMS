import 'package:equatable/equatable.dart';

import '../../data/models/models.dart';

/// Assignment Bloc States
abstract class AssignmentState extends Equatable {
  const AssignmentState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class AssignmentInitial extends AssignmentState {}

/// Loading assignments list
class AssignmentsLoading extends AssignmentState {}

/// Assignments loaded successfully
class AssignmentsLoaded extends AssignmentState {
  final List<AssignmentModel> assignments;
  final String courseId;

  const AssignmentsLoaded({required this.assignments, required this.courseId});

  @override
  List<Object?> get props => [assignments, courseId];
}

/// Loading assignment detail
class AssignmentDetailLoading extends AssignmentState {}

/// Assignment detail loaded with user's submission
class AssignmentDetailLoaded extends AssignmentState {
  final AssignmentModel assignment;
  final SubmissionModel? submission;
  final String currentCode;
  final bool hasChanges;
  final bool isSaving;
  final bool isSubmitting;

  const AssignmentDetailLoaded({
    required this.assignment,
    this.submission,
    required this.currentCode,
    this.hasChanges = false,
    this.isSaving = false,
    this.isSubmitting = false,
  });

  @override
  List<Object?> get props => [
    assignment,
    submission,
    currentCode,
    hasChanges,
    isSaving,
    isSubmitting,
  ];

  AssignmentDetailLoaded copyWith({
    AssignmentModel? assignment,
    SubmissionModel? submission,
    String? currentCode,
    bool? hasChanges,
    bool? isSaving,
    bool? isSubmitting,
  }) {
    return AssignmentDetailLoaded(
      assignment: assignment ?? this.assignment,
      submission: submission ?? this.submission,
      currentCode: currentCode ?? this.currentCode,
      hasChanges: hasChanges ?? this.hasChanges,
      isSaving: isSaving ?? this.isSaving,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// Draft saved successfully
class DraftSaved extends AssignmentState {
  final SubmissionModel submission;

  const DraftSaved({required this.submission});

  @override
  List<Object?> get props => [submission];
}

/// Assignment submitted successfully
class AssignmentSubmitted extends AssignmentState {
  final SubmissionModel submission;

  const AssignmentSubmitted({required this.submission});

  @override
  List<Object?> get props => [submission];
}

/// Submissions loaded (instructor view)
class SubmissionsLoaded extends AssignmentState {
  final AssignmentModel assignment;
  final List<SubmissionModel> submissions;

  const SubmissionsLoaded({
    required this.assignment,
    required this.submissions,
  });

  @override
  List<Object?> get props => [assignment, submissions];
}

/// Submission graded
class SubmissionGraded extends AssignmentState {
  final SubmissionModel submission;

  const SubmissionGraded({required this.submission});

  @override
  List<Object?> get props => [submission];
}

/// Error state
class AssignmentError extends AssignmentState {
  final String message;

  const AssignmentError({required this.message});

  @override
  List<Object?> get props => [message];
}
