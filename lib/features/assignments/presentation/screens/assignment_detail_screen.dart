import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/lesson_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/models.dart';
import '../../data/repositories/assignment_repository.dart';
import '../bloc/assignment_bloc.dart';
import '../bloc/assignment_event.dart';
import '../bloc/assignment_state.dart';
import '../widgets/code_editor.dart';

/// Screen for viewing assignment details and submitting code
class AssignmentDetailScreen extends StatefulWidget {
  final String courseId;
  final String assignmentId;

  const AssignmentDetailScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen>
    with SingleTickerProviderStateMixin {
  late AssignmentBloc _assignmentBloc;
  late TabController _tabController;
  String _currentCode = '';

  bool get _isInstructor {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.user.role == 'instructor';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _assignmentBloc = AssignmentBloc(
      assignmentRepository: context.read<AssignmentRepository>(),
    );
    _loadAssignment();
  }

  void _loadAssignment() {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.user.id
        : 'demo_user';
    _assignmentBloc.add(
      LoadAssignmentDetail(assignmentId: widget.assignmentId, userId: userId),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _assignmentBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _assignmentBloc,
      child: BlocConsumer<AssignmentBloc, AssignmentState>(
        listener: (context, state) {
          if (state is AssignmentDetailLoaded) {
            _currentCode = state.currentCode;
          }
          if (state is DraftSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Draft saved'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
          }
          if (state is AssignmentSubmitted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.submission.isLate
                      ? 'Assignment submitted (late)'
                      : 'Assignment submitted successfully!',
                ),
                backgroundColor: state.submission.isLate
                    ? AppColors.warning
                    : AppColors.success,
              ),
            );
          }
          if (state is AssignmentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: _buildAppBar(state),
            body: _buildBody(state),
            bottomNavigationBar: _buildBottomBar(state),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AssignmentState state) {
    String title = 'Assignment';
    if (state is AssignmentDetailLoaded) {
      title = state.assignment.title;
    }

    return AppBar(
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [
          Tab(text: 'Instructions'),
          Tab(text: 'Code Editor'),
        ],
      ),
      actions: [
        if (!_isInstructor &&
            state is AssignmentDetailLoaded &&
            state.hasChanges)
          TextButton.icon(
            onPressed: state.isSaving ? null : () => _saveDraft(state),
            icon: state.isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(Icons.save_outlined, size: 18),
            label: const Text('Save'),
          ),
      ],
    );
  }

  Widget _buildBody(AssignmentState state) {
    if (state is AssignmentDetailLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state is AssignmentError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              state.message,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadAssignment,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state is AssignmentDetailLoaded) {
      return TabBarView(
        controller: _tabController,
        children: [_buildInstructionsTab(state), _buildCodeEditorTab(state)],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildInstructionsTab(AssignmentDetailLoaded state) {
    final assignment = state.assignment;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assignment info card
          _buildInfoCard(assignment, state.submission),
          const SizedBox(height: 16),

          // Instructions
          if (assignment.instructions != null) ...[
            Text(
              'Instructions',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: MarkdownContent(
                content: assignment.instructions!,
                selectable: true,
              ),
            ),
          ],

          // Starter code preview
          if (assignment.starterCode != null &&
              assignment.starterCode!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Starter Code',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: CodeViewer(
                code: assignment.starterCode!,
                language: assignment.language,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    AssignmentModel assignment,
    SubmissionModel? submission,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assignment.description,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                icon: Icons.code,
                label: assignment.language.displayName,
                color: AppColors.primary,
              ),
              _buildInfoChip(
                icon: Icons.star_outline,
                label: '${assignment.maxPoints} points',
              ),
              if (assignment.dueDate != null)
                _buildInfoChip(
                  icon: Icons.schedule,
                  label: _formatDueDate(assignment.dueDate!),
                  color: assignment.isPastDue
                      ? AppColors.error
                      : AppColors.success,
                ),
              if (submission != null)
                _buildInfoChip(
                  icon: _getStatusIcon(submission.status),
                  label: submission.status.displayName,
                  color: _getStatusColor(submission.status),
                ),
            ],
          ),
          if (submission?.isGraded == true) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.grade, color: AppColors.secondary, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Score: ${submission!.score}/${assignment.maxPoints}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${submission.getPercentage(assignment.maxPoints)?.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            if (submission.feedback != null) ...[
              const SizedBox(height: 12),
              Text(
                'Feedback',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                submission.feedback!,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final chipColor = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: chipColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEditorTab(AssignmentDetailLoaded state) {
    final isSubmitted = state.submission?.isSubmitted == true;
    final isInstructor = _isInstructor;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isInstructor)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Instructor preview mode (read-only)',
                    style: TextStyle(fontSize: 13, color: AppColors.info),
                  ),
                ],
              ),
            )
          else if (isSubmitted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'This assignment has been submitted. You can still edit and resubmit.',
                    style: TextStyle(fontSize: 13, color: AppColors.info),
                  ),
                ],
              ),
            ),
          Expanded(
            child: CodeEditor(
              initialCode: state.currentCode,
              language: state.assignment.language,
              readOnly: isInstructor,
              onChanged: (code) {
                _currentCode = code;
                _assignmentBloc.add(UpdateCode(code: code));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar(AssignmentState state) {
    if (state is! AssignmentDetailLoaded) return null;
    if (_isInstructor) return null;

    final isSubmitting = state.isSubmitting;
    final isSubmitted = state.submission?.isSubmitted == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.hasChanges && !isSubmitting
                    ? () => _saveDraft(state)
                    : null,
                icon: Icon(Icons.save_outlined),
                label: const Text('Save Draft'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: isSubmitting ? null : () => _submitAssignment(state),
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isSubmitted ? Icons.refresh : Icons.send),
                label: Text(isSubmitted ? 'Resubmit' : 'Submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveDraft(AssignmentDetailLoaded state) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.user.id
        : 'demo_user';
    final displayName = authState is AuthAuthenticated
        ? (authState.user.displayName ?? 'Student')
        : 'Demo Student';
    _assignmentBloc.add(
      SaveDraft(
        assignmentId: widget.assignmentId,
        courseId: widget.courseId,
        userId: userId,
        userDisplayName: displayName,
        code: _currentCode,
      ),
    );
  }

  void _submitAssignment(AssignmentDetailLoaded state) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Assignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to submit this assignment?'),
            if (state.assignment.isPastDue) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This assignment is past due. A ${state.assignment.latePenaltyPercent}% penalty may apply.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              final authState = context.read<AuthBloc>().state;
              final userId = authState is AuthAuthenticated
                  ? authState.user.id
                  : 'demo_user';
              final displayName = authState is AuthAuthenticated
                  ? (authState.user.displayName ?? 'Student')
                  : 'Demo Student';
              _assignmentBloc.add(
                SubmitAssignment(
                  assignmentId: widget.assignmentId,
                  courseId: widget.courseId,
                  userId: userId,
                  userDisplayName: displayName,
                  code: _currentCode,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
            child: const Text('Submit', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final diff = dueDate.difference(now);

    if (diff.isNegative) {
      return 'Past due';
    } else if (diff.inDays == 0) {
      return 'Due today';
    } else if (diff.inDays == 1) {
      return 'Due tomorrow';
    } else {
      return 'Due in ${diff.inDays} days';
    }
  }

  IconData _getStatusIcon(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.draft:
        return Icons.edit_note;
      case SubmissionStatus.submitted:
        return Icons.check_circle_outline;
      case SubmissionStatus.grading:
        return Icons.hourglass_empty;
      case SubmissionStatus.graded:
        return Icons.grade;
      case SubmissionStatus.returned:
        return Icons.assignment_return;
    }
  }

  Color _getStatusColor(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.draft:
        return AppColors.textSecondary;
      case SubmissionStatus.submitted:
        return AppColors.info;
      case SubmissionStatus.grading:
        return AppColors.warning;
      case SubmissionStatus.graded:
        return AppColors.success;
      case SubmissionStatus.returned:
        return AppColors.secondary;
    }
  }
}
