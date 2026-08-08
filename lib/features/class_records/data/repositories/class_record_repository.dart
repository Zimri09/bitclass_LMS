import '../../../assignments/data/repositories/assignment_repository.dart';
import '../../../attendance/data/repositories/attendance_repository.dart';
import '../../../courses/data/repositories/course_repository.dart';
import '../../../quizzes/data/repositories/quiz_repository.dart';
import '../models/class_record_model.dart';
import '../services/class_record_calculator.dart';

class ClassRecordRepository {
  final CourseRepository _courseRepository;
  final QuizRepository _quizRepository;
  final AssignmentRepository _assignmentRepository;
  final AttendanceRepository _attendanceRepository;

  const ClassRecordRepository({
    required CourseRepository courseRepository,
    required QuizRepository quizRepository,
    required AssignmentRepository assignmentRepository,
    required AttendanceRepository attendanceRepository,
  }) : _courseRepository = courseRepository,
       _quizRepository = quizRepository,
       _assignmentRepository = assignmentRepository,
       _attendanceRepository = attendanceRepository;

  Future<CourseClassRecord> getCourseRecord(String courseId) async {
    final enrollmentsFuture = _courseRepository.getCourseEnrollments(courseId);
    final rosterFuture = _courseRepository.getCourseRoster(courseId);
    final quizzesFuture = _quizRepository.getQuizzesByCourse(courseId);
    final assignmentsFuture = _assignmentRepository.getAssignmentsForCourse(
      courseId,
    );
    final sessionsFuture = _attendanceRepository.getSessions(courseId);
    final attendanceFuture = _attendanceRepository.getCourseRecords(courseId);

    final enrollments = await enrollmentsFuture;
    final roster = await rosterFuture;
    final quizzes = await quizzesFuture;
    final assignments = await assignmentsFuture;
    final sessions = await sessionsFuture;
    final attendance = await attendanceFuture;

    final attemptGroups = await Future.wait(
      quizzes.map((quiz) => _quizRepository.getQuizAttempts(quiz.id)),
    );
    final submissionGroups = await Future.wait(
      assignments.map(
        (assignment) =>
            _assignmentRepository.getAssignmentSubmissions(assignment.id),
      ),
    );

    return ClassRecordCalculator.calculate(
      enrollments: enrollments,
      roster: roster,
      quizzes: quizzes,
      quizAttempts: attemptGroups.expand((attempts) => attempts).toList(),
      assignments: assignments,
      submissions: submissionGroups
          .expand((submissions) => submissions)
          .toList(),
      attendanceSessions: sessions,
      attendanceRecords: attendance,
    );
  }
}
