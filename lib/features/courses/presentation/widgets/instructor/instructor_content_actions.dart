import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

/// Course-content creation actions shown only to the course instructor.
class InstructorContentActions extends StatelessWidget {
  final String courseId;
  final VoidCallback onContentChanged;

  const InstructorContentActions({
    super.key,
    required this.courseId,
    required this.onContentChanged,
  });

  Future<void> _open(BuildContext context, String location) async {
    await context.push(location);
    onContentChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build_circle_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text('Create content', style: AppTextStyles.bodyLarge),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Add lessons, activities, or supporting files.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InstructorAction(
                icon: Icons.video_library_outlined,
                label: 'Add Lesson',
                color: AppColors.primary,
                onTap: () =>
                    _open(context, '/courses/$courseId/lessons/create'),
              ),
              _InstructorAction(
                icon: Icons.quiz_outlined,
                label: 'Add Quiz',
                color: AppColors.secondary,
                onTap: () =>
                    _open(context, '/courses/$courseId/quizzes/create'),
              ),
              _InstructorAction(
                icon: Icons.assignment_outlined,
                label: 'Add Activity',
                color: AppColors.warning,
                onTap: () =>
                    _open(context, AppRoutes.createAssignmentPath(courseId)),
              ),
              _InstructorAction(
                icon: Icons.folder_copy_outlined,
                label: 'Course materials',
                color: AppColors.success,
                onTap: () => _open(context, AppRoutes.filesPath(courseId)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InstructorAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _InstructorAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: 0.06),
        side: BorderSide(color: color.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
