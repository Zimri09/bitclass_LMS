import 'package:bitclass_admin/core/theme/admin_theme.dart';
import 'package:bitclass_admin/features/courses/presentation/admin_courses_screen.dart';
import 'package:bitclass_admin/features/dashboard/data/admin_models.dart';
import 'package:bitclass_admin/features/dashboard/data/admin_repository.dart';
import 'package:bitclass_admin/features/users/presentation/admin_users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('user directory searches and filters loaded accounts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.dark,
        home: AdminUsersScreen(repository: _DirectoryRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ada Student'), findsOneWidget);
    expect(find.text('Grace Instructor'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Grace');
    await tester.pump();

    expect(find.text('Grace Instructor'), findsOneWidget);
    expect(find.text('Ada Student'), findsNothing);
  });

  testWidgets(
    'course directory uses a single-column layout on narrow screens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: AdminCoursesScreen(repository: _DirectoryRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Algorithms'), findsOneWidget);
      expect(find.text('Published'), findsWidgets);
      expect(find.text('12 students'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _DirectoryRepository implements AdminRepository {
  static const users = [
    AdminAccount(
      id: 'student-1',
      email: 'ada@example.com',
      displayName: 'Ada Student',
      role: 'student',
    ),
    AdminAccount(
      id: 'instructor-1',
      email: 'grace@example.com',
      displayName: 'Grace Instructor',
      role: 'instructor',
    ),
  ];

  static const courses = [
    AdminCourse(
      id: 'course-1',
      title: 'Algorithms',
      instructorName: 'Grace Instructor',
      enrollmentCount: 12,
      lessonCount: 8,
      isPublished: true,
      category: 'Computer Science',
    ),
  ];

  @override
  Future<List<AdminCourse>> fetchCourses({int limit = 100}) async => courses;

  @override
  Future<List<AdminAuditLog>> fetchAuditLogs({int limit = 100}) async =>
      const [];

  @override
  Future<AdminDashboardSnapshot> fetchOverview() async {
    return const AdminDashboardSnapshot(
      userCount: 2,
      courseCount: 1,
      enrollmentCount: 12,
      submissionCount: 4,
      recentUsers: users,
      recentCourses: courses,
    );
  }

  @override
  Future<List<AdminAccount>> fetchUsers({int limit = 100}) async => users;

  @override
  Future<AdminAccount?> findAccount(String userId) async => users.first;

  @override
  Future<AdminAccount> setUserRole({
    required String userId,
    required String role,
    String? reason,
  }) async => users.firstWhere((user) => user.id == userId);

  @override
  Future<AdminAccount> setUserSuspension({
    required String userId,
    required bool suspended,
    String? reason,
  }) async => users.firstWhere((user) => user.id == userId);
}
