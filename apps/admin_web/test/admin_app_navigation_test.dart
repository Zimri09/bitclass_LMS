import 'dart:async';

import 'package:bitclass_admin/app.dart';
import 'package:bitclass_admin/core/auth/admin_auth_service.dart';
import 'package:bitclass_admin/core/auth/admin_session_controller.dart';
import 'package:bitclass_admin/features/dashboard/data/admin_models.dart';
import 'package:bitclass_admin/features/dashboard/data/admin_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('authorized admin can navigate the responsive dashboard shell', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final auth = _AdminAuthService();
    final repository = _AdminRepository();
    final session = AdminSessionController(auth, repository);
    await session.initialize();

    await tester.pumpWidget(AdminApp(session: session, repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Total users'), findsOneWidget);
    expect(find.text('Administrator session'), findsOneWidget);

    await tester.tap(find.text('Users'));
    await tester.pumpAndSettle();

    expect(
      find.text('Review registered students, instructors, and administrators.'),
      findsOneWidget,
    );
    expect(find.text('Admin User'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await auth.close();
  });
}

class _AdminAuthService implements AdminAuthService {
  final _changes = StreamController<String?>.broadcast(sync: true);

  @override
  String? get currentUserId => 'admin-1';

  @override
  Stream<String?> get userChanges => _changes.stream;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async => _changes.add(null);

  Future<void> close() => _changes.close();
}

class _AdminRepository implements AdminRepository {
  static const admin = AdminAccount(
    id: 'admin-1',
    email: 'admin@example.com',
    displayName: 'Admin User',
    role: 'admin',
  );

  static const course = AdminCourse(
    id: 'course-1',
    title: 'Algorithms',
    instructorName: 'Grace Instructor',
    enrollmentCount: 12,
    lessonCount: 8,
    isPublished: true,
  );

  @override
  Future<List<AdminCourse>> fetchCourses({int limit = 100}) async => [course];

  @override
  Future<AdminDashboardSnapshot> fetchOverview() async {
    return const AdminDashboardSnapshot(
      userCount: 1,
      courseCount: 1,
      enrollmentCount: 12,
      submissionCount: 4,
      recentUsers: [admin],
      recentCourses: [course],
    );
  }

  @override
  Future<List<AdminAccount>> fetchUsers({int limit = 100}) async => [admin];

  @override
  Future<AdminAccount?> findAccount(String userId) async => admin;
}
