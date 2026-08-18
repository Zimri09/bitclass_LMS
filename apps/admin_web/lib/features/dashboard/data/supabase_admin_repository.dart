import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_models.dart';
import 'admin_repository.dart';

class SupabaseAdminRepository implements AdminRepository {
  final SupabaseClient _client;

  const SupabaseAdminRepository(this._client);

  static const _profileColumns =
      'id,email,display_name,first_name,last_name,avatar_url,role,created_at';
  static const _courseColumns =
      'id,title,category,instructor_name,enrollment_count,lesson_count,'
      'is_published,created_at';

  @override
  Future<AdminAccount?> findAccount(String userId) async {
    final row = await _client
        .from('profiles')
        .select(_profileColumns)
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : AdminAccount.fromMap(row);
  }

  @override
  Future<AdminDashboardSnapshot> fetchOverview() async {
    final counts = await Future.wait<int>([
      _client.from('profiles').count(),
      _client.from('courses').count(),
      _client.from('enrollments').count(),
      _client.from('submissions').count(),
    ]);
    final recentData = await Future.wait<Object>([
      fetchUsers(limit: 5),
      fetchCourses(limit: 5),
    ]);

    return AdminDashboardSnapshot(
      userCount: counts[0],
      courseCount: counts[1],
      enrollmentCount: counts[2],
      submissionCount: counts[3],
      recentUsers: recentData[0] as List<AdminAccount>,
      recentCourses: recentData[1] as List<AdminCourse>,
    );
  }

  @override
  Future<List<AdminAccount>> fetchUsers({int limit = 100}) async {
    final rows = await _client
        .from('profiles')
        .select(_profileColumns)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(AdminAccount.fromMap).toList(growable: false);
  }

  @override
  Future<List<AdminCourse>> fetchCourses({int limit = 100}) async {
    final rows = await _client
        .from('courses')
        .select(_courseColumns)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(AdminCourse.fromMap).toList(growable: false);
  }
}
