import 'package:bitclass/features/assignments/data/models/assignment_model.dart';
import 'package:bitclass/features/assignments/data/models/submission_model.dart';
import 'package:bitclass/features/attendance/data/models/attendance_models.dart';
import 'package:bitclass/features/class_records/data/models/student_performance.dart';
import 'package:bitclass/features/courses/data/models/course_model.dart';
import 'package:bitclass/features/quizzes/data/models/quiz_attempt_model.dart';
import 'package:bitclass/features/quizzes/data/models/quiz_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 8);
  StudentPerformance calculate({
    List<QuizAttemptModel> attempts = const [],
    List<SubmissionModel> submissions = const [],
    List<AttendanceRecord> attendance = const [],
    bool empty = false,
  }) => StudentPerformance.calculate(
    courseId: 'course-1',
    enrollment: _enrollment(now),
    member: const CourseRosterMember(userId: 'student-1', displayName: 'Ada'),
    quizzes: empty
        ? []
        : [
            _quiz(now),
            _quiz(now).copyWith(id: 'foreign-quiz', courseId: 'other-course'),
          ],
    attempts: attempts,
    assignments: empty ? [] : [_assignment(now)],
    submissions: submissions,
    sessions: empty
        ? []
        : [_session(now, id: 'session-1'), _session(now, id: 'session-2')],
    attendance: attendance,
  );

  test('preview uses best attempt and matches existing weighted grades', () {
    final result = calculate(
      attempts: [
        _attempt(now, id: 'a1', score: 5, percentage: 50),
        _attempt(now, id: 'a2', score: 8, percentage: 80),
      ],
      submissions: [_submission(now, score: 10)],
      attendance: [
        _attendance(now, AttendanceStatus.present, sessionId: 'session-1'),
        _attendance(now, AttendanceStatus.late, sessionId: 'session-2'),
      ],
    );
    expect(result.quizzes.length, 1);
    expect(result.earned, 18);
    expect(result.possible, 30);
    expect(result.student.overallGrade, closeTo(69.5, .001));
    expect(result.student.attendanceGrade, 87.5);
    expect(result.count(AttendanceStatus.late), 1);
  });
  test('ignores other students and unrelated attendance sessions', () {
    final result = calculate(
      attempts: [
        _attempt(
          now,
          id: 'foreign',
          score: 10,
          percentage: 100,
        ).copyWith(userId: 'other-student'),
      ],
      attendance: [
        _attendance(
          now,
          AttendanceStatus.present,
          sessionId: 'foreign-session',
        ),
      ],
    );
    expect(result.earned, 0);
    expect(result.attendance, isEmpty);
    expect(result.quizzes.single.status, 'Not attempted');
    expect(result.student.attendanceGrade, isNull);
  });
  test(
    'empty categories have no denominator; excused has no attendance grade',
    () {
      final empty = calculate(empty: true);
      expect(empty.possible, 0);
      expect(empty.student.overallGrade, isNull);
      final excused = calculate(
        attendance: [
          _attendance(now, AttendanceStatus.excused, sessionId: 'session-1'),
        ],
      );
      expect(excused.count(AttendanceStatus.excused), 1);
      expect(excused.student.attendanceGrade, isNull);
    },
  );
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
