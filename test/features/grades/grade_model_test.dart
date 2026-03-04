import 'package:flutter_test/flutter_test.dart';
import 'package:bitclass/features/grades/data/models/grade_model.dart';
import 'package:bitclass/features/courses/data/models/course_model.dart';
import 'package:bitclass/features/quizzes/data/models/quiz_attempt_model.dart';
import 'package:bitclass/features/assignments/data/models/submission_model.dart';

void main() {
  // -- helpers --
  CourseModel makeCourse({String id = 'course-1'}) => CourseModel(
    id: id,
    title: 'Flutter 101',
    description: 'Intro to Flutter',
    category: 'Mobile Development',
    instructorId: 'inst-1',
    instructorName: 'Prof. Smith',
    createdAt: DateTime(2024, 1, 1),
  );

  EnrollmentModel makeEnrollment({
    String courseId = 'course-1',
    String userId = 'user-1',
  }) => EnrollmentModel(
    id: 'enr-1',
    courseId: courseId,
    userId: userId,
    enrolledAt: DateTime(2024, 1, 5),
  );

  QuizAttemptModel makeAttempt({
    String id = 'att-1',
    AttemptStatus status = AttemptStatus.graded,
    int score = 80,
    int totalPoints = 100,
  }) => QuizAttemptModel(
    id: id,
    quizId: 'quiz-1',
    userId: 'user-1',
    startedAt: DateTime(2024, 2, 1),
    submittedAt: DateTime(2024, 2, 1, 0, 30),
    status: status,
    score: score,
    totalPoints: totalPoints,
  );

  SubmissionModel makeSubmission({
    String id = 'sub-1',
    SubmissionStatus status = SubmissionStatus.graded,
    int? score = 90,
  }) => SubmissionModel(
    id: id,
    assignmentId: 'assign-1',
    courseId: 'course-1',
    userId: 'user-1',
    userDisplayName: 'Test User',
    code: 'void main() {}',
    createdAt: DateTime(2024, 2, 10),
    submittedAt: DateTime(2024, 2, 10),
    status: status,
    score: score,
  );

  // ====================================================
  // CourseGradeModel
  // ====================================================
  group('CourseGradeModel', () {
    test('creates a valid instance with defaults', () {
      final grade = CourseGradeModel(
        courseId: 'course-1',
        userId: 'user-1',
        course: makeCourse(),
        enrollment: makeEnrollment(),
      );

      expect(grade.courseId, 'course-1');
      expect(grade.userId, 'user-1');
      expect(grade.quizAttempts, isEmpty);
      expect(grade.assignmentSubmissions, isEmpty);
    });

    test('gradedQuizAttempts filters only graded attempts', () {
      final grade = CourseGradeModel(
        courseId: 'course-1',
        userId: 'user-1',
        course: makeCourse(),
        enrollment: makeEnrollment(),
        quizAttempts: [
          makeAttempt(id: 'a1', status: AttemptStatus.graded),
          makeAttempt(id: 'a2', status: AttemptStatus.submitted),
          makeAttempt(id: 'a3', status: AttemptStatus.inProgress),
        ],
      );

      expect(grade.gradedQuizAttempts, hasLength(1));
      expect(grade.gradedQuizAttempts.first.id, 'a1');
    });

    test('gradedSubmissions filters only graded submissions', () {
      final grade = CourseGradeModel(
        courseId: 'course-1',
        userId: 'user-1',
        course: makeCourse(),
        enrollment: makeEnrollment(),
        assignmentSubmissions: [
          makeSubmission(id: 's1', status: SubmissionStatus.graded, score: 85),
          makeSubmission(id: 's2', status: SubmissionStatus.submitted),
          makeSubmission(id: 's3', status: SubmissionStatus.draft),
        ],
      );

      expect(grade.gradedSubmissions, hasLength(1));
      expect(grade.gradedSubmissions.first.id, 's1');
    });

    test('overallGrade computes weighted average', () {
      final grade = CourseGradeModel(
        courseId: 'course-1',
        userId: 'user-1',
        course: makeCourse(),
        enrollment: makeEnrollment(),
        quizAttempts: [makeAttempt(id: 'a1', score: 80, totalPoints: 100)],
        assignmentSubmissions: [makeSubmission(id: 's1', score: 90)],
      );

      // totalPoints = 100 (quiz) + 100 (assignment) = 200
      // earned = 80 + 90 = 170
      // percentage = 170/200 * 100 = 85
      expect(grade.overallGrade, 85.0);
    });

    test('overallGrade is zero when no graded items', () {
      final grade = CourseGradeModel(
        courseId: 'course-1',
        userId: 'user-1',
        course: makeCourse(),
        enrollment: makeEnrollment(),
      );

      expect(grade.overallGrade, 0.0);
    });

    test('completedItems sums graded quizzes and submissions', () {
      final grade = CourseGradeModel(
        courseId: 'course-1',
        userId: 'user-1',
        course: makeCourse(),
        enrollment: makeEnrollment(),
        quizAttempts: [
          makeAttempt(id: 'a1', status: AttemptStatus.graded),
          makeAttempt(id: 'a2', status: AttemptStatus.graded),
        ],
        assignmentSubmissions: [
          makeSubmission(id: 's1', status: SubmissionStatus.graded),
        ],
      );

      expect(grade.completedItems, 3);
    });

    test('letterGrade returns correct grade for various percentages', () {
      CourseGradeModel makeWithScore(int quizScore) => CourseGradeModel(
        courseId: 'c',
        userId: 'u',
        course: makeCourse(),
        enrollment: makeEnrollment(),
        quizAttempts: [makeAttempt(score: quizScore, totalPoints: 100)],
      );

      expect(makeWithScore(95).letterGrade, 'A');
      expect(makeWithScore(91).letterGrade, 'A-');
      expect(makeWithScore(88).letterGrade, 'B+');
      expect(makeWithScore(85).letterGrade, 'B');
      expect(makeWithScore(80).letterGrade, 'B-');
      expect(makeWithScore(77).letterGrade, 'C+');
      expect(makeWithScore(75).letterGrade, 'C');
      expect(makeWithScore(70).letterGrade, 'C-');
      expect(makeWithScore(67).letterGrade, 'D+');
      expect(makeWithScore(60).letterGrade, 'D');
      expect(makeWithScore(50).letterGrade, 'F');
    });

    test('copyWith creates new instance with updated fields', () {
      final original = CourseGradeModel(
        courseId: 'course-1',
        userId: 'user-1',
        course: makeCourse(),
        enrollment: makeEnrollment(),
      );

      final updated = original.copyWith(userId: 'user-2');

      expect(updated.userId, 'user-2');
      expect(updated.courseId, 'course-1'); // unchanged
    });

    test('equatable: two identical instances are equal', () {
      final a = CourseGradeModel(
        courseId: 'c1',
        userId: 'u1',
        course: makeCourse(),
        enrollment: makeEnrollment(),
      );
      final b = CourseGradeModel(
        courseId: 'c1',
        userId: 'u1',
        course: makeCourse(),
        enrollment: makeEnrollment(),
      );
      expect(a, equals(b));
    });
  });

  // ====================================================
  // GradesSummaryModel
  // ====================================================
  group('GradesSummaryModel', () {
    test('creates a valid summary with defaults', () {
      final summary = GradesSummaryModel(userId: 'user-1');

      expect(summary.userId, 'user-1');
      expect(summary.courseGrades, isEmpty);
    });

    test('overallAverage averages across courses with grades', () {
      // Course 1: 80%, Course 2: 90%
      final summary = GradesSummaryModel(
        userId: 'user-1',
        courseGrades: [
          CourseGradeModel(
            courseId: 'c1',
            userId: 'user-1',
            course: makeCourse(id: 'c1'),
            enrollment: makeEnrollment(courseId: 'c1'),
            quizAttempts: [makeAttempt(id: 'a1', score: 80, totalPoints: 100)],
          ),
          CourseGradeModel(
            courseId: 'c2',
            userId: 'user-1',
            course: makeCourse(id: 'c2'),
            enrollment: makeEnrollment(courseId: 'c2'),
            quizAttempts: [makeAttempt(id: 'a2', score: 90, totalPoints: 100)],
          ),
        ],
      );

      expect(summary.overallAverage, 85.0);
    });

    test('overallAverage ignores courses with no graded items', () {
      final summary = GradesSummaryModel(
        userId: 'user-1',
        courseGrades: [
          CourseGradeModel(
            courseId: 'c1',
            userId: 'user-1',
            course: makeCourse(id: 'c1'),
            enrollment: makeEnrollment(courseId: 'c1'),
            quizAttempts: [makeAttempt(id: 'a1', score: 80, totalPoints: 100)],
          ),
          // This course has no graded items
          CourseGradeModel(
            courseId: 'c2',
            userId: 'user-1',
            course: makeCourse(id: 'c2'),
            enrollment: makeEnrollment(courseId: 'c2'),
          ),
        ],
      );

      // Only course c1 counted → 80
      expect(summary.overallAverage, 80.0);
    });

    test('overallAverage is zero when no courses', () {
      final summary = GradesSummaryModel(userId: 'user-1');
      expect(summary.overallAverage, 0.0);
    });

    test('coursesWithGrades counts only courses with completed items', () {
      final summary = GradesSummaryModel(
        userId: 'user-1',
        courseGrades: [
          CourseGradeModel(
            courseId: 'c1',
            userId: 'user-1',
            course: makeCourse(id: 'c1'),
            enrollment: makeEnrollment(courseId: 'c1'),
            quizAttempts: [makeAttempt(id: 'a1')],
          ),
          CourseGradeModel(
            courseId: 'c2',
            userId: 'user-1',
            course: makeCourse(id: 'c2'),
            enrollment: makeEnrollment(courseId: 'c2'),
          ),
        ],
      );

      expect(summary.coursesWithGrades, 1);
    });

    test('allQuizAttempts aggregates from all courses', () {
      final summary = GradesSummaryModel(
        userId: 'user-1',
        courseGrades: [
          CourseGradeModel(
            courseId: 'c1',
            userId: 'user-1',
            course: makeCourse(id: 'c1'),
            enrollment: makeEnrollment(courseId: 'c1'),
            quizAttempts: [
              makeAttempt(id: 'a1'),
              makeAttempt(id: 'a2'),
            ],
          ),
          CourseGradeModel(
            courseId: 'c2',
            userId: 'user-1',
            course: makeCourse(id: 'c2'),
            enrollment: makeEnrollment(courseId: 'c2'),
            quizAttempts: [makeAttempt(id: 'a3')],
          ),
        ],
      );

      expect(summary.allQuizAttempts, hasLength(3));
    });

    test('allAssignmentSubmissions aggregates from all courses', () {
      final summary = GradesSummaryModel(
        userId: 'user-1',
        courseGrades: [
          CourseGradeModel(
            courseId: 'c1',
            userId: 'user-1',
            course: makeCourse(id: 'c1'),
            enrollment: makeEnrollment(courseId: 'c1'),
            assignmentSubmissions: [makeSubmission(id: 's1')],
          ),
          CourseGradeModel(
            courseId: 'c2',
            userId: 'user-1',
            course: makeCourse(id: 'c2'),
            enrollment: makeEnrollment(courseId: 'c2'),
            assignmentSubmissions: [
              makeSubmission(id: 's2'),
              makeSubmission(id: 's3'),
            ],
          ),
        ],
      );

      expect(summary.allAssignmentSubmissions, hasLength(3));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = GradesSummaryModel(userId: 'user-1');
      final updated = original.copyWith(userId: 'user-2');

      expect(updated.userId, 'user-2');
      expect(updated.courseGrades, isEmpty);
    });

    test('equatable: identical summaries are equal', () {
      final a = GradesSummaryModel(userId: 'user-1');
      final b = GradesSummaryModel(userId: 'user-1');
      expect(a, equals(b));
    });
  });
}
