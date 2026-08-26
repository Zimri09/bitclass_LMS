import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_models.dart';
import 'admin_repository.dart';
import '../../support/data/admin_support_request.dart';

class SupabaseAdminRepository implements AdminRepository {
  final SupabaseClient _client;

  const SupabaseAdminRepository(this._client);

  static const _profileColumns =
      'id,email,display_name,first_name,last_name,avatar_url,role,'
      'is_suspended,created_at';
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

  @override
  Future<AdminAccount> setUserRole({
    required String userId,
    required String role,
    String? reason,
  }) {
    return _manageUser({
      'action': 'set_role',
      'user_id': userId,
      'role': role,
      if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim(),
    });
  }

  @override
  Future<AdminAccount> setUserSuspension({
    required String userId,
    required bool suspended,
    String? reason,
  }) {
    return _manageUser({
      'action': 'set_suspension',
      'user_id': userId,
      'suspended': suspended,
      if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim(),
    });
  }

  Future<AdminAccount> _manageUser(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke(
      'admin-manage-user',
      body: body,
    );
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Invalid admin action response');
    }
    final payload = Map<String, dynamic>.from(data);
    if (response.status < 200 || response.status >= 300) {
      throw StateError(payload['error'] as String? ?? 'Admin action failed');
    }
    final user = payload['user'];
    if (user is! Map) {
      throw const FormatException('Admin action returned no user');
    }
    return AdminAccount.fromMap(Map<String, dynamic>.from(user));
  }

  @override
  Future<List<AdminAuditLog>> fetchAuditLogs({int limit = 100}) async {
    final rows = await _client
        .from('admin_audit_logs')
        .select(
          'id,actor_email,action,target_type,target_id,reason,'
          'previous_values,new_values,created_at',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(AdminAuditLog.fromMap).toList(growable: false);
  }

  @override
  Future<List<AdminSupportRequest>> fetchSupportRequests({
    int limit = 200,
  }) async {
    final rows = await _client
        .from('support_requests')
        .select(
          'id,user_id,request_type,category,subject,description,metadata,'
          'status,created_at,profile:profiles!support_requests_user_id_fkey('
          'email,first_name,last_name,role)',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(AdminSupportRequest.fromMap).toList(growable: false);
  }

  @override
  Future<bool> hasOpenSupportRequests() async {
    final rows = await _client
        .from('support_requests')
        .select('id')
        .eq('status', AdminSupportRequestStatus.open.databaseValue)
        .limit(1);
    return rows.isNotEmpty;
  }

  @override
  Future<void> updateSupportRequestStatus({
    required String requestId,
    required AdminSupportRequestStatus status,
  }) async {
    await _client
        .from('support_requests')
        .update({'status': status.databaseValue})
        .eq('id', requestId);
  }
}
