import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/courses/data/models/course_model.dart';
import '../../features/courses/data/repositories/course_repository.dart';
import 'course_banner.dart';

/// A shared class card for both the teaching and learning views.
class ClassroomCourseCard extends StatelessWidget {
  final CourseModel course;
  final String? statusLabel;
  final Color? statusColor;
  final Widget? trailing;
  final List<Widget> footer;
  final VoidCallback onTap;
  final bool? compact;

  const ClassroomCourseCard({
    super.key,
    required this.course,
    required this.onTap,
    this.statusLabel,
    this.statusColor,
    this.trailing,
    this.footer = const [],
    this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CourseModel?>(
      stream: context.read<CourseRepository>().watchCourse(course.id),
      initialData: course,
      builder: (context, snapshot) =>
          _buildCard(context, snapshot.data ?? course),
    );
  }

  Widget _buildCard(BuildContext context, CourseModel currentCourse) {
    if (compact ?? kIsWeb) {
      return _buildCompactCard(context, currentCourse);
    }

    return _buildMobileCard(context, currentCourse);
  }

  Widget _buildMobileCard(BuildContext context, CourseModel currentCourse) {
    final hasAvatar = currentCourse.instructorAvatarUrl?.isNotEmpty == true;
    final colors = AppColors.of(context);
    final status = statusLabel;
    final badgeColor = statusColor ?? AppColors.primary;

    return Material(
      color: colors.backgroundSecondary,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CourseBannerWidget(
                      thumbnailUrl: currentCourse.thumbnailUrl,
                      width: double.infinity,
                      height: 120,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
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
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  currentCourse.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.h3.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              ?trailing,
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentCourse.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                          const Spacer(),
                          if (status != null)
                            _BannerLabel(label: status, color: badgeColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.14,
                      ),
                      backgroundImage: hasAvatar
                          ? NetworkImage(currentCourse.instructorAvatarUrl!)
                          : null,
                      child: hasAvatar
                          ? null
                          : Icon(
                              Icons.school_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        currentCourse.instructorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildCompactCard(BuildContext context, CourseModel currentCourse) {
    final hasAvatar = currentCourse.instructorAvatarUrl?.isNotEmpty == true;
    final colors = AppColors.of(context);
    final status = statusLabel;
    final badgeColor = statusColor ?? AppColors.primary;

    return Material(
      color: colors.backgroundSecondary,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 112,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CourseBannerWidget(
                          thumbnailUrl: currentCourse.thumbnailUrl,
                          width: double.infinity,
                          height: 112,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(11),
                          ),
                          darkenOpacity: 0.24,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.42),
                                Colors.black.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      currentCourse.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.h3.copyWith(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                  ?trailing,
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                currentCourse.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white.withValues(alpha: 0.96),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Padding(
                                padding: const EdgeInsets.only(right: 70),
                                child: Text(
                                  currentCourse.instructorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 28, 14, 10),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: status == null
                            ? const SizedBox.shrink()
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: AppTextStyles.caption.copyWith(
                                    color: badgeColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: colors.border)),
                    ),
                    child: Row(children: [const Spacer(), ...footer]),
                  ),
                ],
              ),
              Positioned(
                top: 70,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                    backgroundImage: hasAvatar
                        ? NetworkImage(currentCourse.instructorAvatarUrl!)
                        : null,
                    child: hasAvatar
                        ? null
                        : const Icon(
                            Icons.school_outlined,
                            size: 23,
                            color: AppColors.primary,
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
}

/// Uses compact classroom tiles on web and the existing stacked cards on
/// phones, keeping the role-specific card contents supplied by each screen.
class SliverClassroomCourseLayout extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const SliverClassroomCourseLayout({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.12,
          ),
          delegate: SliverChildBuilderDelegate(
            itemBuilder,
            childCount: itemCount,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: itemBuilder(context, index),
          ),
          childCount: itemCount,
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
