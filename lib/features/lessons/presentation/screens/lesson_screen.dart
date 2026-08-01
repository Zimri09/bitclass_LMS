import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/url_utils.dart';
import '../../../../shared/widgets/lesson_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../courses/data/repositories/course_repository.dart';
import '../../../files/data/models/models.dart';
import '../../../files/data/repositories/file_repository.dart';
import '../../data/models/models.dart';
import '../../data/repositories/lesson_repository.dart';
import '../bloc/lesson_bloc.dart';

/// Screen for viewing lesson content
class LessonScreen extends StatefulWidget {
  final String courseId;
  final String lessonId;

  const LessonScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late LessonBloc _lessonBloc;
  late Future<List<CourseFile>> _attachments;
  final ScrollController _scrollController = ScrollController();
  bool _canManageLesson = false;
  List<String> _pendingDeletedAttachmentIds = const [];

  bool get _isInstructor {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.user.role == 'instructor';
  }

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.id;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _lessonBloc = LessonBloc(
      lessonRepository: context.read<LessonRepository>(),
    );
    _attachments = context.read<FileRepository>().getLessonFiles(
      widget.courseId,
      widget.lessonId,
    );
    _loadManagementPermission();
    _loadLesson();
  }

  Future<void> _loadManagementPermission() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated ||
        authState.user.role != 'instructor') {
      return;
    }

    try {
      final course = await context.read<CourseRepository>().getCourse(
        widget.courseId,
      );
      if (mounted) {
        setState(() {
          _canManageLesson = course?.instructorId == authState.user.id;
        });
      }
    } catch (_) {
      // RLS remains the authority; hide controls if ownership cannot be loaded.
    }
  }

  void _loadLesson() {
    _lessonBloc.add(
      LoadLessonDetail(
        courseId: widget.courseId,
        lessonId: widget.lessonId,
        userId: _currentUserId,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant LessonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId ||
        oldWidget.lessonId != widget.lessonId) {
      _attachments = context.read<FileRepository>().getLessonFiles(
        widget.courseId,
        widget.lessonId,
      );
      _loadLesson();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _lessonBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _lessonBloc,
      child: BlocConsumer<LessonBloc, LessonState>(
        listener: (context, state) {
          if (state is LessonCompletionUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.progress.isCompleted
                      ? 'Lesson marked as complete!'
                      : 'Lesson marked as incomplete.',
                ),
                backgroundColor: AppColors.success,
              ),
            );
            // Reload to update completion status
            _loadLesson();
          } else if (state is LessonDeleted) {
            _removePendingOfflineCopies();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Lesson and attached files deleted.'),
                backgroundColor: AppColors.success,
              ),
            );
            context.go(AppRoutes.courseDetailPath(widget.courseId));
          } else if (state is LessonError) {
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
            appBar: _buildAppBar(context, state),
            body: _buildBody(context, state),
            bottomNavigationBar: state is LessonDetailLoaded
                ? _buildBottomNav(context, state)
                : null,
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, LessonState state) {
    String title = 'Lesson';
    if (state is LessonDetailLoaded) {
      title = state.lesson.title;
    }

    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: _handleBack,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (state is LessonDetailLoaded) ...[
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () => _showLessonInfo(context, state.lesson),
          ),
          if (_canManageLesson)
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') {
                  _editLesson();
                } else if (action == 'delete') {
                  _confirmDeleteLesson();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit lesson'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: AppColors.error),
                    title: Text(
                      'Delete lesson',
                      style: TextStyle(color: AppColors.error),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _buildBody(BuildContext context, LessonState state) {
    if (state is LessonLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is LessonError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load lesson',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _loadLesson, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (state is LessonDetailLoaded) {
      return SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lesson header
            _buildLessonHeader(context, state),
            // Lesson content
            _buildLessonContent(context, state.lesson),
            // Files added through "Save and attach" stay with this lesson.
            _buildAttachments(),
          ],
        ),
      );
    }

    return const Center(child: Text('Loading...'));
  }

  Widget _buildLessonHeader(BuildContext context, LessonDetailLoaded state) {
    final lesson = state.lesson;
    final module = state.module;

    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Module breadcrumb
          if (module != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                module.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Title
          Text(
            lesson.title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (lesson.description != null) ...[
            const SizedBox(height: 8),
            Text(
              lesson.description!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Meta info row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMetaChip(
                icon: _getLessonTypeIcon(lesson.type),
                label: _getLessonTypeLabel(lesson.type),
              ),
              _buildMetaChip(
                icon: Icons.access_time,
                label: '${lesson.durationMinutes} min',
              ),
              if (state.progress?.isCompleted == true)
                _buildMetaChip(
                  icon: Icons.check_circle,
                  label: 'Completed',
                  color: AppColors.success,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
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

  Widget _buildLessonContent(BuildContext context, LessonModel lesson) {
    final content = lesson.content;
    if (content == null || content.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.description_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No content available',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Check lesson type for different rendering
    switch (lesson.type) {
      case LessonType.video:
        return _buildVideoLesson(lesson, content);
      case LessonType.quiz:
        return _buildQuizLesson(lesson);
      case LessonType.code:
      case LessonType.text:
        // Markdown content for text and code lessons
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: MarkdownContent(content: content, selectable: true),
        );
    }
  }

  Widget _buildAttachments() {
    return FutureBuilder<List<CourseFile>>(
      future: _attachments,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final attachments = snapshot.data;
        if (snapshot.hasError || attachments == null || attachments.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.attach_file, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Attachments',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...attachments.map(
                (file) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    file.isExternalLink
                        ? Icons.link
                        : Icons.insert_drive_file_outlined,
                  ),
                  title: Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    file.description.isEmpty
                        ? file.formattedSize
                        : file.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openAttachment(file),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAttachment(CourseFile file) async {
    final fileRepository = context.read<FileRepository>();
    try {
      final uri = file.isExternalLink
          ? normalizeWebUrl(file.url)
          : Uri.parse(file.url);
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('No application can open this resource.');

      if (!file.isExternalLink) {
        try {
          await fileRepository.recordDownload(
            widget.courseId,
            file.id,
          );
        } catch (_) {
          // A read-only student can still open the attachment.
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This resource cannot be opened. Check the link and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _openLessonUrl(String value) async {
    try {
      final opened = await launchUrl(
        normalizeWebUrl(value),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('No application can open this video.');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This video link cannot be opened. Check the URL and try again.',
          ),
        ),
      );
    }
  }

  Widget _buildVideoLesson(LessonModel lesson, String content) {
    final videoUrl = lesson.videoUrl?.trim();
    var videoLabel = 'External video link';
    if (videoUrl != null && videoUrl.isNotEmpty) {
      try {
        videoLabel = normalizeWebUrl(videoUrl).host;
      } on FormatException {
        // Keep legacy invalid links visible without breaking the lesson screen.
      }
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_circle_fill,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    videoUrl == null || videoUrl.isEmpty
                        ? 'No video link added'
                        : 'Video resource',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    videoUrl == null || videoUrl.isEmpty
                        ? 'The instructor has not added a video URL.'
                        : videoLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (videoUrl != null && videoUrl.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _openLessonUrl(videoUrl),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open Video'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Show video notes as markdown
          MarkdownContent(content: content, selectable: true),
        ],
      ),
    );
  }

  Widget _buildQuizLesson(LessonModel lesson) {
    final content = lesson.content ?? '';
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final isInstructor = _isInstructor;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.quiz_outlined,
                    size: 64,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lesson.title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Test your knowledge with this quiz',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!isInstructor)
                    FilledButton.icon(
                      onPressed: () {
                        context.push(
                          '/courses/${widget.courseId}/quizzes/${lesson.id}',
                        );
                      },
                      icon: Icon(Icons.play_arrow),
                      label: const Text('Start Quiz'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Instructor preview mode',
                        style: TextStyle(
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Show quiz description
          if (content.isNotEmpty) ...[
            const SizedBox(height: 24),
            MarkdownContent(content: content, selectable: true),
          ],
        ],
      ),
    );
  }

  Widget? _buildBottomNav(BuildContext context, LessonDetailLoaded state) {
    final isCompleted = state.progress?.isCompleted == true;

    return LessonNavigationBar(
      previousLessonTitle: state.previousLessonId != null ? 'Previous' : null,
      nextLessonTitle: state.nextLessonId != null ? 'Next' : null,
      onPrevious: state.previousLessonId != null
          ? () => _navigateToLesson(
              state.previousLessonId!,
              currentLessonId: state.lesson.id,
            )
          : null,
      onNext: state.nextLessonId != null
          ? () => _navigateToLesson(
              state.nextLessonId!,
              currentLessonId: state.lesson.id,
            )
          : null,
      onMarkComplete: _isInstructor ? null : () => _setLessonCompletion(isCompleted),
      isCompleted: isCompleted,
      isLoading: false,
    );
  }

  void _navigateToLesson(String lessonId, {String? currentLessonId}) {
    final currentId = currentLessonId ?? widget.lessonId;
    if (lessonId == currentId) return;

    context.pushReplacement(AppRoutes.lessonPath(widget.courseId, lessonId));
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go(AppRoutes.courseDetailPath(widget.courseId));
  }

  Future<void> _editLesson() async {
    final updated = await context.push<bool>(
      AppRoutes.editLessonPath(widget.courseId, widget.lessonId),
    );
    if (updated == true && mounted) {
      _loadLesson();
    }
  }

  Future<void> _confirmDeleteLesson() async {
    var attachmentCount = 0;
    try {
      final attachments = await _attachments;
      attachmentCount = attachments.length;
      _pendingDeletedAttachmentIds = attachments
          .map((attachment) => attachment.id)
          .toList(growable: false);
    } catch (_) {
      _pendingDeletedAttachmentIds = const [];
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete lesson?'),
        content: Text(
          attachmentCount == 0
              ? 'This will permanently remove the lesson and its student progress.'
              : 'This will permanently remove the lesson, its student progress, '
                    'and $attachmentCount attached ${attachmentCount == 1 ? 'file' : 'files'} '
                    'from Supabase Storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _lessonBloc.add(
        DeleteLesson(courseId: widget.courseId, lessonId: widget.lessonId),
      );
    }
  }

  Future<void> _removePendingOfflineCopies() async {
    final userId = _currentUserId;
    if (userId == null || _pendingDeletedAttachmentIds.isEmpty) return;

    final repository = context.read<FileRepository>();
    for (final fileId in _pendingDeletedAttachmentIds) {
      try {
        await repository.removeOfflineFile(userId: userId, fileId: fileId);
      } catch (_) {
        // Remote lesson deletion succeeded; stale local metadata is pruned
        // automatically if its file is later missing.
      }
    }
    _pendingDeletedAttachmentIds = const [];
  }

  Future<void> _setLessonCompletion(bool isCurrentlyCompleted) async {
    if (_isInstructor) {
      return;
    }

    final userId = _currentUserId;
    if (userId == null) {
      return; // Cannot mark complete if not logged in
    }

    try {
      final enrollment = await context.read<CourseRepository>().getEnrollment(
        widget.courseId,
        userId,
      );
      if (!mounted) return;

      if (enrollment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Enroll in this course before updating lesson completion.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (isCurrentlyCompleted) {
        _lessonBloc.add(
          MarkLessonIncomplete(
            courseId: widget.courseId,
            lessonId: widget.lessonId,
            enrollmentId: enrollment.id,
            userId: userId,
          ),
        );
      } else {
        _lessonBloc.add(
          MarkLessonComplete(
            courseId: widget.courseId,
            lessonId: widget.lessonId,
            enrollmentId: enrollment.id,
            userId: userId,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to update lesson completion. Please try again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showLessonInfo(BuildContext context, LessonModel lesson) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lesson Information',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Title', lesson.title),
            if (lesson.description != null)
              _buildInfoRow('Description', lesson.description!),
            _buildInfoRow('Type', _getLessonTypeLabel(lesson.type)),
            _buildInfoRow('Duration', '${lesson.durationMinutes} minutes'),
            _buildInfoRow(
              'Created',
              '${lesson.createdAt.day}/${lesson.createdAt.month}/${lesson.createdAt.year}',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLessonTypeIcon(LessonType type) {
    switch (type) {
      case LessonType.video:
        return Icons.play_circle_outline;
      case LessonType.code:
        return Icons.code;
      case LessonType.quiz:
        return Icons.quiz_outlined;
      case LessonType.text:
        return Icons.article_outlined;
    }
  }

  String _getLessonTypeLabel(LessonType type) {
    switch (type) {
      case LessonType.video:
        return 'Video';
      case LessonType.code:
        return 'Code';
      case LessonType.quiz:
        return 'Quiz';
      case LessonType.text:
        return 'Reading';
    }
  }
}
