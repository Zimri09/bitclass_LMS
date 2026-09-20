import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_time_formatters.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../courses/data/repositories/course_repository.dart';
import '../../data/models/models.dart';
import '../../data/repositories/assignment_repository.dart';
import '../bloc/assignment_bloc.dart';
import '../bloc/assignment_event.dart';
import '../bloc/assignment_state.dart';

class AssignmentListScreen extends StatefulWidget {
  final String courseId;
  final bool embedded;

  const AssignmentListScreen({
    super.key,
    required this.courseId,
    this.embedded = false,
  });

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  late final AssignmentBloc _assignmentBloc;
  bool _canManageAssignments = false;
  Map<String, SubmissionModel> _studentSubmissions = {};

  bool get _hasInstructorRole {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return false;
    return authState.user.isStaff;
  }

  @override
  void initState() {
    super.initState();
    _assignmentBloc = AssignmentBloc(
      assignmentRepository: context.read<AssignmentRepository>(),
    );
    _loadManagementPermission();
    _loadStudentSubmissions();
    _loadAssignments();
  }

  Future<void> _loadManagementPermission() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    if (authState.user.role == 'admin') {
      if (mounted) {
        setState(() => _canManageAssignments = true);
        _loadAssignments();
      }
      return;
    }
    if (authState.user.role != 'instructor') return;

    try {
      final course = await context.read<CourseRepository>().getCourse(
        widget.courseId,
      );
      if (!mounted) return;
      setState(() {
        _canManageAssignments = course?.instructorId == authState.user.id;
      });
      if (_canManageAssignments) _loadAssignments();
    } catch (_) {
      // Hide write controls when ownership cannot be confirmed.
    }
  }

  Future<void> _loadStudentSubmissions() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || authState.user.role != 'student') {
      return;
    }
    final submissions = await context
        .read<AssignmentRepository>()
        .getUserSubmissionsForCourse(widget.courseId, authState.user.id);
    if (!mounted) return;
    setState(() {
      _studentSubmissions = {
        for (final submission in submissions)
          submission.assignmentId: submission,
      };
    });
  }

  void _loadAssignments() {
    _assignmentBloc.add(
      LoadAssignments(
        courseId: widget.courseId,
        includeDrafts: _canManageAssignments,
      ),
    );
  }

  Future<void> _refresh() async {
    _loadAssignments();
    await _loadStudentSubmissions();
  }

  @override
  void dispose() {
    _assignmentBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = BlocBuilder<AssignmentBloc, AssignmentState>(
      builder: (context, state) {
        if (state is AssignmentsLoading || state is AssignmentInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is AssignmentError) {
          return _buildError(state.message);
        }
        if (state is AssignmentsLoaded) {
          if (state.assignments.isEmpty) return _buildEmptyState();
          return _buildAssignmentList(state.assignments);
        }
        return const SizedBox.shrink();
      },
    );

    return BlocProvider.value(
      value: _assignmentBloc,
      child: widget.embedded
          ? body
          : Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                title: const Text('Activities'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  if (_canManageAssignments)
                    IconButton(
                      tooltip: 'Create activity',
                      onPressed: _createAssignment,
                      icon: const Icon(Icons.add),
                    ),
                ],
              ),
              body: body,
            ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _loadAssignments,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text('No activities yet', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              _canManageAssignments
                  ? 'Create an activity for your class.'
                  : 'Published activities will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (_canManageAssignments) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _createAssignment,
                icon: const Icon(Icons.add),
                label: const Text('Create activity'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentList(List<AssignmentModel> assignments) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!kIsWeb) {
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: assignments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _buildAssignmentCard(context, assignments[index]),
            );
          }

          const gap = 14.0;
          const maxCardWidth = 370.0;
          const minCardWidth = 280.0;

          final availableWidth = constraints.maxWidth - 32; // 16px padding on each side
          final count = (availableWidth / (maxCardWidth + gap)).floor();
          final columns = count < 1 ? 1 : count;

          final double tileWidth;
          if (columns == 1) {
            tileWidth = availableWidth > maxCardWidth
                ? maxCardWidth
                : availableWidth;
          } else {
            final computed =
                (availableWidth - gap * (columns - 1)) / columns;
            tileWidth = computed.clamp(minCardWidth, maxCardWidth);
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: Wrap(
                spacing: gap,
                runSpacing: gap,
                children: assignments
                    .map(
                      (assignment) => SizedBox(
                        width: tileWidth,
                        child: _buildAssignmentCard(
                          context,
                          assignment,
                          columns: columns,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssignmentCard(
    BuildContext context,
    AssignmentModel assignment, {
    int? columns,
  }) {
    final submission = _studentSubmissions[assignment.id];
    final card = _AssignmentCard(
      assignment: assignment,
      submission: submission,
      showInstructorControls: _canManageAssignments,
      showStudentStatus: !_hasInstructorRole,
      onTap: () => context.push(
        AppRoutes.assignmentPath(widget.courseId, assignment.id),
      ),
      onEdit: () => _editAssignment(assignment.id),
      onReview: () => context.push(
        AppRoutes.gradeAssignmentPath(widget.courseId, assignment.id),
      ),
      onDelete: () => _confirmDeleteAssignment(assignment),
    );

    if (columns != null) return card;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: card,
      ),
    );
  }

  Future<void> _createAssignment() async {
    await context.push(AppRoutes.createAssignmentPath(widget.courseId));
    if (mounted) _loadAssignments();
  }

  Future<void> _editAssignment(String assignmentId) async {
    await context.push(
      AppRoutes.editAssignmentPath(widget.courseId, assignmentId),
    );
    if (mounted) _loadAssignments();
  }

  Future<void> _confirmDeleteAssignment(AssignmentModel assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AppColors.error),
        title: const Text('Delete activity?'),
        content: Text(
          '"${assignment.title}" and all student submissions will be '
          'permanently removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<AssignmentRepository>().deleteAssignment(
        assignment.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Activity deleted.')));
      _loadAssignments();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete this activity.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _AssignmentCard extends StatelessWidget {
  final AssignmentModel assignment;
  final SubmissionModel? submission;
  final bool showInstructorControls;
  final bool showStudentStatus;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onReview;
  final VoidCallback onDelete;

  const _AssignmentCard({
    required this.assignment,
    required this.submission,
    required this.showInstructorControls,
    required this.showStudentStatus,
    required this.onTap,
    required this.onEdit,
    required this.onReview,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status =
        submission?.classroomStatus(assignment) ??
        (assignment.isPastDue
            ? ClassroomSubmissionStatus.missing
            : ClassroomSubmissionStatus.assigned);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const _CardBadge(
                    label: 'ACTIVITY',
                    color: AppColors.primary,
                    isFirst: true,
                  ),
                  if (showInstructorControls && !assignment.isPublished)
                    const _CardBadge(label: 'Draft', color: AppColors.warning),
                  if (showStudentStatus)
                    _CardBadge(
                      label: status.displayName,
                      color: _statusColor(status),
                    ),
                  const Spacer(),
                  if (showInstructorControls)
                    SizedBox.square(
                      dimension: 28,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        tooltip: 'Activity actions',
                        onSelected: (action) {
                          if (action == 'edit') onEdit();
                          if (action == 'review') onReview();
                          if (action == 'delete') onDelete();
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit activity'),
                          ),
                          PopupMenuItem(
                            value: 'review',
                            child: Text('Review submissions'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete activity',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                assignment.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CardMeta(
                    icon: Icons.schedule_outlined,
                    label: formatPostedDateTime(assignment.createdAt),
                  ),
                  _CardMeta(
                    icon: Icons.event_outlined,
                    label: assignment.dueDate == null
                        ? 'No due date'
                        : 'Due ${DateFormat('MMM d, h:mm a').format(assignment.dueDate!.toLocal())}',
                  ),
                  _CardMeta(
                    icon: Icons.star_outline,
                    label: '${assignment.maxPoints} points',
                  ),
                  if (assignment.attachments.isNotEmpty)
                    _CardMeta(
                      icon: Icons.attach_file,
                      label:
                          '${assignment.attachments.length} material${assignment.attachments.length == 1 ? '' : 's'}',
                    ),
                  if (assignment.isCodeActivity)
                    _CardMeta(
                      icon: Icons.code,
                      label: assignment.language.displayName,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: showInstructorControls ? onReview : onTap,
                  icon: Icon(
                    showInstructorControls
                        ? Icons.rate_review_outlined
                        : Icons.arrow_forward,
                    size: 16,
                  ),
                  label: Text(showInstructorControls ? 'Review' : 'Open'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(ClassroomSubmissionStatus status) {
    return switch (status) {
      ClassroomSubmissionStatus.assigned => AppColors.info,
      ClassroomSubmissionStatus.submitted => AppColors.success,
      ClassroomSubmissionStatus.done => AppColors.success,
      ClassroomSubmissionStatus.missing => AppColors.error,
      ClassroomSubmissionStatus.late => AppColors.warning,
    };
  }
}

class _CardMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CardMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isFirst;

  const _CardBadge({
    required this.label,
    required this.color,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: isFirst ? 0 : 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
