import 'admin_models.dart';

abstract interface class AdminRepository {
  Future<AdminAccount?> findAccount(String userId);

  Future<AdminDashboardSnapshot> fetchOverview();

  Future<List<AdminAccount>> fetchUsers({int limit = 100});

  Future<List<AdminCourse>> fetchCourses({int limit = 100});
}
