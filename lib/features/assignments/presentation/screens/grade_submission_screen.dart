import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/glow_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/models.dart';
import '../../data/repositories/assignment_repository.dart';
import '../bloc/assignment_bloc.dart';
import '../bloc/assignment_event.dart';
import '../bloc/assignment_state.dart';
import '../widgets/assignment_attachment_tile.dart';

String _gradeNumber(num value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// Screen for instructors to view and grade activity submissions
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
  final Map<String, TextEditingController> _criterionScoreControllers = {};
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
    _disposeCriterionScoreControllers();
    _feedbackController.dispose();
    _assignmentBloc.close();
    super.dispose();
  }

  void _disposeCriterionScoreControllers() {
    for (final controller in _criterionScoreControllers.values) {
      controller.dispose();
    }
    _criterionScoreControllers.clear();
  }

  void _selectSubmission(
    SubmissionModel submission,
    AssignmentModel assignment,
  ) {
    _disposeCriterionScoreControllers();
    final previousScores = {
      for (final item in submission.criterionScores)
        item.criterionId: item.score,
    };
    for (final criterion in assignment.gradingCriteria) {
      final previousScore = previousScores[criterion.id];
      _criterionScoreControllers[criterion.id] = TextEditingController(
        text: previousScore == null ? '' : _gradeNumber(previousScore),
      );
    }
    setState(() {
      _selectedSubmission = submission;
      _scoreController.text = submission.score == null
          ? ''
          : _gradeNumber(submission.score!);
      _feedbackController.text = submission.feedback ?? '';
    });
  }

  List<CriterionScore> _criterionScores(AssignmentModel assignment) {
    return assignment.gradingCriteria
        .map(
          (criterion) => CriterionScore(
            criterionId: criterion.id,
            criterionName: criterion.name,
            maxPoints: criterion.equivalentPoints(assignment.maxPoints),
            score:
                double.tryParse(
                  _criterionScoreControllers[criterion.id]?.text.trim() ?? '',
                ) ??
                0,
          ),
        )
        .toList(growable: false);
  }

  double _currentTotal(AssignmentModel assignment) =>
      assignment.gradingCriteria.isEmpty
      ? double.tryParse(_scoreController.text.trim()) ?? 0
      : _criterionScores(assignment).totalScore;

  void _gradeSubmission(AssignmentModel assignment) {
    if (_selectedSubmission?.isCompleted != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This work has not been turned in yet.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    _assignmentBloc.add(
      GradeSubmission(
        submissionId: _selectedSubmission!.id,
        assignmentId: widget.assignmentId,
        score: double.parse(_currentTotal(assignment).toStringAsFixed(2)),
        criterionScores: assignment.gradingCriteria.isEmpty
            ? const []
            : _criterionScores(assignment),
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
            _disposeCriterionScoreControllers();
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
            Icon(Icons.inbox_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('No submissions yet', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            Text(
              'Students haven\'t submitted anything for this activity.',
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
      SubmissionStatus.done => AppColors.success,
      SubmissionStatus.grading => AppColors.info,
      SubmissionStatus.returned => AppColors.secondary,
      _ => AppColors.textMuted,
    };

    return ListTile(
      selected: isSelected,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
      onTap: () => _selectSubmission(submission, assignment),
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Text(
          submission.userDisplayName.isNotEmpty
              ? submission.userDisplayName[0].toUpperCase()
              : '?',
          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        submission.userDisplayName,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        (submission.isLate ? 'Late' : submission.status.displayName) +
            (submission.isGraded
                ? ' - ${_gradeNumber(submission.score ?? 0)}/${assignment.maxPoints}'
                : ''),
        style: AppTextStyles.caption.copyWith(color: statusColor),
      ),
      trailing: submission.isGraded
          ? Icon(Icons.check_circle, color: AppColors.success, size: 20)
          : Icon(Icons.pending_outlined, color: AppColors.textMuted, size: 20),
    );
  }

  Widget _buildEmptySelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 48, color: AppColors.textMuted),
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
                      Text(submission.userDisplayName, style: AppTextStyles.h4),
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

          if (submission.attachments.isNotEmpty) ...[
            Text('Attached Work', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            ...submission.attachments.map(
              (attachment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AssignmentAttachmentTile(
                  attachment: attachment,
                  onOpen: () => _openAttachment(attachment),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (submission.code.trim().isNotEmpty) ...[
            Text('Submitted Code', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  submission.code,
                  style: GoogleFonts.firaCode(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (submission.code.trim().isEmpty &&
              submission.attachments.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                submission.status == SubmissionStatus.done
                    ? 'The student marked this activity as done.'
                    : 'No attached work was submitted.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Grading form
          Text('Grade Activity', style: AppTextStyles.h4),
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
                  if (assignment.gradingCriteria.isNotEmpty) ...[
                    Text('Score each criterion', style: AppTextStyles.label),
                    const SizedBox(height: 4),
                    Text(
                      'The final Activity score is calculated automatically.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...assignment.gradingCriteria.map(
                      (criterion) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TextFormField(
                          key: ValueKey('criterion-score-${criterion.id}'),
                          controller: _criterionScoreControllers[criterion.id],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d{0,5}(?:\.\d{0,2})?$'),
                            ),
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: criterion.name,
                            helperText:
                                '${_gradeNumber(criterion.percentage)}% of the Activity grade',
                            prefixIcon: const Icon(Icons.checklist_outlined),
                            suffixText:
                                '/ ${_gradeNumber(criterion.equivalentPoints(assignment.maxPoints))}',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter a score for ${criterion.name}';
                            }
                            final score = double.tryParse(value.trim());
                            final maximum = criterion.equivalentPoints(
                              assignment.maxPoints,
                            );
                            if (score == null) {
                              return 'Enter a valid number';
                            }
                            if (score < 0 || score > maximum + 0.0001) {
                              return 'Score must be from 0 to ${_gradeNumber(maximum)}';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate_outlined),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Final Activity score',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '${_gradeNumber(_currentTotal(assignment))} / ${assignment.maxPoints}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    TextFormField(
                      controller: _scoreController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Score',
                        hintText: 'Out of ${assignment.maxPoints}',
                        prefixIcon: const Icon(Icons.grade),
                        suffixText: '/ ${assignment.maxPoints}',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a score';
                        }
                        final score = double.tryParse(value);
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
                      onPressed: submission.isCompleted
                          ? () => _gradeSubmission(assignment)
                          : null,
                      icon: Icon(Icons.check),
                      label: Text(
                        !submission.isCompleted
                            ? 'Not turned in'
                            : submission.isGraded
                            ? 'Update Grade'
                            : 'Submit Grade',
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
                    'Score: ${_gradeNumber(submission.score ?? 0)}/${assignment.maxPoints}',
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (submission.criterionScores.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...submission.criterionScores.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.criterionName)),
                            Text(
                              '${_gradeNumber(item.score)}/${_gradeNumber(item.maxPoints)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openAttachment(AssignmentAttachment attachment) async {
    try {
      final value = await context.read<AssignmentRepository>().getAttachmentUrl(
        attachment,
      );
      final opened = await launchUrl(
        Uri.parse(value),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('No app can open this attachment.');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This attachment could not be opened.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
