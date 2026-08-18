class AdminAccount {
  final String id;
  final String email;
  final String displayName;
  final String role;
  final String? avatarUrl;
  final DateTime? createdAt;

  const AdminAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory AdminAccount.fromMap(Map<String, dynamic> map) {
    final firstName = (map['first_name'] as String? ?? '').trim();
    final lastName = (map['last_name'] as String? ?? '').trim();
    final fullName = '$firstName $lastName'.trim();
    final displayName = (map['display_name'] as String? ?? '').trim();

    return AdminAccount(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      displayName: fullName.isNotEmpty
          ? fullName
          : displayName.isNotEmpty
          ? displayName
          : map['email'] as String? ?? 'Unknown user',
      role: map['role'] as String? ?? 'student',
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    );
  }
}

class AdminCourse {
  final String id;
  final String title;
  final String instructorName;
  final String? category;
  final int enrollmentCount;
  final int lessonCount;
  final bool isPublished;
  final DateTime? createdAt;

  const AdminCourse({
    required this.id,
    required this.title,
    required this.instructorName,
    required this.enrollmentCount,
    required this.lessonCount,
    required this.isPublished,
    this.category,
    this.createdAt,
  });

  factory AdminCourse.fromMap(Map<String, dynamic> map) {
    return AdminCourse(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled course',
      instructorName: map['instructor_name'] as String? ?? 'Unknown instructor',
      category: map['category'] as String?,
      enrollmentCount: (map['enrollment_count'] as num?)?.toInt() ?? 0,
      lessonCount: (map['lesson_count'] as num?)?.toInt() ?? 0,
      isPublished: map['is_published'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    );
  }
}

class AdminDashboardSnapshot {
  final int userCount;
  final int courseCount;
  final int enrollmentCount;
  final int submissionCount;
  final List<AdminAccount> recentUsers;
  final List<AdminCourse> recentCourses;

  const AdminDashboardSnapshot({
    required this.userCount,
    required this.courseCount,
    required this.enrollmentCount,
    required this.submissionCount,
    required this.recentUsers,
    required this.recentCourses,
  });
}
