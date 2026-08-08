import '../../../assignments/data/models/assignment_model.dart';
import '../../../assignments/data/models/submission_model.dart';
import '../../../attendance/data/models/attendance_models.dart';
import '../../../courses/data/models/course_model.dart';
import '../../../quizzes/data/models/quiz_attempt_model.dart';
import '../../../quizzes/data/models/quiz_model.dart';
import '../models/class_record_model.dart';

class ClassRecordCalculator {
  const ClassRecordCalculator._();

  static CourseClassRecord calculate({
    required List<EnrollmentModel> enrollments,
    required List<CourseRosterMember> roster,
    required List<QuizModel> quizzes,
    required List<QuizAttemptModel> quizAttempts,
    required List<AssignmentModel> assignments,
    required List<SubmissionModel> submissions,
    required List<AttendanceSession> attendanceSessions,
    required List<AttendanceRecord> attendanceRecords,
    ClassRecordWeights weights = const ClassRecordWeights(),
  }) {
    final rosterByUser = {for (final member in roster) member.userId: member};
    final quizById = {for (final quiz in quizzes) quiz.id: quiz};
    final assignmentById = {
      for (final assignment in assignments) assignment.id: assignment,
    };
    final activeSessionIds = {
      for (final session in attendanceSessions) session.id,
    };

    final students =
        enrollments.map((enrollment) {
          final member = rosterByUser[enrollment.userId];
          final quizGrade = _quizGrade(
            userId: enrollment.userId,
            quizzes: quizById,
            attempts: quizAttempts,
          );
          final assignmentGrade = _assignmentGrade(
            userId: enrollment.userId,
            assignments: assignmentById,
            submissions: submissions,
          );
          final attendanceGrade = _attendanceGrade(
            userId: enrollment.userId,
            activeSessionIds: activeSessionIds,
            records: attendanceRecords,
          );

          return StudentClassRecord(
            userId: enrollment.userId,
            displayName:
                member?.displayName ?? enrollment.studentName ?? 'Student',
            avatarUrl: member?.avatarUrl,
            quizGrade: quizGrade,
            assignmentGrade: assignmentGrade,
            attendanceGrade: attendanceGrade,
            overallGrade: _overallGrade(
              quizGrade: quizGrade,
              assignmentGrade: assignmentGrade,
              attendanceGrade: attendanceGrade,
              weights: weights,
            ),
          );
        }).toList()..sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );

    return CourseClassRecord(
      students: students,
      weights: weights,
      quizCount: quizzes.length,
      assignmentCount: assignments.length,
      attendanceSessionCount: attendanceSessions.length,
    );
  }

  static double? _quizGrade({
    required String userId,
    required Map<String, QuizModel> quizzes,
    required List<QuizAttemptModel> attempts,
  }) {
    if (quizzes.isEmpty) return null;

    var earned = 0.0;
    var possible = 0.0;
    for (final quiz in quizzes.values) {
      if (quiz.totalPoints <= 0) continue;
      possible += quiz.totalPoints;
      final graded =
          attempts
              .where(
                (attempt) =>
                    attempt.userId == userId &&
                    attempt.quizId == quiz.id &&
                    attempt.status == AttemptStatus.graded,
              )
              .toList()
            ..sort((a, b) => b.percentage.compareTo(a.percentage));
      if (graded.isNotEmpty) {
        earned += graded.first.score.clamp(0, quiz.totalPoints);
      }
    }
    return possible == 0 ? null : earned / possible * 100;
  }

  static double? _assignmentGrade({
    required String userId,
    required Map<String, AssignmentModel> assignments,
    required List<SubmissionModel> submissions,
  }) {
    if (assignments.isEmpty) return null;

    var earned = 0.0;
    var possible = 0.0;
    for (final assignment in assignments.values) {
      if (assignment.maxPoints <= 0) continue;
      possible += assignment.maxPoints;
      final graded = submissions.where(
        (submission) =>
            submission.userId == userId &&
            submission.assignmentId == assignment.id &&
            submission.score != null &&
            (submission.status == SubmissionStatus.graded ||
                submission.status == SubmissionStatus.returned),
      );
      if (graded.isNotEmpty) {
        earned += graded.first.score!.clamp(0, assignment.maxPoints);
      }
    }
    return possible == 0 ? null : earned / possible * 100;
  }

  static double? _attendanceGrade({
    required String userId,
    required Set<String> activeSessionIds,
    required List<AttendanceRecord> records,
  }) {
    if (activeSessionIds.isEmpty) return null;

    final studentRecords = records.where(
      (record) =>
          record.studentId == userId &&
          activeSessionIds.contains(record.sessionId) &&
          record.status != AttendanceStatus.excused,
    );
    if (studentRecords.isEmpty) return null;

    final total = studentRecords.fold<double>(0, (sum, record) {
      return sum +
          switch (record.status) {
            AttendanceStatus.present => 100,
            AttendanceStatus.late => 75,
            AttendanceStatus.absent => 0,
            AttendanceStatus.excused => 0,
          };
    });
    return total / studentRecords.length;
  }

  static double? _overallGrade({
    required double? quizGrade,
    required double? assignmentGrade,
    required double? attendanceGrade,
    required ClassRecordWeights weights,
  }) {
    var weightedTotal = 0.0;
    var activeWeight = 0.0;

    void include(double? grade, double weight) {
      if (grade == null || weight <= 0) return;
      weightedTotal += grade * weight;
      activeWeight += weight;
    }

    include(quizGrade, weights.quizzes);
    include(assignmentGrade, weights.assignments);
    include(attendanceGrade, weights.attendance);
    return activeWeight == 0 ? null : weightedTotal / activeWeight;
  }
}
