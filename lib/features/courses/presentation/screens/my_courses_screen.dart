import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/course_banner.dart';
import '../../../../shared/widgets/glow_card.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/course_model.dart';
import '../../data/repositories/course_repository.dart';

/// Screen showing instructor's created courses
class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  List<CourseModel>? _courses;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final courses = await context
            .read<CourseRepository>()
            .getInstructorCourses(authState.user.id);
        setState(() {
          _courses = courses;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadCourses,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: Text('My Courses', style: AppTextStyles.h3),
              actions: [
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.createCourse),
                  icon: const Icon(Icons.add),
                  label: const Text('New Course'),
                ),
                const SizedBox(width: 16),
              ],
            ),

            // Content
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
                  title: 'No courses yet',
                  subtitle: 'Create your first course to start teaching',
                  action: ElevatedButton.icon(
                    onPressed: () => context.go(AppRoutes.createCourse),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Course'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(24),
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
    return GlowCard(
      glowColor: course.isPublished ? AppColors.success : AppColors.warning,
      glowIntensity: 0.1,
      onTap: () => context.go(AppRoutes.courseDetailPath(course.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          CourseBannerWidget(
            thumbnailUrl: course.thumbnailUrl,
            width: 120,
            height: 90,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (course.isPublished
                                    ? AppColors.success
                                    : AppColors.warning)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        course.isPublished ? 'Published' : 'Draft',
                        style: AppTextStyles.caption.copyWith(
                          color: course.isPublished
                              ? AppColors.success
                              : AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        course.category,
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  course.title,
                  style: AppTextStyles.h4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  course.description,
                  style: AppTextStyles.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStat(
                      Icons.people_outline,
                      '${course.enrollmentCount}',
                    ),
                    const SizedBox(width: 16),
                    _buildStat(
                      Icons.menu_book_outlined,
                      '${course.lessonCount}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  context.push(AppRoutes.editCoursePath(course.id));
                  break;
                case 'lessons':
                  context.push('/courses/${course.id}');
                  break;
                case 'publish':
                  _togglePublish(context);
                  break;
                case 'delete':
                  _showDeleteDialog(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'lessons',
                child: Row(
                  children: [
                    Icon(Icons.menu_book, size: 20),
                    SizedBox(width: 8),
                    Text('Manage Lessons'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'publish',
                child: Row(
                  children: [
                    Icon(
                      course.isPublished ? Icons.unpublished : Icons.publish,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(course.isPublished ? 'Unpublish' : 'Publish'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _togglePublish(BuildContext context) async {
    try {
      final newState = !course.isPublished;
      await context.read<CourseRepository>().togglePublish(course.id, newState);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newState ? 'Course published!' : 'Course unpublished'),
          backgroundColor: AppColors.success,
        ),
      );
      onRefresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Course?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${course.title}"? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Course deleted'),
                    backgroundColor: AppColors.success,
                  ),
                );
                onRefresh();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete: $e'),
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

  Widget _buildStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.caption),
      ],
    );
  }
}
