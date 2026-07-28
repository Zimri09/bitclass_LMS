import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/courses/data/models/course_model.dart';
import 'course_banner.dart';

/// A shared class card for both the teaching and learning views.
class ClassroomCourseCard extends StatelessWidget {
  final CourseModel course;
  final String subtitle;
  final String? statusLabel;
  final Color? statusColor;
  final Widget? trailing;
  final List<Widget> footer;
  final VoidCallback onTap;

  const ClassroomCourseCard({
    super.key,
    required this.course,
    required this.subtitle,
    required this.onTap,
    this.statusLabel,
    this.statusColor,
    this.trailing,
    this.footer = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final status = statusLabel;
    final badgeColor = statusColor ?? AppColors.primary;

    return Material(
      color: colors.backgroundSecondary,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 156,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CourseBannerWidget(
                      thumbnailUrl: course.thumbnailUrl,
                      width: double.infinity,
                      height: 156,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      darkenOpacity: 0.28,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.38),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  course.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.h3.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                              if (trailing != null) trailing!,
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _BannerLabel(label: course.category),
                              if (status != null)
                                _BannerLabel(
                                  label: status,
                                  color: badgeColor,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.14,
                      ),
                      child: Icon(
                        Icons.school_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        course.instructorName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...footer,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerLabel extends StatelessWidget {
  final String label;
  final Color? color;

  const _BannerLabel({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
