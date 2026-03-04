import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// A loading indicator with the BitClass branding
class BitClassLoader extends StatelessWidget {
  final String? message;
  final double size;

  const BitClassLoader({super.key, this.message, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A simple shimmer loading placeholder
class ShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(
      begin: -1,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _animation.value, 0),
              end: Alignment(_animation.value, 0),
              colors: const [
                AppColors.surface,
                AppColors.surfaceLight,
                AppColors.surface,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton loader for a course card
class CourseCardSkeleton extends StatelessWidget {
  const CourseCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ShimmerPlaceholder(
            width: double.infinity,
            height: 120,
            borderRadius: 12,
          ),
          SizedBox(height: 16),
          // Title
          ShimmerPlaceholder(width: 200, height: 20, borderRadius: 4),
          SizedBox(height: 8),
          // Subtitle
          ShimmerPlaceholder(width: 150, height: 14, borderRadius: 4),
          SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              ShimmerPlaceholder(width: 60, height: 12, borderRadius: 4),
              SizedBox(width: 16),
              ShimmerPlaceholder(width: 60, height: 12, borderRadius: 4),
              SizedBox(width: 16),
              ShimmerPlaceholder(width: 60, height: 12, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for a list of course cards
class CourseListSkeleton extends StatelessWidget {
  final int count;

  const CourseListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (context, index) => const CourseCardSkeleton(),
    );
  }
}

/// Skeleton loader for a notification item
class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          ShimmerPlaceholder(width: 44, height: 44, borderRadius: 12),
          SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerPlaceholder(width: 180, height: 16, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerPlaceholder(
                  width: double.infinity,
                  height: 14,
                  borderRadius: 4,
                ),
                SizedBox(height: 6),
                ShimmerPlaceholder(width: 80, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for notification list
class NotificationListSkeleton extends StatelessWidget {
  final int count;

  const NotificationListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: count,
      itemBuilder: (context, index) => const NotificationSkeleton(),
    );
  }
}

/// Skeleton loader for a file item
class FileSkeleton extends StatelessWidget {
  const FileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          // File icon
          ShimmerPlaceholder(width: 48, height: 48, borderRadius: 12),
          SizedBox(width: 12),
          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerPlaceholder(width: 160, height: 16, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerPlaceholder(width: 120, height: 12, borderRadius: 4),
                SizedBox(height: 6),
                Row(
                  children: [
                    ShimmerPlaceholder(width: 50, height: 10, borderRadius: 4),
                    SizedBox(width: 12),
                    ShimmerPlaceholder(width: 40, height: 10, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
          // More button
          ShimmerPlaceholder(width: 24, height: 24, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Skeleton loader for file list
class FileListSkeleton extends StatelessWidget {
  final int count;

  const FileListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (context, index) => const FileSkeleton(),
    );
  }
}

/// Skeleton loader for a discussion thread item
class ThreadSkeleton extends StatelessWidget {
  const ThreadSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with avatar and name
          Row(
            children: [
              ShimmerPlaceholder(width: 32, height: 32, borderRadius: 16),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerPlaceholder(width: 100, height: 14, borderRadius: 4),
                  SizedBox(height: 4),
                  ShimmerPlaceholder(width: 60, height: 10, borderRadius: 4),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          // Title
          ShimmerPlaceholder(
            width: double.infinity,
            height: 18,
            borderRadius: 4,
          ),
          SizedBox(height: 8),
          // Content preview
          ShimmerPlaceholder(
            width: double.infinity,
            height: 14,
            borderRadius: 4,
          ),
          SizedBox(height: 4),
          ShimmerPlaceholder(width: 200, height: 14, borderRadius: 4),
          SizedBox(height: 12),
          // Footer stats
          Row(
            children: [
              ShimmerPlaceholder(width: 40, height: 12, borderRadius: 4),
              SizedBox(width: 16),
              ShimmerPlaceholder(width: 40, height: 12, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for thread list
class ThreadListSkeleton extends StatelessWidget {
  final int count;

  const ThreadListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (context, index) => const ThreadSkeleton(),
    );
  }
}

/// Skeleton loader for a lesson item
class LessonSkeleton extends StatelessWidget {
  const LessonSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          // Order number
          ShimmerPlaceholder(width: 32, height: 32, borderRadius: 8),
          SizedBox(width: 16),
          // Lesson info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerPlaceholder(width: 180, height: 16, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerPlaceholder(width: 100, height: 12, borderRadius: 4),
              ],
            ),
          ),
          // Duration/status
          ShimmerPlaceholder(width: 60, height: 24, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Skeleton loader for profile page
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          const ShimmerPlaceholder(width: 100, height: 100, borderRadius: 50),
          const SizedBox(height: 16),
          // Name
          const ShimmerPlaceholder(width: 150, height: 24, borderRadius: 4),
          const SizedBox(height: 8),
          // Email
          const ShimmerPlaceholder(width: 200, height: 16, borderRadius: 4),
          const SizedBox(height: 24),
          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatSkeleton(),
              const SizedBox(width: 32),
              _buildStatSkeleton(),
              const SizedBox(width: 32),
              _buildStatSkeleton(),
            ],
          ),
          const SizedBox(height: 32),
          // Bio section
          const ShimmerPlaceholder(
            width: double.infinity,
            height: 80,
            borderRadius: 12,
          ),
          const SizedBox(height: 24),
          // Settings items
          for (int i = 0; i < 4; i++) ...[
            const ShimmerPlaceholder(
              width: double.infinity,
              height: 56,
              borderRadius: 12,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildStatSkeleton() {
    return const Column(
      children: [
        ShimmerPlaceholder(width: 40, height: 24, borderRadius: 4),
        SizedBox(height: 4),
        ShimmerPlaceholder(width: 60, height: 14, borderRadius: 4),
      ],
    );
  }
}

/// Empty state widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// Error state widget
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for a compact course card (grid layout)
class CourseCardCompactSkeleton extends StatelessWidget {
  const CourseCardCompactSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            child: ShimmerPlaceholder(
              width: double.infinity,
              height: 100,
              borderRadius: 0,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerPlaceholder(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 4,
                ),
                SizedBox(height: 6),
                ShimmerPlaceholder(width: 100, height: 12, borderRadius: 4),
                SizedBox(height: 10),
                Row(
                  children: [
                    ShimmerPlaceholder(width: 50, height: 10, borderRadius: 4),
                    Spacer(),
                    ShimmerPlaceholder(width: 50, height: 10, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sliver grid skeleton for course catalog
class SliverCourseGridSkeleton extends StatelessWidget {
  final int count;

  const SliverCourseGridSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const CourseCardCompactSkeleton(),
          childCount: count,
        ),
      ),
    );
  }
}
