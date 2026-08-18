import 'dart:async';

import 'package:bitclass_admin/core/auth/admin_auth_service.dart';
import 'package:bitclass_admin/core/auth/admin_session_controller.dart';
import 'package:bitclass_admin/features/dashboard/data/admin_models.dart';
import 'package:bitclass_admin/features/dashboard/data/admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminSessionController', () {
    test('starts signed out when there is no Supabase user', () async {
      final auth = _FakeAuthService();
      final controller = AdminSessionController(auth, _FakeRepository());

      await controller.initialize();

      expect(controller.status, AdminSessionStatus.signedOut);
      expect(controller.account, isNull);
      controller.dispose();
      await auth.close();
    });

    test('rejects an authenticated non-admin account', () async {
      final auth = _FakeAuthService(userId: 'student-1');
      final repository = _FakeRepository(
        account: const AdminAccount(
          id: 'student-1',
          email: 'student@example.com',
          displayName: 'Student User',
          role: 'student',
        ),
      );
      final controller = AdminSessionController(auth, repository);

      await controller.initialize();

      expect(controller.status, AdminSessionStatus.forbidden);
      expect(controller.account?.role, 'student');
      expect(controller.message, contains('administrators only'));
      controller.dispose();
      await auth.close();
    });

    test('authorizes a database-backed admin account', () async {
      final auth = _FakeAuthService(userId: 'admin-1');
      final repository = _FakeRepository(
        account: const AdminAccount(
          id: 'admin-1',
          email: 'admin@example.com',
          displayName: 'Admin User',
          role: 'admin',
        ),
      );
      final controller = AdminSessionController(auth, repository);

      await controller.initialize();

      expect(controller.status, AdminSessionStatus.authorized);
      expect(controller.account?.isAdmin, isTrue);
      controller.dispose();
      await auth.close();
    });
  });
}

class _FakeAuthService implements AdminAuthService {
  final StreamController<String?> _changes =
      StreamController<String?>.broadcast(sync: true);
  String? _userId;

  _FakeAuthService({String? userId}) {
    _userId = userId;
  }

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> get userChanges => _changes.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _userId = 'admin-1';
    _changes.add(_userId);
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _changes.add(null);
  }

  Future<void> close() => _changes.close();
}

class _FakeRepository implements AdminRepository {
  final AdminAccount? account;

  const _FakeRepository({this.account});

  @override
  Future<AdminAccount?> findAccount(String userId) async => account;

  @override
  Future<List<AdminCourse>> fetchCourses({int limit = 100}) async => const [];

  @override
  Future<List<AdminAuditLog>> fetchAuditLogs({int limit = 100}) async =>
      const [];

  @override
  Future<AdminDashboardSnapshot> fetchOverview() async {
    return const AdminDashboardSnapshot(
      userCount: 0,
      courseCount: 0,
      enrollmentCount: 0,
      submissionCount: 0,
      recentUsers: [],
      recentCourses: [],
    );
  }

  @override
  Future<List<AdminAccount>> fetchUsers({int limit = 100}) async => const [];

  @override
  Future<AdminAccount> setUserRole({
    required String userId,
    required String role,
    String? reason,
  }) async => account!;

  @override
  Future<AdminAccount> setUserSuspension({
    required String userId,
    required bool suspended,
    String? reason,
  }) async => account!;
}
