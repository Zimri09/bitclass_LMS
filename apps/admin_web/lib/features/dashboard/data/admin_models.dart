class AdminAccount {
  final String id;
  final String email;
  final String displayName;
  final String role;
  final bool isSuspended;
  final String? avatarUrl;
  final DateTime? createdAt;

  const AdminAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.isSuspended = false,
    this.avatarUrl,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin' && !isSuspended;

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
      isSuspended: map['is_suspended'] as bool? ?? false,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    );
  }
}

class AdminAuditLog {
  final String id;
  final String actorEmail;
  final String action;
  final String targetType;
  final String? targetId;
  final String? reason;
  final Map<String, dynamic> previousValues;
  final Map<String, dynamic> newValues;
  final DateTime? createdAt;

  const AdminAuditLog({
    required this.id,
    required this.actorEmail,
    required this.action,
    required this.targetType,
    required this.previousValues,
    required this.newValues,
    this.targetId,
    this.reason,
    this.createdAt,
  });

  String get actionLabel => action
      .split('.')
      .expand((part) => part.split('_'))
      .map(
        (part) => part.isEmpty
            ? part
            : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  factory AdminAuditLog.fromMap(Map<String, dynamic> map) {
    return AdminAuditLog(
      id: map['id'] as String,
      actorEmail: map['actor_email'] as String? ?? 'Unknown administrator',
      action: map['action'] as String? ?? 'unknown',
      targetType: map['target_type'] as String? ?? 'unknown',
      targetId: map['target_id'] as String?,
      reason: map['reason'] as String?,
      previousValues: Map<String, dynamic>.from(
        map['previous_values'] as Map? ?? const {},
      ),
      newValues: Map<String, dynamic>.from(
        map['new_values'] as Map? ?? const {},
      ),
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
