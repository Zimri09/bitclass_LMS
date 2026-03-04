import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/assignment_repository.dart';
import 'assignment_event.dart';
import 'assignment_state.dart';

/// Bloc for managing assignment operations
class AssignmentBloc extends Bloc<AssignmentEvent, AssignmentState> {
  final AssignmentRepository assignmentRepository;

  AssignmentBloc({required this.assignmentRepository})
    : super(AssignmentInitial()) {
    on<LoadAssignments>(_onLoadAssignments);
    on<LoadAssignmentDetail>(_onLoadAssignmentDetail);
    on<UpdateCode>(_onUpdateCode);
    on<SaveDraft>(_onSaveDraft);
    on<SubmitAssignment>(_onSubmitAssignment);
    on<GradeSubmission>(_onGradeSubmission);
    on<LoadSubmissions>(_onLoadSubmissions);
  }

  Future<void> _onLoadAssignments(
    LoadAssignments event,
    Emitter<AssignmentState> emit,
  ) async {
    emit(AssignmentsLoading());
    try {
      final assignments = await assignmentRepository.getAssignmentsForCourse(
        event.courseId,
      );
      emit(
        AssignmentsLoaded(assignments: assignments, courseId: event.courseId),
      );
    } catch (e) {
      emit(AssignmentError(message: 'Failed to load assignments: $e'));
    }
  }

  Future<void> _onLoadAssignmentDetail(
    LoadAssignmentDetail event,
    Emitter<AssignmentState> emit,
  ) async {
    emit(AssignmentDetailLoading());
    try {
      final assignment = await assignmentRepository.getAssignment(
        event.assignmentId,
      );
      if (assignment == null) {
        emit(const AssignmentError(message: 'Assignment not found'));
        return;
      }

      final submission = await assignmentRepository.getUserSubmission(
        event.assignmentId,
        event.userId,
      );

      // Use submission code if exists, otherwise use starter code
      final initialCode = submission?.code ?? assignment.starterCode ?? '';

      emit(
        AssignmentDetailLoaded(
          assignment: assignment,
          submission: submission,
          currentCode: initialCode,
          hasChanges: false,
        ),
      );
    } catch (e) {
      emit(AssignmentError(message: 'Failed to load assignment: $e'));
    }
  }

  void _onUpdateCode(UpdateCode event, Emitter<AssignmentState> emit) {
    final currentState = state;
    if (currentState is AssignmentDetailLoaded) {
      final originalCode =
          currentState.submission?.code ??
          currentState.assignment.starterCode ??
          '';
      emit(
        currentState.copyWith(
          currentCode: event.code,
          hasChanges: event.code != originalCode,
        ),
      );
    }
  }

  Future<void> _onSaveDraft(
    SaveDraft event,
    Emitter<AssignmentState> emit,
  ) async {
    final currentState = state;
    if (currentState is AssignmentDetailLoaded) {
      emit(currentState.copyWith(isSaving: true));
      try {
        final submission = await assignmentRepository.saveDraft(
          assignmentId: event.assignmentId,
          courseId: event.courseId,
          userId: event.userId,
          userDisplayName: event.userDisplayName,
          code: event.code,
        );
        emit(
          currentState.copyWith(
            submission: submission,
            isSaving: false,
            hasChanges: false,
          ),
        );
        emit(DraftSaved(submission: submission));
        // Re-emit the loaded state
        emit(
          currentState.copyWith(
            submission: submission,
            isSaving: false,
            hasChanges: false,
          ),
        );
      } catch (e) {
        emit(currentState.copyWith(isSaving: false));
        emit(AssignmentError(message: 'Failed to save draft: $e'));
      }
    }
  }

  Future<void> _onSubmitAssignment(
    SubmitAssignment event,
    Emitter<AssignmentState> emit,
  ) async {
    final currentState = state;
    if (currentState is AssignmentDetailLoaded) {
      emit(currentState.copyWith(isSubmitting: true));
      try {
        final submission = await assignmentRepository.submitAssignment(
          assignmentId: event.assignmentId,
          courseId: event.courseId,
          userId: event.userId,
          userDisplayName: event.userDisplayName,
          code: event.code,
        );
        emit(AssignmentSubmitted(submission: submission));
        // Re-emit the loaded state with submitted submission
        emit(
          currentState.copyWith(
            submission: submission,
            isSubmitting: false,
            hasChanges: false,
          ),
        );
      } catch (e) {
        emit(currentState.copyWith(isSubmitting: false));
        emit(AssignmentError(message: 'Failed to submit assignment: $e'));
      }
    }
  }

  Future<void> _onGradeSubmission(
    GradeSubmission event,
    Emitter<AssignmentState> emit,
  ) async {
    try {
      final submission = await assignmentRepository.gradeSubmission(
        submissionId: event.submissionId,
        assignmentId: event.assignmentId,
        score: event.score,
        feedback: event.feedback,
        gradedBy: event.gradedBy,
      );
      emit(SubmissionGraded(submission: submission));
    } catch (e) {
      emit(AssignmentError(message: 'Failed to grade submission: $e'));
    }
  }

  Future<void> _onLoadSubmissions(
    LoadSubmissions event,
    Emitter<AssignmentState> emit,
  ) async {
    emit(AssignmentsLoading());
    try {
      final assignment = await assignmentRepository.getAssignment(
        event.assignmentId,
      );
      if (assignment == null) {
        emit(const AssignmentError(message: 'Assignment not found'));
        return;
      }

      final submissions = await assignmentRepository.getAssignmentSubmissions(
        event.assignmentId,
      );
      emit(SubmissionsLoaded(assignment: assignment, submissions: submissions));
    } catch (e) {
      emit(AssignmentError(message: 'Failed to load submissions: $e'));
    }
  }
}
