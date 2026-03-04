import 'package:equatable/equatable.dart';

import '../../../quizzes/data/models/quiz_attempt_model.dart';
import '../../../assignments/data/models/submission_model.dart';
import '../../../courses/data/models/course_model.dart';

/// Represents the aggregated grades for a single course
class CourseGradeModel extends Equatable {
  final String courseId;
  final String userId;
  final CourseModel course;
  final EnrollmentModel enrollment;
  final List<QuizAttemptModel> quizAttempts;
  final List<SubmissionModel> assignmentSubmissions;

  const CourseGradeModel({
    required this.courseId,
    required this.userId,
    required this.course,
    required this.enrollment,
    this.quizAttempts = const [],
    this.assignmentSubmissions = const [],
  });

  @override
  List<Object?> get props => [
    courseId,
    userId,
    course,
    enrollment,
    quizAttempts,
    assignmentSubmissions,
  ];

  /// Returns the list of graded quiz attempts only
  List<QuizAttemptModel> get gradedQuizAttempts =>
      quizAttempts.where((a) => a.status == AttemptStatus.graded).toList();

  /// Returns the list of graded assignment submissions only
  List<SubmissionModel> get gradedSubmissions => assignmentSubmissions
      .where((s) => s.status == SubmissionStatus.graded)
      .toList();

  /// Overall grade percentage across all graded items in this course
  double get overallGrade {
    int totalPoints = 0;
    int earnedPoints = 0;

    for (final attempt in gradedQuizAttempts) {
      totalPoints += attempt.totalPoints;
      earnedPoints += attempt.score;
    }

    for (final submission in gradedSubmissions) {
      totalPoints += 100; // Default max points per assignment
      earnedPoints += submission.score ?? 0;
    }

    if (totalPoints == 0) return 0;
    return (earnedPoints / totalPoints) * 100;
  }

  /// Total number of graded items (quizzes + assignments)
  int get completedItems =>
      gradedQuizAttempts.length + gradedSubmissions.length;

  /// Letter grade derived from the overall percentage
  String get letterGrade {
    final grade = overallGrade;
    if (grade >= 93) return 'A';
    if (grade >= 90) return 'A-';
    if (grade >= 87) return 'B+';
    if (grade >= 83) return 'B';
    if (grade >= 80) return 'B-';
    if (grade >= 77) return 'C+';
    if (grade >= 73) return 'C';
    if (grade >= 70) return 'C-';
    if (grade >= 67) return 'D+';
    if (grade >= 60) return 'D';
    return 'F';
  }

  CourseGradeModel copyWith({
    String? courseId,
    String? userId,
    CourseModel? course,
    EnrollmentModel? enrollment,
    List<QuizAttemptModel>? quizAttempts,
    List<SubmissionModel>? assignmentSubmissions,
  }) {
    return CourseGradeModel(
      courseId: courseId ?? this.courseId,
      userId: userId ?? this.userId,
      course: course ?? this.course,
      enrollment: enrollment ?? this.enrollment,
      quizAttempts: quizAttempts ?? this.quizAttempts,
      assignmentSubmissions:
          assignmentSubmissions ?? this.assignmentSubmissions,
    );
  }
}

/// Summary of all grades across all courses for a user
class GradesSummaryModel extends Equatable {
  final String userId;
  final List<CourseGradeModel> courseGrades;

  const GradesSummaryModel({
    required this.userId,
    this.courseGrades = const [],
  });

  @override
  List<Object?> get props => [userId, courseGrades];

  /// Overall GPA-style average across all courses
  double get overallAverage {
    if (courseGrades.isEmpty) return 0;
    final coursesWithGrades = courseGrades
        .where((c) => c.completedItems > 0)
        .toList();
    if (coursesWithGrades.isEmpty) return 0;
    final total = coursesWithGrades.fold<double>(
      0,
      (sum, c) => sum + c.overallGrade,
    );
    return total / coursesWithGrades.length;
  }

  /// All graded quiz attempts across all courses, sorted by date descending
  List<QuizAttemptModel> get allQuizAttempts =>
      courseGrades.expand((c) => c.quizAttempts).toList()..sort(
        (a, b) => (b.submittedAt ?? b.startedAt).compareTo(
          a.submittedAt ?? a.startedAt,
        ),
      );

  /// All graded assignment submissions across all courses, sorted by date desc
  List<SubmissionModel> get allAssignmentSubmissions =>
      courseGrades.expand((c) => c.assignmentSubmissions).toList()
        ..sort((a, b) {
          final aDate = b.gradedAt ?? b.submittedAt ?? b.createdAt;
          final bDate = a.gradedAt ?? a.submittedAt ?? a.createdAt;
          return aDate.compareTo(bDate);
        });

  /// Total number of enrolled courses with graded items
  int get coursesWithGrades =>
      courseGrades.where((c) => c.completedItems > 0).length;

  GradesSummaryModel copyWith({
    String? userId,
    List<CourseGradeModel>? courseGrades,
  }) {
    return GradesSummaryModel(
      userId: userId ?? this.userId,
      courseGrades: courseGrades ?? this.courseGrades,
    );
  }
}
