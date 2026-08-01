import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/classroom_course_card.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/course_model.dart';
import '../../data/repositories/course_repository.dart';

/// Classroom-style list of the courses managed by the signed-in instructor.
class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  List<CourseModel>? _courses;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<CourseModel>>? _coursesSubscription;

  @override
  void initState() {
    super.initState();
    _listenToCourses();
  }

  @override
  void dispose() {
    _coursesSubscription?.cancel();
    super.dispose();
  }

  void _listenToCourses() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      setState(() {
        _isLoading = false;
        _error = 'Please sign in again.';
      });
      return;
    }

    _coursesSubscription = context
        .read<CourseRepository>()
        .watchInstructorCourses(authState.user.id)
        .listen(
          (courses) {
            if (!mounted) return;
            setState(() {
              _courses = courses;
              _isLoading = false;
              _error = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _error = error.toString();
              _isLoading = false;
            });
          },
        );
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) return;

      final courses = await context
          .read<CourseRepository>()
          .getInstructorCourses(authState.user.id);
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadCourses,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              leading: const AppDrawerButton(),
              title: Text('Teaching', style: AppTextStyles.h3),
              actions: [
                TextButton.icon(
                  onPressed: () => context.push(AppRoutes.createCourse),
                  icon: const Icon(Icons.add),
                  label: const Text('Create class'),
                ),
                const SizedBox(width: 12),
              ],
            ),
            if (_isLoading)
              const SliverCourseGridSkeleton()
            else if (_error != null)
              SliverFillRemaining(
                child: ErrorState(message: _error!, onRetry: _loadCourses),
              )
            else if (_courses == null || _courses!.isEmpty)
              SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.school_outlined,
                  title: 'No classes yet',
                  subtitle: 'Create your first class to start teaching',
                  action: ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.createCourse),
                    icon: const Icon(Icons.add),
                    label: const Text('Create class'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _InstructorCourseCard(
                        course: _courses![index],
                        onRefresh: _loadCourses,
                      ),
                    ),
                    childCount: _courses!.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InstructorCourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onRefresh;

  const _InstructorCourseCard({required this.course, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ClassroomCourseCard(
      course: course,
      statusLabel: course.isPublished ? 'Published' : 'Draft',
      statusColor: course.isPublished ? AppColors.success : AppColors.warning,
      onTap: () => context.push(AppRoutes.courseDetailPath(course.id)),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: (value) => _handleAction(context, value),
        itemBuilder: (context) => [
          _menuItem('edit', Icons.edit_outlined, 'Edit class'),
          _menuItem('content', Icons.menu_book_outlined, 'Manage content'),
          const PopupMenuDivider(),
          _menuItem('lesson', Icons.video_library_outlined, 'Add lesson'),
          _menuItem('quiz', Icons.quiz_outlined, 'Add quiz'),
          _menuItem('assignment', Icons.assignment_outlined, 'Add assignment'),
          _menuItem('files', Icons.upload_file_outlined, 'Upload materials'),
          const PopupMenuDivider(),
          _menuItem(
            'publish',
            course.isPublished ? Icons.unpublished : Icons.publish,
            course.isPublished ? 'Unpublish' : 'Publish',
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                const SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
      ),
      footer: [
        _stat(Icons.people_outline, '${course.enrollmentCount}'),
        const SizedBox(width: 14),
        _stat(Icons.menu_book_outlined, '${course.lessonCount}'),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(label)],
      ),
    );
  }

  Widget _stat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(value, style: AppTextStyles.caption),
      ],
    );
  }

  void _handleAction(BuildContext context, String value) {
    switch (value) {
      case 'edit':
        context.push(AppRoutes.editCoursePath(course.id));
        return;
      case 'content':
        context.push(AppRoutes.courseDetailPath(course.id));
        return;
      case 'lesson':
        context.push('/courses/${course.id}/lessons/create');
        return;
      case 'quiz':
        context.push('/courses/${course.id}/quizzes/create');
        return;
      case 'assignment':
        context.push('/courses/${course.id}/assignments/create');
        return;
      case 'files':
        context.push(AppRoutes.filesPath(course.id));
        return;
      case 'publish':
        _togglePublish(context);
        return;
      case 'delete':
        _showDeleteDialog(context);
        return;
    }
  }

  Future<void> _togglePublish(BuildContext context) async {
    try {
      final isNowPublished = !course.isPublished;
      await context.read<CourseRepository>().togglePublish(
        course.id,
        isNowPublished,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowPublished ? 'Class published' : 'Class unpublished',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      onRefresh();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyErrorMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete class?'),
        content: Text(
          'Delete "${course.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await context.read<CourseRepository>().deleteCourse(course.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Class deleted'),
                    backgroundColor: AppColors.success,
                  ),
                );
                onRefresh();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(userFriendlyErrorMessage(error)),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
