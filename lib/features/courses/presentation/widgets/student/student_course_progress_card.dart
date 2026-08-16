import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/widgets/glow_card.dart';
import '../../../../lessons/data/repositories/lesson_repository.dart';

/// Student-only summary of completed lessons in a course.
class StudentCourseProgressCard extends StatefulWidget {
  final String courseId;
  final String enrollmentId;

  const StudentCourseProgressCard({
    super.key,
    required this.courseId,
    required this.enrollmentId,
  });

  @override
  State<StudentCourseProgressCard> createState() =>
      _StudentCourseProgressCardState();
}

class _StudentCourseProgressCardState extends State<StudentCourseProgressCard> {
  late Future<_CourseProgressSummary> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressFuture = _loadProgress();
  }

  @override
  void didUpdateWidget(covariant StudentCourseProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId ||
        oldWidget.enrollmentId != widget.enrollmentId) {
      _progressFuture = _loadProgress();
    }
  }

  Future<_CourseProgressSummary> _loadProgress() async {
    final lessonRepository = context.read<LessonRepository>();
    final lessons = await lessonRepository.getLessons(widget.courseId);
    final lessonProgress = await lessonRepository.getCourseProgress(
      widget.courseId,
      widget.enrollmentId,
    );

    return _CourseProgressSummary(
      completedLessons: lessonProgress
          .where((progress) => progress.isCompleted)
          .length,
      totalLessons: lessons.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CourseProgressSummary>(
      future: _progressFuture,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final completedLessons = summary?.completedLessons ?? 0;
        final totalLessons = summary?.totalLessons ?? 0;
        final progress = totalLessons == 0
            ? 0.0
            : completedLessons / totalLessons;

        return GlowCard(
          glowColor: progress >= 1.0 ? AppColors.success : AppColors.primary,
          glowIntensity: 0.1,
          isHoverable: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Overall Progress', style: AppTextStyles.bodyMedium),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: AppTextStyles.h4.copyWith(
                      color: progress >= 1.0
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? AppColors.success : AppColors.primary,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$completedLessons of $totalLessons lessons completed',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CourseProgressSummary {
  final int completedLessons;
  final int totalLessons;

  const _CourseProgressSummary({
    required this.completedLessons,
    required this.totalLessons,
  });
}
