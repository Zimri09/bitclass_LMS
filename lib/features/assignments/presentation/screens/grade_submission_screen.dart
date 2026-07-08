import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/glow_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/models.dart';
import '../../data/repositories/assignment_repository.dart';
import '../bloc/assignment_bloc.dart';
import '../bloc/assignment_event.dart';
import '../bloc/assignment_state.dart';

/// Screen for instructors to view and grade assignment submissions
class GradeSubmissionScreen extends StatefulWidget {
  final String courseId;
  final String assignmentId;

  const GradeSubmissionScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
  });

  @override
  State<GradeSubmissionScreen> createState() => _GradeSubmissionScreenState();
}

class _GradeSubmissionScreenState extends State<GradeSubmissionScreen> {
  late AssignmentBloc _assignmentBloc;
  SubmissionModel? _selectedSubmission;
  final _scoreController = TextEditingController();
  final _feedbackController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _assignmentBloc = AssignmentBloc(
      assignmentRepository: context.read<AssignmentRepository>(),
    );
    _assignmentBloc.add(LoadSubmissions(assignmentId: widget.assignmentId));
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _feedbackController.dispose();
    _assignmentBloc.close();
    super.dispose();
  }

  void _selectSubmission(SubmissionModel submission) {
    setState(() {
      _selectedSubmission = submission;
      _scoreController.text = submission.score?.toString() ?? '';
      _feedbackController.text = submission.feedback ?? '';
    });
  }

  void _gradeSubmission() {
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    _assignmentBloc.add(
      GradeSubmission(
        submissionId: _selectedSubmission!.id,
        assignmentId: widget.assignmentId,
        score: int.parse(_scoreController.text.trim()),
        feedback: _feedbackController.text.trim(),
        gradedBy: authState.user.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grade Submissions', style: AppTextStyles.h3),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<AssignmentBloc, AssignmentState>(
        bloc: _assignmentBloc,
        listener: (context, state) {
          if (state is SubmissionGraded) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Submission graded successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
            // Reload submissions to reflect the update
            setState(() => _selectedSubmission = null);
            _assignmentBloc.add(
              LoadSubmissions(assignmentId: widget.assignmentId),
            );
          } else if (state is AssignmentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AssignmentsLoading || state is AssignmentInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AssignmentError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(state.message, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _assignmentBloc.add(
                      LoadSubmissions(assignmentId: widget.assignmentId),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is SubmissionsLoaded) {
            return _buildContent(state);
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildContent(SubmissionsLoaded state) {
    final assignment = state.assignment;
    final submissions = state.submissions;

    if (submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text('No submissions yet', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            Text(
              'Students haven\'t submitted anything for this assignment.',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use side-by-side layout on wide screens, stacked on narrow
        final isWide = constraints.maxWidth > 800;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Submissions list (left panel)
              SizedBox(
                width: 320,
                child: _buildSubmissionsList(submissions, assignment),
              ),
              VerticalDivider(width: 1),
              // Detail / grading panel (right)
              Expanded(
                child: _selectedSubmission != null
                    ? _buildGradingPanel(assignment)
                    : _buildEmptySelection(),
              ),
            ],
          );
        }

        // Narrow layout: if a submission is selected, show grading; else list
        if (_selectedSubmission != null) {
          return Column(
            children: [
              // Back to list button
              Padding(
                padding: const EdgeInsets.all(8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _selectedSubmission = null),
                    icon: Icon(Icons.arrow_back),
                    label: const Text('Back to list'),
                  ),
                ),
              ),
              Expanded(child: _buildGradingPanel(assignment)),
            ],
          );
        }

        return _buildSubmissionsList(submissions, assignment);
      },
    );
  }

  Widget _buildSubmissionsList(
    List<SubmissionModel> submissions,
    AssignmentModel assignment,
  ) {
    // Sort: ungraded first, then by submission date
    final sorted = List<SubmissionModel>.from(submissions)
      ..sort((a, b) {
        if (a.isGraded != b.isGraded) return a.isGraded ? 1 : -1;
        final aDate = a.submittedAt ?? a.createdAt;
        final bDate = b.submittedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

    final gradedCount = submissions.where((s) => s.isGraded).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with stats
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(assignment.title, style: AppTextStyles.h4),
              const SizedBox(height: 4),
              Text(
                '$gradedCount / ${submissions.length} graded',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: submissions.isNotEmpty
                      ? gradedCount / submissions.length
                      : 0,
                  valueColor: AlwaysStoppedAnimation(AppColors.success),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1),
        // Submissions
        Expanded(
          child: ListView.separated(
            itemCount: sorted.length,
            separatorBuilder: (_, _) => Divider(height: 1),
            itemBuilder: (context, index) {
              final submission = sorted[index];
              final isSelected = _selectedSubmission?.id == submission.id;
              return _buildSubmissionTile(submission, isSelected, assignment);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionTile(
    SubmissionModel submission,
    bool isSelected,
    AssignmentModel assignment,
  ) {
    final statusColor = switch (submission.status) {
      SubmissionStatus.graded => AppColors.success,
      SubmissionStatus.submitted => AppColors.warning,
      SubmissionStatus.grading => AppColors.info,
      SubmissionStatus.returned => AppColors.secondary,
      _ => AppColors.textMuted,
    };

    return ListTile(
      selected: isSelected,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
      onTap: () => _selectSubmission(submission),
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Text(
          submission.userDisplayName.isNotEmpty
              ? submission.userDisplayName[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        submission.userDisplayName,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        submission.status.displayName +
            (submission.isLate ? ' (Late)' : '') +
            (submission.isGraded
                ? ' — ${submission.score}/${assignment.maxPoints}'
                : ''),
        style: AppTextStyles.caption.copyWith(color: statusColor),
      ),
      trailing: submission.isGraded
          ? Icon(Icons.check_circle, color: AppColors.success, size: 20)
          : Icon(
              Icons.pending_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
    );
  }

  Widget _buildEmptySelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'Select a submission to grade',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradingPanel(AssignmentModel assignment) {
    final submission = _selectedSubmission!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student info header
          GlowCard(
            glowColor: AppColors.primary,
            glowIntensity: 0.05,
            isHoverable: false,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  radius: 24,
                  child: Text(
                    submission.userDisplayName.isNotEmpty
                        ? submission.userDisplayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submission.userDisplayName,
                        style: AppTextStyles.h4,
                      ),
                      Text(
                        'Status: ${submission.status.displayName}'
                        '${submission.isLate ? ' (Late)' : ''}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (submission.submittedAt != null)
                        Text(
                          'Submitted: ${_formatDate(submission.submittedAt!)}',
                          style: AppTextStyles.caption,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Student's code
          Text('Submitted Code', style: AppTextStyles.h4),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.border,
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                submission.code.isNotEmpty
                    ? submission.code
                    : '// No code submitted',
                style: GoogleFonts.firaCode(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Grading form
          Text('Grade Submission', style: AppTextStyles.h4),
          const SizedBox(height: 12),

          GlowCard(
            glowColor: AppColors.secondary,
            glowIntensity: 0.05,
            isHoverable: false,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score
                  TextFormField(
                    controller: _scoreController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Score',
                      hintText: 'Out of ${assignment.maxPoints}',
                      prefixIcon: Icon(Icons.grade),
                      suffixText: '/ ${assignment.maxPoints}',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a score';
                      }
                      final score = int.tryParse(value);
                      if (score == null) {
                        return 'Please enter a valid number';
                      }
                      if (score < 0 || score > assignment.maxPoints) {
                        return 'Score must be between 0 and ${assignment.maxPoints}';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Feedback
                  TextFormField(
                    controller: _feedbackController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Feedback',
                      hintText:
                          'Provide feedback to help the student improve...',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 60),
                        child: Icon(Icons.comment),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please provide feedback';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Submit grade button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _gradeSubmission,
                      icon: Icon(Icons.check),
                      label: Text(
                        submission.isGraded ? 'Update Grade' : 'Submit Grade',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Previous grade info
          if (submission.isGraded) ...[
            const SizedBox(height: 16),
            GlowCard(
              glowColor: AppColors.success,
              glowIntensity: 0.05,
              isHoverable: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('Previous Grade', style: AppTextStyles.label),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Score: ${submission.score}/${assignment.maxPoints}',
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (submission.feedback != null &&
                      submission.feedback!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Feedback: ${submission.feedback}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (submission.gradedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Graded: ${_formatDate(submission.gradedAt!)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
