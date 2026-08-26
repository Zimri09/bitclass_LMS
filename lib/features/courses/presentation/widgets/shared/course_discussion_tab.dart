part of '../../screens/course_detail_screen.dart';

class _CourseDiscussionTab extends StatelessWidget {
  final String courseId;
  final Widget? courseMenu;

  const _CourseDiscussionTab({required this.courseId, this.courseMenu});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('Course Discussion', style: AppTextStyles.h3),
              ),
              ?courseMenu,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Announcements, questions, and class conversations.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: ChannelListScreen(courseId: courseId, embedded: true)),
      ],
    );
  }
}
