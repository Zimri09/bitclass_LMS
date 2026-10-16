import '../../../assignments/data/models/assignment_model.dart';
import '../../../assignments/data/models/submission_model.dart';
import '../../../attendance/data/models/attendance_models.dart';
import '../../../courses/data/models/course_model.dart';
import '../../../quizzes/data/models/quiz_attempt_model.dart';
import '../../../quizzes/data/models/quiz_model.dart';
import '../services/class_record_calculator.dart';
import 'class_record_model.dart';

class PerformanceScore {
  final String title;
  final double earned;
  final double possible;
  final String status;
  const PerformanceScore(this.title, this.earned, this.possible, this.status);
}

class StudentPerformance {
  final StudentClassRecord student;
  final List<PerformanceScore> quizzes;
  final List<PerformanceScore> activities;
  final int sessionCount;
  final List<AttendanceRecord> attendance;

  const StudentPerformance({
    required this.student,
    required this.quizzes,
    required this.activities,
    required this.sessionCount,
    required this.attendance,
  });

  double get earned =>
      [...quizzes, ...activities].fold(0, (sum, s) => sum + s.earned);
  double get possible =>
      [...quizzes, ...activities].fold(0, (sum, s) => sum + s.possible);
  int count(AttendanceStatus status) =>
      attendance.where((r) => r.status == status).length;

  factory StudentPerformance.calculate({
    required String courseId,
    required EnrollmentModel enrollment,
    required CourseRosterMember member,
    required List<QuizModel> quizzes,
    required List<QuizAttemptModel> attempts,
    required List<AssignmentModel> assignments,
    required List<SubmissionModel> submissions,
    required List<AttendanceSession> sessions,
    required List<AttendanceRecord> attendance,
  }) {
    final userId = enrollment.userId;
    final courseQuizzes = quizzes.where((q) => q.courseId == courseId).toList();
    final courseAssignments = assignments
        .where((a) => a.courseId == courseId)
        .toList();
    final courseSessions = sessions
        .where((s) => s.courseId == courseId)
        .toList();
    final sessionIds = courseSessions.map((s) => s.id).toSet();
    final records = attendance
        .where(
          (r) =>
              r.courseId == courseId &&
              r.studentId == userId &&
              sessionIds.contains(r.sessionId),
        )
        .toList();
    final student = ClassRecordCalculator.calculate(
      enrollments: [enrollment],
      roster: [member],
      quizzes: courseQuizzes,
      quizAttempts: attempts,
      assignments: courseAssignments,
      submissions: submissions,
      attendanceSessions: courseSessions,
      attendanceRecords: records,
    ).students.single;
    return StudentPerformance(
      student: student,
      sessionCount: courseSessions.length,
      attendance: records,
      quizzes: courseQuizzes.map((q) {
        final own = attempts
            .where((a) => a.userId == userId && a.quizId == q.id)
            .toList();
        final graded =
            own.where((a) => a.status == AttemptStatus.graded).toList()
              ..sort((a, b) => b.percentage.compareTo(a.percentage));
        final max = q.totalPoints > 0 ? q.totalPoints.toDouble() : 0.0;
        return PerformanceScore(
          q.title,
          graded.isEmpty ? 0 : graded.first.score.clamp(0, max).toDouble(),
          max,
          graded.isNotEmpty
              ? 'Best graded attempt'
              : own.isEmpty
              ? 'Not attempted'
              : 'Not graded',
        );
      }).toList(),
      activities: courseAssignments.map((a) {
        final own = submissions
            .where((s) => s.userId == userId && s.assignmentId == a.id)
            .toList();
        final graded = own
            .where(
              (s) =>
                  s.score != null &&
                  (s.status == SubmissionStatus.graded ||
                      s.status == SubmissionStatus.returned),
            )
            .toList();
        final max = a.maxPoints > 0 ? a.maxPoints.toDouble() : 0.0;
        return PerformanceScore(
          a.title,
          graded.isEmpty ? 0 : graded.first.score!.clamp(0, max).toDouble(),
          max,
          graded.isNotEmpty
              ? 'Graded'
              : own.isEmpty
              ? 'Not submitted'
              : 'Not graded',
        );
      }).toList(),
    );
  }
}
