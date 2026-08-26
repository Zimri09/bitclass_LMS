part of '../../screens/course_detail_screen.dart';

class _CoursePeopleTab extends StatefulWidget {
  final CourseModel course;
  final Widget? courseMenu;

  const _CoursePeopleTab({required this.course, this.courseMenu});

  @override
  State<_CoursePeopleTab> createState() => _CoursePeopleTabState();
}

class _CoursePeopleTabState extends State<_CoursePeopleTab> {
  late Future<List<CourseRosterMember>> _students;

  @override
  void initState() {
    super.initState();
    _students = _loadStudents();
  }

  Future<List<CourseRosterMember>> _loadStudents() {
    return context.read<CourseRepository>().getCourseRoster(widget.course.id);
  }

  Future<void> _refresh() async {
    setState(() => _students = _loadStudents());
    await _students;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CourseRosterMember>>(
      future: _students,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ErrorState(
            message: 'Unable to load the class roster.',
            onRetry: _refresh,
          );
        }

        final students = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(child: Text('People', style: AppTextStyles.h3)),
                  ?widget.courseMenu,
                ],
              ),
              const SizedBox(height: 20),
              Text('INSTRUCTOR', style: _sectionStyle(context)),
              const SizedBox(height: 8),
              _PersonTile(
                name: widget.course.instructorName,
                avatarUrl: widget.course.instructorAvatarUrl,
                role: 'Instructor',
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text('STUDENTS', style: _sectionStyle(context)),
                  const Spacer(),
                  Text(
                    '${students.length}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (students.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No students have joined yet.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...students.map(
                  (student) => _PersonTile(
                    name: student.displayName,
                    avatarUrl: student.avatarUrl,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  TextStyle _sectionStyle(BuildContext context) {
    return AppTextStyles.caption.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );
  }
}

class _PersonTile extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? role;

  const _PersonTile({required this.name, this.avatarUrl, this.role});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundImage: avatarUrl?.isNotEmpty == true
            ? NetworkImage(avatarUrl!)
            : null,
        child: avatarUrl?.isNotEmpty == true ? null : Text(initials),
      ),
      title: Text(name, style: AppTextStyles.bodyLarge),
      subtitle: role == null
          ? null
          : Text(
              role!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
    );
  }
}
