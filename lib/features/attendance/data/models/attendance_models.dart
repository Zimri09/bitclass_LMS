import 'package:equatable/equatable.dart';

enum AttendanceStatus {
  present,
  late,
  absent,
  excused;

  static AttendanceStatus fromValue(String value) {
    return AttendanceStatus.values.firstWhere(
      (status) => status.name == value.toLowerCase(),
      orElse: () => AttendanceStatus.absent,
    );
  }

  String get label => name[0].toUpperCase() + name.substring(1);
}

enum AttendanceWindow { upcoming, present, late, closed }

class AttendanceSessionValidation {
  final String? dateError;
  final String? openingError;
  final String? lateTimeError;
  final String? closingError;

  const AttendanceSessionValidation({
    this.dateError,
    this.openingError,
    this.lateTimeError,
    this.closingError,
  });

  bool get isValid =>
      dateError == null &&
      openingError == null &&
      lateTimeError == null &&
      closingError == null;

  String? get firstError =>
      dateError ?? openingError ?? lateTimeError ?? closingError;
}

AttendanceSessionValidation validateAttendanceSessionSchedule({
  required DateTime? attendanceDate,
  required DateTime? opensAt,
  required DateTime? lateAt,
  required DateTime? closesAt,
  required DateTime serverNow,
  List<AttendanceSession> existingSessions = const [],
}) {
  final localNow = serverNow.toLocal();
  final localDate = attendanceDate?.toLocal();
  final localOpensAt = opensAt?.toLocal();
  final localLateAt = lateAt?.toLocal();
  final localClosesAt = closesAt?.toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);

  String? dateError;
  String? openingError;
  String? lateTimeError;
  String? closingError;

  if (localDate == null) {
    dateError = 'Attendance date is required.';
  } else {
    final selectedDate = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );
    if (selectedDate.isBefore(today)) {
      dateError = 'Attendance date cannot be in the past.';
    } else if (existingSessions.any((session) {
      final existingDate = session.attendanceDate.toLocal();
      return existingDate.year == selectedDate.year &&
          existingDate.month == selectedDate.month &&
          existingDate.day == selectedDate.day;
    })) {
      dateError = 'An attendance session already exists for this date.';
    }
  }

  if (localOpensAt == null) {
    openingError = 'Opening time is required.';
  } else {
    final openingDate = DateTime(
      localOpensAt.year,
      localOpensAt.month,
      localOpensAt.day,
    );
    final selectedDate = localDate == null
        ? null
        : DateTime(localDate.year, localDate.month, localDate.day);
    if (selectedDate != null && openingDate != selectedDate) {
      openingError = 'Opening time must be on the attendance date.';
    } else if (localOpensAt.isBefore(localNow)) {
      openingError = 'Opening time cannot be in the past.';
    }
  }

  if (localLateAt == null) {
    lateTimeError = 'Late time is required.';
  } else if (localOpensAt != null && !localLateAt.isAfter(localOpensAt)) {
    lateTimeError = 'Late time must be after the opening time.';
  }

  if (localClosesAt == null) {
    closingError = 'Closing time is required.';
  } else if (localLateAt != null && !localClosesAt.isAfter(localLateAt)) {
    closingError = 'Closing time must be after the Late time.';
  }

  if (dateError == null &&
      openingError == null &&
      lateTimeError == null &&
      closingError == null) {
    final overlaps = existingSessions.any((session) {
      final existingOpensAt = session.opensAt.toLocal();
      final existingClosesAt = session.closesAt.toLocal();
      return localClosesAt!.isAfter(existingOpensAt) &&
          localOpensAt!.isBefore(existingClosesAt);
    });
    if (overlaps) {
      closingError = 'This attendance window overlaps an existing session.';
    }
  }

  return AttendanceSessionValidation(
    dateError: dateError,
    openingError: openingError,
    lateTimeError: lateTimeError,
    closingError: closingError,
  );
}

class AttendanceSession extends Equatable {
  final String id;
  final String courseId;
  final DateTime attendanceDate;
  final DateTime opensAt;
  final DateTime lateAt;
  final DateTime closesAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AttendanceSession({
    required this.id,
    required this.courseId,
    required this.attendanceDate,
    required this.opensAt,
    required this.lateAt,
    required this.closesAt,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory AttendanceSession.fromMap(Map<String, dynamic> map) {
    return AttendanceSession(
      id: map['id'] as String,
      courseId: map['course_id'] as String,
      attendanceDate: DateTime.parse(map['attendance_date'] as String),
      opensAt: DateTime.parse(map['opens_at'] as String),
      lateAt: DateTime.parse(map['late_at'] as String),
      closesAt: DateTime.parse(map['closes_at'] as String),
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String),
    );
  }

  AttendanceWindow windowAt(DateTime serverTime) {
    if (serverTime.isBefore(opensAt)) return AttendanceWindow.upcoming;
    if (serverTime.isBefore(lateAt)) return AttendanceWindow.present;
    if (serverTime.isBefore(closesAt)) return AttendanceWindow.late;
    return AttendanceWindow.closed;
  }

  bool isCheckInOpenAt(DateTime serverTime) {
    final window = windowAt(serverTime);
    return window == AttendanceWindow.present ||
        window == AttendanceWindow.late;
  }

  @override
  List<Object?> get props => [
    id,
    courseId,
    attendanceDate,
    opensAt,
    lateAt,
    closesAt,
    createdBy,
    createdAt,
    updatedAt,
  ];
}

class AttendanceRecord extends Equatable {
  final String id;
  final String courseId;
  final String sessionId;
  final String studentId;
  final DateTime attendanceDate;
  final DateTime? checkInAt;
  final AttendanceStatus status;
  final String? note;
  final String createdBy;
  final String lastModifiedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AttendanceRecord({
    required this.id,
    required this.courseId,
    required this.sessionId,
    required this.studentId,
    required this.attendanceDate,
    this.checkInAt,
    required this.status,
    this.note,
    required this.createdBy,
    required this.lastModifiedBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as String,
      courseId: map['course_id'] as String,
      sessionId: map['session_id'] as String,
      studentId: map['student_id'] as String,
      attendanceDate: DateTime.parse(map['attendance_date'] as String),
      checkInAt: map['check_in_at'] == null
          ? null
          : DateTime.parse(map['check_in_at'] as String),
      status: AttendanceStatus.fromValue(map['status'] as String? ?? 'absent'),
      note: map['note'] as String?,
      createdBy: map['created_by'] as String,
      lastModifiedBy: map['last_modified_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String),
    );
  }

  AttendanceRecord copyWith({
    DateTime? checkInAt,
    AttendanceStatus? status,
    String? note,
    bool clearNote = false,
    String? lastModifiedBy,
    DateTime? updatedAt,
  }) {
    return AttendanceRecord(
      id: id,
      courseId: courseId,
      sessionId: sessionId,
      studentId: studentId,
      attendanceDate: attendanceDate,
      checkInAt: checkInAt ?? this.checkInAt,
      status: status ?? this.status,
      note: clearNote ? null : (note ?? this.note),
      createdBy: createdBy,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    courseId,
    sessionId,
    studentId,
    attendanceDate,
    checkInAt,
    status,
    note,
    createdBy,
    lastModifiedBy,
    createdAt,
    updatedAt,
  ];
}

class AttendanceRecordChange extends Equatable {
  final String id;
  final String recordId;
  final AttendanceStatus previousStatus;
  final AttendanceStatus updatedStatus;
  final String? previousNote;
  final String? updatedNote;
  final String changeType;
  final String changedBy;
  final DateTime changedAt;

  const AttendanceRecordChange({
    required this.id,
    required this.recordId,
    required this.previousStatus,
    required this.updatedStatus,
    this.previousNote,
    this.updatedNote,
    required this.changeType,
    required this.changedBy,
    required this.changedAt,
  });

  factory AttendanceRecordChange.fromMap(Map<String, dynamic> map) {
    return AttendanceRecordChange(
      id: map['id'] as String,
      recordId: map['record_id'] as String,
      previousStatus: AttendanceStatus.fromValue(
        map['previous_status'] as String,
      ),
      updatedStatus: AttendanceStatus.fromValue(
        map['updated_status'] as String,
      ),
      previousNote: map['previous_note'] as String?,
      updatedNote: map['updated_note'] as String?,
      changeType: map['change_type'] as String,
      changedBy: map['changed_by'] as String,
      changedAt: DateTime.parse(map['changed_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    recordId,
    previousStatus,
    updatedStatus,
    previousNote,
    updatedNote,
    changeType,
    changedBy,
    changedAt,
  ];
}

class AttendanceCheckInResult extends Equatable {
  final String recordId;
  final AttendanceStatus status;
  final DateTime checkedInAt;
  final DateTime serverTime;

  const AttendanceCheckInResult({
    required this.recordId,
    required this.status,
    required this.checkedInAt,
    required this.serverTime,
  });

  factory AttendanceCheckInResult.fromMap(Map<String, dynamic> map) {
    return AttendanceCheckInResult(
      recordId: map['record_id'] as String,
      status: AttendanceStatus.fromValue(map['attendance_status'] as String),
      checkedInAt: DateTime.parse(map['checked_in_at'] as String),
      serverTime: DateTime.parse(map['server_time'] as String),
    );
  }

  @override
  List<Object?> get props => [recordId, status, checkedInAt, serverTime];
}
