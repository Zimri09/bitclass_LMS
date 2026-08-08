import 'package:equatable/equatable.dart';

class ClassRecordWeights extends Equatable {
  final double quizzes;
  final double assignments;
  final double attendance;

  const ClassRecordWeights({
    this.quizzes = 0.4,
    this.assignments = 0.4,
    this.attendance = 0.2,
  });

  int get quizPercent => (quizzes * 100).round();
  int get assignmentPercent => (assignments * 100).round();
  int get attendancePercent => (attendance * 100).round();

  @override
  List<Object?> get props => [quizzes, assignments, attendance];
}

class StudentClassRecord extends Equatable {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double? quizGrade;
  final double? assignmentGrade;
  final double? attendanceGrade;
  final double? overallGrade;

  const StudentClassRecord({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.quizGrade,
    this.assignmentGrade,
    this.attendanceGrade,
    this.overallGrade,
  });

  @override
  List<Object?> get props => [
    userId,
    displayName,
    avatarUrl,
    quizGrade,
    assignmentGrade,
    attendanceGrade,
    overallGrade,
  ];
}

class CourseClassRecord extends Equatable {
  final List<StudentClassRecord> students;
  final ClassRecordWeights weights;
  final int quizCount;
  final int assignmentCount;
  final int attendanceSessionCount;

  const CourseClassRecord({
    required this.students,
    this.weights = const ClassRecordWeights(),
    required this.quizCount,
    required this.assignmentCount,
    required this.attendanceSessionCount,
  });

  double? get classAverage {
    final grades = students
        .map((student) => student.overallGrade)
        .whereType<double>()
        .toList();
    if (grades.isEmpty) return null;
    return grades.reduce((a, b) => a + b) / grades.length;
  }

  @override
  List<Object?> get props => [
    students,
    weights,
    quizCount,
    assignmentCount,
    attendanceSessionCount,
  ];
}
