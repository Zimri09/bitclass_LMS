import 'admin_models.dart';
import '../../support/data/admin_support_request.dart';

abstract interface class AdminRepository {
  Future<AdminAccount?> findAccount(String userId);

  Future<AdminDashboardSnapshot> fetchOverview();

  Future<List<AdminAccount>> fetchUsers({int limit = 100});

  Future<List<AdminCourse>> fetchCourses({int limit = 100});

  Future<AdminAccount> setUserRole({
    required String userId,
    required String role,
    String? reason,
  });

  Future<AdminAccount> setUserSuspension({
    required String userId,
    required bool suspended,
    String? reason,
  });

  Future<List<AdminAuditLog>> fetchAuditLogs({int limit = 100});

  Future<List<AdminSupportRequest>> fetchSupportRequests({int limit = 200});

  Future<bool> hasOpenSupportRequests();

  Future<void> updateSupportRequestStatus({
    required String requestId,
    required AdminSupportRequestStatus status,
  });
}
