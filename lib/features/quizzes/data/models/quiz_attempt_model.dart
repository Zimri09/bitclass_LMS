import 'package:equatable/equatable.dart';

/// Status of a quiz attempt
enum AttemptStatus { inProgress, submitted, graded, timedOut }

/// Quiz attempt model representing a user's attempt at a quiz
class QuizAttemptModel extends Equatable {
  final String id;
  final String quizId;
  final String userId;
  final String? enrollmentId;
  final AttemptStatus status;
  final int attemptNumber;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final DateTime? gradedAt;
  final int score; // Points earned
  final int totalPoints; // Maximum possible points
  final double percentage; // Score percentage
  final bool passed;
  final int timeSpentSeconds;
  final Map<String, UserAnswerModel> answers; // questionId -> answer

  const QuizAttemptModel({
    required this.id,
    required this.quizId,
    required this.userId,
    this.enrollmentId,
    this.status = AttemptStatus.inProgress,
    this.attemptNumber = 1,
    required this.startedAt,
    this.submittedAt,
    this.gradedAt,
    this.score = 0,
    this.totalPoints = 0,
    this.percentage = 0,
    this.passed = false,
    this.timeSpentSeconds = 0,
    this.answers = const {},
  });

  @override
  List<Object?> get props => [
    id,
    quizId,
    userId,
    enrollmentId,
    status,
    attemptNumber,
    startedAt,
    submittedAt,
    gradedAt,
    score,
    totalPoints,
    percentage,
    passed,
    timeSpentSeconds,
    answers,
  ];

  factory QuizAttemptModel.fromMap(Map<String, dynamic> map) {
    return QuizAttemptModel(
      id: map['id'] as String,
      quizId: map['quizId'] as String,
      userId: map['userId'] as String,
      enrollmentId: map['enrollmentId'] as String?,
      status: AttemptStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AttemptStatus.inProgress,
      ),
      attemptNumber: map['attemptNumber'] as int? ?? 1,
      startedAt: DateTime.parse(map['startedAt'] as String),
      submittedAt: map['submittedAt'] != null
          ? DateTime.parse(map['submittedAt'] as String)
          : null,
      gradedAt: map['gradedAt'] != null
          ? DateTime.parse(map['gradedAt'] as String)
          : null,
      score: map['score'] as int? ?? 0,
      totalPoints: map['totalPoints'] as int? ?? 0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0,
      passed: map['passed'] as bool? ?? false,
      timeSpentSeconds: map['timeSpentSeconds'] as int? ?? 0,
      answers:
          (map['answers'] as Map<String, dynamic>?)?.map(
            (k, v) =>
                MapEntry(k, UserAnswerModel.fromMap(v as Map<String, dynamic>)),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quizId': quizId,
      'userId': userId,
      'enrollmentId': enrollmentId,
      'status': status.name,
      'attemptNumber': attemptNumber,
      'startedAt': startedAt.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
      'gradedAt': gradedAt?.toIso8601String(),
      'score': score,
      'totalPoints': totalPoints,
      'percentage': percentage,
      'passed': passed,
      'timeSpentSeconds': timeSpentSeconds,
      'answers': answers.map((k, v) => MapEntry(k, v.toMap())),
    };
  }

  QuizAttemptModel copyWith({
    String? id,
    String? quizId,
    String? userId,
    String? enrollmentId,
    AttemptStatus? status,
    int? attemptNumber,
    DateTime? startedAt,
    DateTime? submittedAt,
    DateTime? gradedAt,
    int? score,
    int? totalPoints,
    double? percentage,
    bool? passed,
    int? timeSpentSeconds,
    Map<String, UserAnswerModel>? answers,
  }) {
    return QuizAttemptModel(
      id: id ?? this.id,
      quizId: quizId ?? this.quizId,
      userId: userId ?? this.userId,
      enrollmentId: enrollmentId ?? this.enrollmentId,
      status: status ?? this.status,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      gradedAt: gradedAt ?? this.gradedAt,
      score: score ?? this.score,
      totalPoints: totalPoints ?? this.totalPoints,
      percentage: percentage ?? this.percentage,
      passed: passed ?? this.passed,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      answers: answers ?? this.answers,
    );
  }

  @override
  String toString() =>
      'QuizAttemptModel($id, quiz: $quizId, score: $score/$totalPoints)';
}

/// User's answer to a question
class UserAnswerModel extends Equatable {
  final String questionId;
  final List<String> selectedAnswers; // For multiple choice
  final String? textAnswer; // For short answer
  final String? codeAnswer; // For coding questions
  final bool isCorrect;
  final int pointsEarned;
  final int maxPoints;
  final String? feedback; // Auto-generated or instructor feedback
  final DateTime answeredAt;

  const UserAnswerModel({
    required this.questionId,
    this.selectedAnswers = const [],
    this.textAnswer,
    this.codeAnswer,
    this.isCorrect = false,
    this.pointsEarned = 0,
    this.maxPoints = 0,
    this.feedback,
    required this.answeredAt,
  });

  @override
  List<Object?> get props => [
    questionId,
    selectedAnswers,
    textAnswer,
    codeAnswer,
    isCorrect,
    pointsEarned,
    maxPoints,
    feedback,
    answeredAt,
  ];

  factory UserAnswerModel.fromMap(Map<String, dynamic> map) {
    return UserAnswerModel(
      questionId: map['questionId'] as String,
      selectedAnswers:
          (map['selectedAnswers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      textAnswer: map['textAnswer'] as String?,
      codeAnswer: map['codeAnswer'] as String?,
      isCorrect: map['isCorrect'] as bool? ?? false,
      pointsEarned: map['pointsEarned'] as int? ?? 0,
      maxPoints: map['maxPoints'] as int? ?? 0,
      feedback: map['feedback'] as String?,
      answeredAt: DateTime.parse(map['answeredAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'selectedAnswers': selectedAnswers,
      'textAnswer': textAnswer,
      'codeAnswer': codeAnswer,
      'isCorrect': isCorrect,
      'pointsEarned': pointsEarned,
      'maxPoints': maxPoints,
      'feedback': feedback,
      'answeredAt': answeredAt.toIso8601String(),
    };
  }

  UserAnswerModel copyWith({
    String? questionId,
    List<String>? selectedAnswers,
    String? textAnswer,
    String? codeAnswer,
    bool? isCorrect,
    int? pointsEarned,
    int? maxPoints,
    String? feedback,
    DateTime? answeredAt,
  }) {
    return UserAnswerModel(
      questionId: questionId ?? this.questionId,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      textAnswer: textAnswer ?? this.textAnswer,
      codeAnswer: codeAnswer ?? this.codeAnswer,
      isCorrect: isCorrect ?? this.isCorrect,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      maxPoints: maxPoints ?? this.maxPoints,
      feedback: feedback ?? this.feedback,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }
}
