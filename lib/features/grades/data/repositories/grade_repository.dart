import '../../../assignments/data/repositories/assignment_repository.dart';
import '../../../courses/data/repositories/course_repository.dart';
import '../../../quizzes/data/repositories/quiz_repository.dart';
import '../models/models.dart';

/// Repository that aggregates grades from quiz attempts and assignment submissions
class GradeRepository {
  final CourseRepository _courseRepository;
  final QuizRepository _quizRepository;
  final AssignmentRepository _assignmentRepository;

  GradeRepository({
    required CourseRepository courseRepository,
    required QuizRepository quizRepository,
    required AssignmentRepository assignmentRepository,
  }) : _courseRepository = courseRepository,
       _quizRepository = quizRepository,
       _assignmentRepository = assignmentRepository;

  /// Load grades summary for a user across all enrolled courses
  Future<GradesSummaryModel> getGradesSummary(String userId) async {
    final enrollments = await _courseRepository.getUserEnrollments(userId);
    final courseGrades = <CourseGradeModel>[];

    for (final enrollment in enrollments) {
      final courseGrade = await getCourseGrade(
        courseId: enrollment.courseId,
        userId: userId,
        enrollment: enrollment,
      );
      if (courseGrade != null) {
        courseGrades.add(courseGrade);
      }
    }

    return GradesSummaryModel(userId: userId, courseGrades: courseGrades);
  }

  /// Load grade data for a specific course
  Future<CourseGradeModel?> getCourseGrade({
    required String courseId,
    required String userId,
    dynamic enrollment,
  }) async {
    final course = await _courseRepository.getCourse(courseId);
    if (course == null) return null;

    // Resolve enrollment if not provided
    final resolvedEnrollment =
        enrollment ??
        (await _courseRepository.getUserEnrollments(
          userId,
        )).cast().firstWhere((e) => e.courseId == courseId, orElse: () => null);
    if (resolvedEnrollment == null) return null;

    // Fetch quiz attempts for this course
    final quizzes = await _quizRepository.getQuizzesByCourse(courseId);
    final quizAttempts = <dynamic>[];
    for (final quiz in quizzes) {
      final attempts = await _quizRepository.getAttempts(
        quizId: quiz.id,
        userId: userId,
      );
      quizAttempts.addAll(attempts);
    }

    // Fetch assignment submissions for this course
    final submissions = await _assignmentRepository.getUserSubmissionsForCourse(
      courseId,
      userId,
    );

    return CourseGradeModel(
      courseId: courseId,
      userId: userId,
      course: course,
      enrollment: resolvedEnrollment,
      quizAttempts: quizAttempts.cast(),
      assignmentSubmissions: submissions,
    );
  }
}
