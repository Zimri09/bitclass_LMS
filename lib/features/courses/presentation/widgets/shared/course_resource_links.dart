import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

/// Shared links to learning materials and classwork for a course.
class CourseResourceLinks extends StatelessWidget {
  final String courseId;
  final VoidCallback onOpenClasswork;

  const CourseResourceLinks({
    super.key,
    required this.courseId,
    required this.onOpenClasswork,
  });

  @override
  Widget build(BuildContext context) {
    final materials = _CourseResourceCard(
      icon: Icons.folder_outlined,
      color: AppColors.success,
      title: 'Learning materials',
      description: 'Files, links, and supporting resources',
      onTap: () => context.push(AppRoutes.filesPath(courseId)),
    );
    final classwork = _CourseResourceCard(
      icon: Icons.assignment_outlined,
      color: AppColors.warning,
      title: 'Assignments & activities',
      description: 'Quizzes, assignments, and class activities',
      onTap: onOpenClasswork,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [materials, const SizedBox(height: 10), classwork],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: materials),
            const SizedBox(width: 12),
            Expanded(child: classwork),
          ],
        );
      },
    );
  }
}

class _CourseResourceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _CourseResourceCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
