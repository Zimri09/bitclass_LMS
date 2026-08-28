import 'package:bitclass/features/assignments/data/models/assignment_model.dart';
import 'package:bitclass/features/assignments/data/models/submission_model.dart';
import 'package:bitclass/features/attendance/data/models/attendance_models.dart';
import 'package:bitclass/features/class_records/data/services/class_record_calculator.dart';
import 'package:bitclass/features/courses/data/models/course_model.dart';
import 'package:bitclass/features/quizzes/data/models/quiz_attempt_model.dart';
import 'package:bitclass/features/quizzes/data/models/quiz_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 8);

  test('uses best quiz attempt and computes the weighted overall grade', () {
    final result = ClassRecordCalculator.calculate(
      enrollments: [_enrollment(now)],
      roster: const [
        CourseRosterMember(userId: 'student-1', displayName: 'Ada Lovelace'),
      ],
      quizzes: [_quiz(now)],
      quizAttempts: [
        _attempt(now, id: 'attempt-1', score: 5, percentage: 50),
        _attempt(now, id: 'attempt-2', score: 8, percentage: 80),
      ],
      assignments: [_assignment(now)],
      submissions: [_submission(now, score: 10)],
      attendanceSessions: [
        _session(now, id: 'session-1'),
        _session(now.add(const Duration(days: 1)), id: 'session-2'),
      ],
      attendanceRecords: [
        _attendance(now, AttendanceStatus.present, sessionId: 'session-1'),
        _attendance(
          now.add(const Duration(days: 1)),
          AttendanceStatus.late,
          sessionId: 'session-2',
        ),
      ],
    );

    final student = result.students.single;
    expect(student.displayName, 'Ada Lovelace');
    expect(student.quizGrade, 80);
    expect(student.assignmentGrade, 50);
    expect(student.attendanceGrade, 87.5);
    expect(student.overallGrade, closeTo(69.5, 0.001));
    expect(result.classAverage, closeTo(69.5, 0.001));
  });

  test('excludes excused attendance and reweights unavailable categories', () {
    final result = ClassRecordCalculator.calculate(
      enrollments: [_enrollment(now)],
      roster: const [],
      quizzes: [_quiz(now)],
      quizAttempts: [_attempt(now, id: 'attempt-1', score: 8, percentage: 80)],
      assignments: const [],
      submissions: const [],
      attendanceSessions: [
        _session(now, id: 'session-1'),
        _session(now.add(const Duration(days: 1)), id: 'session-2'),
      ],
      attendanceRecords: [
        _attendance(now, AttendanceStatus.excused, sessionId: 'session-1'),
        _attendance(
          now.add(const Duration(days: 1)),
          AttendanceStatus.present,
          sessionId: 'session-2',
        ),
      ],
    );

    final student = result.students.single;
    expect(student.displayName, 'Fallback Name');
    expect(student.assignmentGrade, isNull);
    expect(student.attendanceGrade, 100);
    expect(student.overallGrade, closeTo(86.6667, 0.001));
  });

  test('counts missing work as zero when assessments are available', () {
    final result = ClassRecordCalculator.calculate(
      enrollments: [_enrollment(now)],
      roster: const [],
      quizzes: [_quiz(now)],
      quizAttempts: const [],
      assignments: [_assignment(now)],
      submissions: const [],
      attendanceSessions: const [],
      attendanceRecords: const [],
    );

    final student = result.students.single;
    expect(student.quizGrade, 0);
    expect(student.assignmentGrade, 0);
    expect(student.attendanceGrade, isNull);
    expect(student.overallGrade, 0);
  });
}

EnrollmentModel _enrollment(DateTime now) {
  return EnrollmentModel(
    id: 'enrollment-1',
    courseId: 'course-1',
    userId: 'student-1',
    studentName: 'Fallback Name',
    enrolledAt: now,
  );
}

QuizModel _quiz(DateTime now) {
  return QuizModel(
    id: 'quiz-1',
    courseId: 'course-1',
    title: 'Quiz',
    totalPoints: 10,
    isPublished: true,
    createdAt: now,
  );
}

QuizAttemptModel _attempt(
  DateTime now, {
  required String id,
  required int score,
  required double percentage,
}) {
  return QuizAttemptModel(
    id: id,
    quizId: 'quiz-1',
    userId: 'student-1',
    status: AttemptStatus.graded,
    startedAt: now,
    score: score,
    totalPoints: 10,
    percentage: percentage,
  );
}

AssignmentModel _assignment(DateTime now) {
  return AssignmentModel(
    id: 'assignment-1',
    courseId: 'course-1',
    title: 'Assignment',
    description: 'Description',
    language: ProgrammingLanguage.plaintext,
    maxPoints: 20,
    isPublished: true,
    createdAt: now,
  );
}

SubmissionModel _submission(DateTime now, {required int score}) {
  return SubmissionModel(
    id: 'submission-1',
    assignmentId: 'assignment-1',
    courseId: 'course-1',
    userId: 'student-1',
    userDisplayName: 'Ada Lovelace',
    code: 'answer',
    status: SubmissionStatus.graded,
    score: score.toDouble(),
    createdAt: now,
  );
}

AttendanceSession _session(DateTime date, {required String id}) {
  return AttendanceSession(
    id: id,
    courseId: 'course-1',
    attendanceDate: date,
    opensAt: date,
    lateAt: date.add(const Duration(minutes: 15)),
    closesAt: date.add(const Duration(hours: 1)),
    createdBy: 'instructor-1',
    createdAt: date,
  );
}

AttendanceRecord _attendance(
  DateTime date,
  AttendanceStatus status, {
  required String sessionId,
}) {
  return AttendanceRecord(
    id: 'record-$sessionId',
    courseId: 'course-1',
    sessionId: sessionId,
    studentId: 'student-1',
    attendanceDate: date,
    status: status,
    createdBy: 'instructor-1',
    lastModifiedBy: 'instructor-1',
    createdAt: date,
  );
}
