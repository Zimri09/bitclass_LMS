import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../models/attendance_models.dart';

class AttendanceRepository {
  static const _sessionsTable = 'attendance_sessions';
  static const _recordsTable = 'attendance_records';
  static const _changesTable = 'attendance_record_changes';

  final SupabaseClient? _supabase;
  final List<AttendanceSession> _demoSessions = [];
  final List<AttendanceRecord> _demoRecords = [];
  final List<AttendanceRecordChange> _demoChanges = [];

  AttendanceRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client);

  Future<DateTime> getServerTime() async {
    if (EnvironmentConfig.isDemoMode) return DateTime.now().toUtc();
    final value = await _supabase!.rpc('attendance_server_now');
    return DateTime.parse(value as String);
  }

  Future<List<AttendanceSession>> getSessions(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      return _demoSessions.where((item) => item.courseId == courseId).toList()
        ..sort((a, b) => b.attendanceDate.compareTo(a.attendanceDate));
    }

    final rows = await _supabase!
        .from(_sessionsTable)
        .select()
        .eq('course_id', courseId)
        .order('attendance_date', ascending: false);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AttendanceSession.fromMap)
        .toList();
  }

  Future<List<AttendanceRecord>> getCourseRecords(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      return _demoRecords.where((item) => item.courseId == courseId).toList();
    }

    final rows = await _supabase!
        .from(_recordsTable)
        .select()
        .eq('course_id', courseId)
        .order('attendance_date', ascending: false);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AttendanceRecord.fromMap)
        .toList();
  }

  Future<void> createSession({
    required String courseId,
    required DateTime attendanceDate,
    required DateTime opensAt,
    required DateTime presentDeadline,
    required DateTime lateDeadline,
    required String creatorId,
    List<String> demoStudentIds = const [],
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      final now = DateTime.now().toUtc();
      final validation = validateAttendanceSessionSchedule(
        attendanceDate: attendanceDate,
        opensAt: opensAt,
        presentDeadline: presentDeadline,
        lateDeadline: lateDeadline,
        serverNow: now,
        existingSessions: _demoSessions
            .where((session) => session.courseId == courseId)
            .toList(),
      );
      if (!validation.isValid) {
        throw Exception(validation.firstError);
      }
      final session = AttendanceSession(
        id: 'attendance-${now.microsecondsSinceEpoch}',
        courseId: courseId,
        attendanceDate: attendanceDate,
        opensAt: opensAt.toUtc(),
        presentDeadline: presentDeadline.toUtc(),
        lateDeadline: lateDeadline.toUtc(),
        createdBy: creatorId,
        createdAt: now,
      );
      _demoSessions.add(session);
      for (final studentId in demoStudentIds) {
        _demoRecords.add(
          AttendanceRecord(
            id: 'record-${session.id}-$studentId',
            courseId: courseId,
            sessionId: session.id,
            studentId: studentId,
            attendanceDate: attendanceDate,
            status: AttendanceStatus.absent,
            createdBy: creatorId,
            lastModifiedBy: creatorId,
            createdAt: now,
          ),
        );
      }
      return;
    }

    final client = _supabase!;
    try {
      await client.rpc(
        'create_attendance_session',
        params: {
          'target_course_id': courseId,
          'target_attendance_date': _dateOnly(attendanceDate),
          'target_opens_at': opensAt.toUtc().toIso8601String(),
          'target_present_deadline': presentDeadline.toUtc().toIso8601String(),
          'target_late_deadline': lateDeadline.toUtc().toIso8601String(),
        },
      );
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<AttendanceCheckInResult> checkIn({
    required String sessionId,
    required String studentId,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      final session = _demoSessions.firstWhere((item) => item.id == sessionId);
      final index = _demoRecords.indexWhere(
        (item) => item.sessionId == sessionId && item.studentId == studentId,
      );
      if (index < 0) throw Exception('Attendance record not found.');
      if (_demoRecords[index].checkInAt != null) {
        throw Exception('You have already checked in for this session.');
      }
      final now = DateTime.now().toUtc();
      if (!session.isCheckInOpenAt(now)) {
        throw Exception(
          session.windowAt(now) == AttendanceWindow.upcoming
              ? 'Attendance is not open yet.'
              : 'Attendance is already closed.',
        );
      }
      final status = now.isAfter(session.presentDeadline)
          ? AttendanceStatus.late
          : AttendanceStatus.present;
      _demoRecords[index] = _demoRecords[index].copyWith(
        checkInAt: now,
        status: status,
        lastModifiedBy: studentId,
        updatedAt: now,
      );
      return AttendanceCheckInResult(
        recordId: _demoRecords[index].id,
        status: status,
        checkedInAt: now,
        serverTime: now,
      );
    }

    final rows = await _supabase!.rpc(
      'check_in_attendance',
      params: {'target_session_id': sessionId},
    );
    final row = (rows as List<dynamic>).cast<Map<String, dynamic>>().single;
    return AttendanceCheckInResult.fromMap(row);
  }

  Future<void> updateRecord({
    required AttendanceRecord record,
    required AttendanceStatus status,
    required String? note,
    required String instructorId,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      final index = _demoRecords.indexWhere((item) => item.id == record.id);
      if (index < 0) throw Exception('Attendance record not found.');
      final now = DateTime.now().toUtc();
      _demoChanges.add(
        AttendanceRecordChange(
          id: 'change-${now.microsecondsSinceEpoch}',
          recordId: record.id,
          previousStatus: record.status,
          updatedStatus: status,
          previousNote: record.note,
          updatedNote: note,
          changeType: 'manual',
          changedBy: instructorId,
          changedAt: now,
        ),
      );
      _demoRecords[index] = record.copyWith(
        status: status,
        note: note,
        clearNote: note == null || note.trim().isEmpty,
        lastModifiedBy: instructorId,
        updatedAt: now,
      );
      return;
    }

    await _supabase!.rpc(
      'update_attendance_record',
      params: {
        'target_record_id': record.id,
        'corrected_status': status.name,
        'correction_note': note,
      },
    );
  }

  Future<List<AttendanceRecordChange>> getRecordChanges(String recordId) async {
    if (EnvironmentConfig.isDemoMode) {
      return _demoChanges.where((item) => item.recordId == recordId).toList()
        ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
    }

    final rows = await _supabase!
        .from(_changesTable)
        .select()
        .eq('record_id', recordId)
        .order('changed_at', ascending: false);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AttendanceRecordChange.fromMap)
        .toList();
  }

  RealtimeChannel? subscribeToCourse({
    required String courseId,
    required VoidCallback onChanged,
  }) {
    if (EnvironmentConfig.isDemoMode) return null;

    return _supabase!
        .channel(
          'attendance-$courseId-${DateTime.now().microsecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _sessionsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'course_id',
            value: courseId,
          ),
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _recordsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'course_id',
            value: courseId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe((status, error) {
          if (error != null && kDebugMode) {
            log('Attendance Realtime error: $error', name: 'Attendance');
          }
        });
  }

  Future<void> removeRealtimeChannel(RealtimeChannel? channel) async {
    if (channel != null && !EnvironmentConfig.isDemoMode) {
      await _supabase!.removeChannel(channel);
    }
  }

  String _dateOnly(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
