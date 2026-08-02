import 'package:bitclass/features/attendance/data/models/attendance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceSession', () {
    final session = AttendanceSession(
      id: 'session-1',
      courseId: 'course-1',
      attendanceDate: DateTime.utc(2026, 8, 3),
      opensAt: DateTime.utc(2026, 8, 3, 1),
      presentDeadline: DateTime.utc(2026, 8, 3, 1, 15),
      lateDeadline: DateTime.utc(2026, 8, 3, 1, 30),
      closesAt: DateTime.utc(2026, 8, 3, 1, 45),
      createdBy: 'instructor-1',
      createdAt: DateTime.utc(2026, 8, 2),
    );

    test('calculates attendance windows from supplied server time', () {
      expect(
        session.windowAt(DateTime.utc(2026, 8, 3, 0, 59)),
        AttendanceWindow.upcoming,
      );
      expect(
        session.windowAt(DateTime.utc(2026, 8, 3, 1, 15)),
        AttendanceWindow.present,
      );
      expect(
        session.windowAt(DateTime.utc(2026, 8, 3, 1, 16)),
        AttendanceWindow.late,
      );
      expect(
        session.windowAt(DateTime.utc(2026, 8, 3, 1, 31)),
        AttendanceWindow.checkInEnded,
      );
      expect(
        session.windowAt(DateTime.utc(2026, 8, 3, 1, 45)),
        AttendanceWindow.closed,
      );
    });

    test('allows check-in only during present and late windows', () {
      expect(session.isCheckInOpenAt(DateTime.utc(2026, 8, 3, 1, 10)), isTrue);
      expect(session.isCheckInOpenAt(DateTime.utc(2026, 8, 3, 1, 20)), isTrue);
      expect(session.isCheckInOpenAt(DateTime.utc(2026, 8, 3, 1, 31)), isFalse);
      expect(session.isCheckInOpenAt(DateTime.utc(2026, 8, 3, 1, 46)), isFalse);
    });
  });

  test('AttendanceRecord parses server timestamps and status', () {
    final record = AttendanceRecord.fromMap({
      'id': 'record-1',
      'course_id': 'course-1',
      'session_id': 'session-1',
      'student_id': 'student-1',
      'attendance_date': '2026-08-03',
      'check_in_at': '2026-08-03T01:18:00Z',
      'status': 'late',
      'note': null,
      'created_by': 'instructor-1',
      'last_modified_by': 'student-1',
      'created_at': '2026-08-03T01:00:00Z',
      'updated_at': '2026-08-03T01:18:00Z',
    });

    expect(record.status, AttendanceStatus.late);
    expect(record.checkInAt, DateTime.utc(2026, 8, 3, 1, 18));
    expect(record.studentId, 'student-1');
  });

  test('unknown database statuses safely fall back to absent', () {
    expect(AttendanceStatus.fromValue('unexpected'), AttendanceStatus.absent);
  });

  group('attendance session schedule validation', () {
    final serverNow = DateTime(2026, 8, 2, 23, 40);

    AttendanceSessionValidation validate({
      DateTime? date,
      DateTime? opensAt,
      DateTime? presentDeadline,
      DateTime? lateDeadline,
      DateTime? closesAt,
      List<AttendanceSession> existingSessions = const [],
    }) {
      return validateAttendanceSessionSchedule(
        attendanceDate: date ?? DateTime(2026, 8, 2),
        opensAt: opensAt ?? DateTime(2026, 8, 2, 23, 41),
        presentDeadline: presentDeadline ?? DateTime(2026, 8, 2, 23, 56),
        lateDeadline: lateDeadline ?? DateTime(2026, 8, 3, 0, 11),
        closesAt: closesAt ?? DateTime(2026, 8, 3, 0, 26),
        serverNow: serverNow,
        existingSessions: existingSessions,
      );
    }

    test('accepts an ordered session that crosses midnight', () {
      expect(validate().isValid, isTrue);
    });

    test('rejects a past date and opening time with field errors', () {
      final result = validate(
        date: DateTime(2026, 8, 1),
        opensAt: DateTime(2026, 8, 1, 23, 41),
        presentDeadline: DateTime(2026, 8, 1, 23, 56),
        lateDeadline: DateTime(2026, 8, 2, 0, 11),
        closesAt: DateTime(2026, 8, 2, 0, 26),
      );

      expect(result.dateError, 'Attendance date cannot be in the past.');
      expect(result.openingError, 'Opening time cannot be in the past.');
    });

    test('requires strict present and late deadline ordering', () {
      final invalidPresent = validate(
        presentDeadline: DateTime(2026, 8, 2, 23, 41),
      );
      final invalidLate = validate(lateDeadline: DateTime(2026, 8, 2, 23, 56));
      final invalidClose = validate(closesAt: DateTime(2026, 8, 3, 0, 11));

      expect(
        invalidPresent.presentDeadlineError,
        'Present deadline must be after the opening time.',
      );
      expect(
        invalidLate.lateDeadlineError,
        'Late deadline must be after the Present deadline.',
      );
      expect(
        invalidClose.closingError,
        'Closing time must be after the Late deadline.',
      );
    });

    test('rejects duplicate dates and overlapping windows', () {
      final existing = AttendanceSession(
        id: 'existing',
        courseId: 'course-1',
        attendanceDate: DateTime(2026, 8, 3),
        opensAt: DateTime(2026, 8, 3, 9),
        presentDeadline: DateTime(2026, 8, 3, 9, 15),
        lateDeadline: DateTime(2026, 8, 3, 9, 30),
        closesAt: DateTime(2026, 8, 3, 9, 45),
        createdBy: 'instructor-1',
        createdAt: serverNow,
      );
      final duplicate = validateAttendanceSessionSchedule(
        attendanceDate: DateTime(2026, 8, 3),
        opensAt: DateTime(2026, 8, 3, 10),
        presentDeadline: DateTime(2026, 8, 3, 10, 15),
        lateDeadline: DateTime(2026, 8, 3, 10, 30),
        closesAt: DateTime(2026, 8, 3, 10, 45),
        serverNow: serverNow,
        existingSessions: [existing],
      );
      final overlapping = validate(
        date: DateTime(2026, 8, 2),
        opensAt: DateTime(2026, 8, 2, 23, 50),
        presentDeadline: DateTime(2026, 8, 3, 0, 5),
        lateDeadline: DateTime(2026, 8, 3, 0, 20),
        closesAt: DateTime(2026, 8, 3, 0, 35),
        existingSessions: [
          AttendanceSession(
            id: 'overnight',
            courseId: 'course-1',
            attendanceDate: DateTime(2026, 8, 1),
            opensAt: DateTime(2026, 8, 3, 0, 10),
            presentDeadline: DateTime(2026, 8, 3, 0, 20),
            lateDeadline: DateTime(2026, 8, 3, 0, 30),
            closesAt: DateTime(2026, 8, 3, 0, 45),
            createdBy: 'instructor-1',
            createdAt: serverNow,
          ),
        ],
      );

      expect(
        duplicate.dateError,
        'An attendance session already exists for this date.',
      );
      expect(
        overlapping.closingError,
        'This attendance window overlaps an existing session.',
      );
    });
  });
}
