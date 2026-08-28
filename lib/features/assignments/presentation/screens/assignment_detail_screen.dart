import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_time_formatters.dart';
import '../../../../core/utils/url_utils.dart';
import '../../../../shared/widgets/lesson_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../courses/data/repositories/course_repository.dart';
import '../../data/models/models.dart';
import '../../data/repositories/assignment_repository.dart';
import '../bloc/assignment_bloc.dart';
import '../bloc/assignment_event.dart';
import '../bloc/assignment_state.dart';
import '../widgets/widgets.dart';

String _displayNumber(num value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

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

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  late final AssignmentBloc _assignmentBloc;
  String _currentCode = '';
  bool _canManage = false;
  bool _isWorkBusy = false;

  AuthAuthenticated? get _authenticatedUser {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated ? authState : null;
  }

  bool get _isInstructorView {
    return _authenticatedUser?.user.isStaff ?? false;
  }

  String get _userId => _authenticatedUser?.user.id ?? 'demo-user-1';
  String get _userDisplayName =>
      _authenticatedUser?.user.displayNameOrEmail ?? 'Demo Student';

  @override
  void initState() {
    super.initState();
    _assignmentBloc = AssignmentBloc(
      assignmentRepository: context.read<AssignmentRepository>(),
    );
    _loadManagementPermission();
    _loadAssignment();
  }

  Future<void> _loadManagementPermission() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    if (authState.user.role == 'admin') {
      if (mounted) setState(() => _canManage = true);
      return;
    }
    if (authState.user.role != 'instructor') return;

    try {
      final course = await context.read<CourseRepository>().getCourse(
        widget.courseId,
      );
      if (mounted) {
        setState(() => _canManage = course?.instructorId == authState.user.id);
      }
    } catch (_) {
      // RLS remains the final authority when ownership cannot be loaded.
    }
  }

  void _loadAssignment() {
    _assignmentBloc.add(
      LoadAssignmentDetail(assignmentId: widget.assignmentId, userId: _userId),
    );
  }

  @override
  void dispose() {
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
          } else if (state is DraftSaved) {
            _showMessage('Draft saved.', AppColors.success);
          } else if (state is AssignmentSubmitted) {
            _showMessage(
              state.submission.isLate
                  ? 'Work submitted late.'
                  : 'Work submitted.',
              state.submission.isLate ? AppColors.warning : AppColors.success,
            );
          } else if (state is AssignmentMarkedDone) {
            _showMessage(
              state.submission.isLate ? 'Marked done late.' : 'Marked as done.',
              state.submission.isLate ? AppColors.warning : AppColors.success,
            );
          } else if (state is AssignmentUnsubmitted) {
            _showMessage(
              'Activity returned to Assigned. You can continue working on it.',
              AppColors.info,
            );
          } else if (state is AssignmentError) {
            _showMessage(state.message, AppColors.error);
          }
        },
        builder: (context, state) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(state),
          body: _buildBody(state),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AssignmentState state) {
    final assignment = state is AssignmentDetailLoaded
        ? state.assignment
        : null;
    return AppBar(
      title: const Text('Activity'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      actions: [
        if (_canManage && assignment != null)
          PopupMenuButton<String>(
            tooltip: 'Activity actions',
            onSelected: (action) async {
              if (action == 'edit') {
                await context.push(
                  AppRoutes.editAssignmentPath(
                    widget.courseId,
                    widget.assignmentId,
                  ),
                );
                if (mounted) _loadAssignment();
              } else if (action == 'review') {
                await context.push(
                  AppRoutes.gradeAssignmentPath(
                    widget.courseId,
                    widget.assignmentId,
                  ),
                );
              } else if (action == 'delete') {
                await _deleteAssignment(assignment);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit activity')),
              PopupMenuItem(value: 'review', child: Text('Review submissions')),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete activity',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBody(AssignmentState state) {
    if (state is AssignmentDetailLoading || state is AssignmentInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is AssignmentError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 14),
              Text(state.message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _loadAssignment,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (state is! AssignmentDetailLoaded) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () async => _loadAssignment(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 880;
          final details = _buildDetails(state);
          final sidePanel = _isInstructorView
              ? (_canManage
                    ? _buildInstructorPanel(state.assignment)
                    : const _DetailCard(
                        child: Text(
                          'This activity is read-only for this instructor.',
                        ),
                      ))
              : _buildYourWork(state);

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.all(isWide ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 20),
                          SizedBox(width: 330, child: sidePanel),
                        ],
                      )
                    : Column(
                        children: [
                          details,
                          const SizedBox(height: 16),
                          sidePanel,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetails(AssignmentDetailLoaded state) {
    final assignment = state.assignment;
    final status = _classroomStatus(assignment, state.submission);

    return Column(
      children: [
        _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(assignment.title, style: AppTextStyles.h3),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _MetaLabel(
                              icon: Icons.schedule_outlined,
                              text: formatPostedDateTime(assignment.createdAt),
                            ),
                            _MetaLabel(
                              icon: Icons.star_outline,
                              text: '${assignment.maxPoints} points',
                            ),
                            _MetaLabel(
                              icon: Icons.event_outlined,
                              text: _dueLabel(assignment.dueDate),
                            ),
                            if (assignment.isCodeActivity)
                              _MetaLabel(
                                icon: Icons.code,
                                text: assignment.language.displayName,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!_isInstructorView) _StatusBadge(status: status),
                  if (_isInstructorView && !assignment.isPublished)
                    const _SimpleBadge(
                      label: 'Draft',
                      color: AppColors.warning,
                    ),
                ],
              ),
              const Divider(height: 34),
              Text('Instructions', style: AppTextStyles.h4),
              const SizedBox(height: 12),
              if (assignment.instructions?.trim().isNotEmpty == true)
                MarkdownContent(
                  content: assignment.instructions!,
                  selectable: true,
                )
              else
                Text(
                  'No instructions were provided.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              if (assignment.gradingCriteria.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text('Grading criteria', style: AppTextStyles.h4),
                const SizedBox(height: 6),
                Text(
                  'Each value is calculated from ${assignment.maxPoints} total points.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                ...assignment.gradingCriteria.map(
                  (criterion) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            criterion.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${_displayNumber(criterion.percentage)}%',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '${_displayNumber(criterion.equivalentPoints(assignment.maxPoints))} pts',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (assignment.attachments.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text('Materials', style: AppTextStyles.h4),
                const SizedBox(height: 10),
                ...assignment.attachments.map(
                  (attachment) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AssignmentAttachmentTile(
                      attachment: attachment,
                      onOpen: () => _openAttachment(attachment),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (assignment.isCodeActivity) ...[
          const SizedBox(height: 16),
          _buildCodeSection(state),
        ],
      ],
    );
  }

  Widget _buildCodeSection(AssignmentDetailLoaded state) {
    final submission = state.submission;
    final canEdit =
        !_isInstructorView &&
        (submission == null || submission.status == SubmissionStatus.draft) &&
        !(state.assignment.isPastDue && !state.assignment.allowLateSubmission);

    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Code editor', style: AppTextStyles.h4)),
              if (canEdit && state.hasChanges)
                TextButton.icon(
                  onPressed: state.isSaving ? null : () => _saveDraft(state),
                  icon: state.isSaving
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save draft'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!canEdit && !_isInstructorView)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                submission?.isCompleted == true
                    ? 'Unsubmit before the deadline to edit this work.'
                    : 'The deadline has passed and editing is closed.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          CodeEditor(
            key: ValueKey(
              '${submission?.id}-${submission?.updatedAt}-$canEdit',
            ),
            initialCode: _currentCode,
            language: state.assignment.language,
            readOnly: _isInstructorView || !canEdit,
            height: 430,
            onChanged: canEdit
                ? (code) {
                    _currentCode = code;
                    _assignmentBloc.add(UpdateCode(code: code));
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorPanel(AssignmentModel assignment) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Instructor actions', style: AppTextStyles.h4),
          const SizedBox(height: 8),
          Text(
            assignment.isPublished
                ? 'This activity is visible to students.'
                : 'This activity is currently a draft.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(
                AppRoutes.gradeAssignmentPath(
                  widget.courseId,
                  widget.assignmentId,
                ),
              ),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Review submissions'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await context.push(
                  AppRoutes.editAssignmentPath(
                    widget.courseId,
                    widget.assignmentId,
                  ),
                );
                if (mounted) _loadAssignment();
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit activity'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourWork(AssignmentDetailLoaded state) {
    final assignment = state.assignment;
    final submission = state.submission;
    final attachments =
        submission?.attachments ?? const <AssignmentAttachment>[];
    final status = _classroomStatus(assignment, submission);
    final isDraft =
        submission == null || submission.status == SubmissionStatus.draft;
    final deadlineClosed =
        assignment.isPastDue && !assignment.allowLateSubmission;
    final canEdit = isDraft && !deadlineClosed;
    final shouldSubmit =
        assignment.requiresAttachment ||
        assignment.isCodeActivity ||
        attachments.isNotEmpty;

    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your work', style: AppTextStyles.h4)),
              _StatusBadge(status: status),
            ],
          ),
          if (submission?.submittedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '${submission!.status == SubmissionStatus.done ? 'Completed' : 'Submitted'} '
              '${_dateTimeLabel(submission.submittedAt!)}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          if (submission?.score != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Final grade: ${_displayNumber(submission!.score!)}/${assignment.maxPoints}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (submission.criterionScores.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Text('Criteria breakdown', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    ...submission.criterionScores.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.criterionName)),
                            Text(
                              '${_displayNumber(item.score)}/${_displayNumber(item.maxPoints)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (submission?.feedback?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text('Feedback', style: AppTextStyles.label),
            const SizedBox(height: 4),
            Text(submission!.feedback!),
          ],
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...attachments.map(
              (attachment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AssignmentAttachmentTile(
                  attachment: attachment,
                  isBusy: _isWorkBusy,
                  onOpen: () => _openAttachment(attachment),
                  onRemove: canEdit
                      ? () => _removeStudentAttachment(state, attachment)
                      : null,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                assignment.requiresAttachment
                    ? 'No work attached yet.'
                    : 'No attachment is required.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isWorkBusy
                        ? null
                        : () => _addStudentFile(state),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('File'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isWorkBusy
                        ? null
                        : () => _addStudentLink(state),
                    icon: const Icon(Icons.link),
                    label: const Text('Link'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (shouldSubmit) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('turn-in-work'),
                  onPressed: state.isSubmitting || _isWorkBusy
                      ? null
                      : () => _confirmTurnIn(state),
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Turn in'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const ValueKey('mark-work-done'),
                  onPressed: state.isSubmitting || _isWorkBusy
                      ? null
                      : () => _confirmMarkDone(state),
                  child: const Text('Mark as done'),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('mark-work-done'),
                  onPressed: state.isSubmitting || _isWorkBusy
                      ? null
                      : () => _confirmMarkDone(state),
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Mark as done'),
                ),
              ),
          ] else if (submission?.canUnsubmit(assignment) == true) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey('unsubmit-work'),
                onPressed: state.isUnsubmitting
                    ? null
                    : () => _confirmUnsubmit(state),
                child: state.isUnsubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        submission?.status == SubmissionStatus.done
                            ? 'Undo'
                            : 'Unsubmit',
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unsubmit before the deadline to edit or replace your work.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ] else if (submission?.isCompleted == true) ...[
            const SizedBox(height: 14),
            Text(
              submission!.isGraded
                  ? 'This work has been graded and can no longer be unsubmitted.'
                  : 'The deadline has passed. This work can no longer be unsubmitted.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ] else if (deadlineClosed) ...[
            const SizedBox(height: 14),
            Text(
              'The deadline has passed and late submissions are closed.',
              style: const TextStyle(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addStudentFile(AssignmentDetailLoaded state) async {
    final repository = context.read<AssignmentRepository>();
    final current = state.submission?.attachments ?? const [];
    if (current.length >= AssignmentRepository.maxAttachments) {
      _showMessage('You can attach up to 10 items.', AppColors.error);
      return;
    }

    setState(() => _isWorkBusy = true);
    AssignmentAttachment? uploaded;
    try {
      final file = await pickAssignmentFile();
      if (file == null || !mounted) return;
      uploaded = await repository.uploadAttachment(
        courseId: widget.courseId,
        assignmentId: widget.assignmentId,
        userId: _userId,
        fileName: file.name,
        mimeType: file.mimeType,
        bytes: file.bytes,
        isSubmission: true,
      );
      await repository.saveDraft(
        assignmentId: widget.assignmentId,
        courseId: widget.courseId,
        userId: _userId,
        userDisplayName: _userDisplayName,
        code: _currentCode,
        language: state.assignment.language,
        attachments: [...current, uploaded],
      );
      if (mounted) {
        _showMessage('File attached.', AppColors.success);
        _loadAssignment();
      }
    } catch (error) {
      if (uploaded != null) {
        try {
          await repository.deleteStoredAttachment(uploaded);
        } catch (_) {}
      }
      if (mounted) _showMessage(error.toString(), AppColors.error);
    } finally {
      if (mounted) setState(() => _isWorkBusy = false);
    }
  }

  Future<void> _addStudentLink(AssignmentDetailLoaded state) async {
    final current = state.submission?.attachments ?? const [];
    if (current.length >= AssignmentRepository.maxAttachments) {
      _showMessage('You can attach up to 10 items.', AppColors.error);
      return;
    }

    final attachment = await _showLinkDialog();
    if (attachment == null || !mounted) return;
    setState(() => _isWorkBusy = true);
    try {
      await context.read<AssignmentRepository>().saveDraft(
        assignmentId: widget.assignmentId,
        courseId: widget.courseId,
        userId: _userId,
        userDisplayName: _userDisplayName,
        code: _currentCode,
        language: state.assignment.language,
        attachments: [...current, attachment],
      );
      if (mounted) {
        _showMessage('Link attached.', AppColors.success);
        _loadAssignment();
      }
    } catch (error) {
      if (mounted) _showMessage(error.toString(), AppColors.error);
    } finally {
      if (mounted) setState(() => _isWorkBusy = false);
    }
  }

  Future<AssignmentAttachment?> _showLinkDialog() async {
    var linkName = '';
    var linkUrl = '';
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<AssignmentAttachment>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Attach a web link'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                autofocus: true,
                keyboardType: TextInputType.url,
                onChanged: (value) => linkUrl = value,
                decoration: const InputDecoration(
                  labelText: 'Web address',
                  hintText: 'https://example.com',
                ),
                validator: validateWebUrl,
              ),
              const SizedBox(height: 12),
              TextFormField(
                onChanged: (value) => linkName = value,
                decoration: const InputDecoration(
                  labelText: 'Display name (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final uri = normalizeWebUrl(linkUrl);
              Navigator.pop(
                dialogContext,
                AssignmentAttachment(
                  id: const Uuid().v4(),
                  name: linkName.trim().isEmpty ? uri.host : linkName.trim(),
                  kind: AssignmentAttachmentKind.link,
                  url: uri.toString(),
                ),
              );
            },
            child: const Text('Attach'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _removeStudentAttachment(
    AssignmentDetailLoaded state,
    AssignmentAttachment attachment,
  ) async {
    final updated = List<AssignmentAttachment>.from(
      state.submission?.attachments ?? const [],
    )..removeWhere((item) => item.id == attachment.id);

    setState(() => _isWorkBusy = true);
    try {
      final repository = context.read<AssignmentRepository>();
      await repository.saveDraft(
        assignmentId: widget.assignmentId,
        courseId: widget.courseId,
        userId: _userId,
        userDisplayName: _userDisplayName,
        code: _currentCode,
        language: state.assignment.language,
        attachments: updated,
      );
      await repository.deleteStoredAttachment(attachment);
      if (mounted) {
        _showMessage('Attachment removed.', AppColors.success);
        _loadAssignment();
      }
    } catch (error) {
      if (mounted) _showMessage(error.toString(), AppColors.error);
    } finally {
      if (mounted) setState(() => _isWorkBusy = false);
    }
  }

  void _saveDraft(AssignmentDetailLoaded state) {
    _assignmentBloc.add(
      SaveDraft(
        assignmentId: widget.assignmentId,
        courseId: widget.courseId,
        userId: _userId,
        userDisplayName: _userDisplayName,
        code: _currentCode,
        language: state.assignment.language,
        attachments: state.submission?.attachments,
      ),
    );
  }

  Future<void> _confirmTurnIn(AssignmentDetailLoaded state) async {
    if (state.assignment.requiresAttachment &&
        (state.submission?.attachments.isEmpty ?? true)) {
      _showMessage(
        'Attach at least one file or link before turning in.',
        AppColors.error,
      );
      return;
    }
    final confirmed = await _confirmationDialog(
      title: 'Turn in your work?',
      message: 'You will need to unsubmit before the deadline to make changes.',
      action: 'Turn in',
    );
    if (confirmed != true) return;
    _assignmentBloc.add(
      SubmitAssignment(
        assignmentId: widget.assignmentId,
        courseId: widget.courseId,
        userId: _userId,
        userDisplayName: _userDisplayName,
        code: _currentCode,
        attachments: state.submission?.attachments,
      ),
    );
  }

  Future<void> _confirmMarkDone(AssignmentDetailLoaded state) async {
    final requiresWork =
        state.assignment.requiresAttachment || state.assignment.isCodeActivity;
    final confirmed = await _confirmationDialog(
      title: 'Mark this activity as done?',
      message: requiresWork
          ? 'This marks the activity Done without turning in your file, link, or code. You can undo it before the deadline.'
          : 'This records the activity as completed. You can undo it before the deadline.',
      action: 'Mark as done',
    );
    if (confirmed != true) return;
    _assignmentBloc.add(
      MarkAssignmentDone(
        assignmentId: widget.assignmentId,
        courseId: widget.courseId,
        userId: _userId,
        userDisplayName: _userDisplayName,
        code: _currentCode,
        attachments: state.submission?.attachments,
      ),
    );
  }

  Future<void> _confirmUnsubmit(AssignmentDetailLoaded state) async {
    final isMarkedDone = state.submission?.status == SubmissionStatus.done;
    final confirmed = await _confirmationDialog(
      title: isMarkedDone ? 'Undo mark as done?' : 'Unsubmit this work?',
      message: isMarkedDone
          ? 'The activity will return to Assigned so you can continue working on it.'
          : 'Your work will return to draft so you can edit or replace it.',
      action: isMarkedDone ? 'Undo' : 'Unsubmit',
    );
    if (confirmed != true) return;
    _assignmentBloc.add(
      UnsubmitAssignment(assignmentId: widget.assignmentId, userId: _userId),
    );
  }

  Future<bool?> _confirmationDialog({
    required String title,
    required String message,
    required String action,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
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
    } catch (error) {
      if (mounted) _showMessage(error.toString(), AppColors.error);
    }
  }

  Future<void> _deleteAssignment(AssignmentModel assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AppColors.error),
        title: const Text('Delete activity?'),
        content: Text(
          '"${assignment.title}" and every student submission will be '
          'permanently deleted. This cannot be undone.',
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
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) _showMessage(error.toString(), AppColors.error);
    }
  }

  ClassroomSubmissionStatus _classroomStatus(
    AssignmentModel assignment,
    SubmissionModel? submission,
  ) {
    if (submission != null) return submission.classroomStatus(assignment);
    if (assignment.isPastDue) return ClassroomSubmissionStatus.missing;
    return ClassroomSubmissionStatus.assigned;
  }

  String _dueLabel(DateTime? dueDate) {
    if (dueDate == null) return 'No due date';
    return 'Due ${DateFormat('MMM d, y, h:mm a').format(dueDate.toLocal())}';
  }

  String _dateTimeLabel(DateTime date) {
    return DateFormat('MMM d, y, h:mm a').format(date.toLocal());
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}

class _DetailCard extends StatelessWidget {
  final Widget child;

  const _DetailCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.backgroundSecondary,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            softWrap: true,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ClassroomSubmissionStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ClassroomSubmissionStatus.assigned => AppColors.info,
      ClassroomSubmissionStatus.submitted => AppColors.success,
      ClassroomSubmissionStatus.done => AppColors.success,
      ClassroomSubmissionStatus.missing => AppColors.error,
      ClassroomSubmissionStatus.late => AppColors.warning,
    };
    return _SimpleBadge(label: status.displayName, color: color);
  }
}

class _SimpleBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SimpleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
