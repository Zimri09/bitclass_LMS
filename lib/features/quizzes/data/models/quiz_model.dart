import 'package:equatable/equatable.dart';

/// Quiz model representing a quiz/assessment in a course
class QuizModel extends Equatable {
  final String id;
  final String courseId;
  final String?
  lessonId; // Optional - quiz can be standalone or attached to lesson
  final String title;
  final String? description;
  final int timeLimitMinutes; // 0 = no time limit
  final int passingScore; // Percentage required to pass (0-100)
  final int totalPoints;
  final int questionCount;
  final bool shuffleQuestions;
  final bool shuffleAnswers;
  final bool showCorrectAnswers; // Show correct answers after submission
  final bool allowRetakes;
  final int maxAttempts; // 0 = unlimited
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const QuizModel({
    required this.id,
    required this.courseId,
    this.lessonId,
    required this.title,
    this.description,
    this.timeLimitMinutes = 0,
    this.passingScore = 70,
    this.totalPoints = 0,
    this.questionCount = 0,
    this.shuffleQuestions = false,
    this.shuffleAnswers = true,
    this.showCorrectAnswers = true,
    this.allowRetakes = true,
    this.maxAttempts = 0,
    this.isPublished = false,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    courseId,
    lessonId,
    title,
    description,
    timeLimitMinutes,
    passingScore,
    totalPoints,
    questionCount,
    shuffleQuestions,
    shuffleAnswers,
    showCorrectAnswers,
    allowRetakes,
    maxAttempts,
    isPublished,
    createdAt,
    updatedAt,
  ];

  factory QuizModel.fromMap(Map<String, dynamic> map) {
    return QuizModel(
      id: map['id'] as String,
      courseId: map['courseId'] as String,
      lessonId: map['lessonId'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      timeLimitMinutes: map['timeLimitMinutes'] as int? ?? 0,
      passingScore: map['passingScore'] as int? ?? 70,
      totalPoints: map['totalPoints'] as int? ?? 0,
      questionCount: map['questionCount'] as int? ?? 0,
      shuffleQuestions: map['shuffleQuestions'] as bool? ?? false,
      shuffleAnswers: map['shuffleAnswers'] as bool? ?? true,
      showCorrectAnswers: map['showCorrectAnswers'] as bool? ?? true,
      allowRetakes: map['allowRetakes'] as bool? ?? true,
      maxAttempts: map['maxAttempts'] as int? ?? 0,
      isPublished: map['isPublished'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'lessonId': lessonId,
      'title': title,
      'description': description,
      'timeLimitMinutes': timeLimitMinutes,
      'passingScore': passingScore,
      'totalPoints': totalPoints,
      'questionCount': questionCount,
      'shuffleQuestions': shuffleQuestions,
      'shuffleAnswers': shuffleAnswers,
      'showCorrectAnswers': showCorrectAnswers,
      'allowRetakes': allowRetakes,
      'maxAttempts': maxAttempts,
      'isPublished': isPublished,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  QuizModel copyWith({
    String? id,
    String? courseId,
    String? lessonId,
    String? title,
    String? description,
    int? timeLimitMinutes,
    int? passingScore,
    int? totalPoints,
    int? questionCount,
    bool? shuffleQuestions,
    bool? shuffleAnswers,
    bool? showCorrectAnswers,
    bool? allowRetakes,
    int? maxAttempts,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuizModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      title: title ?? this.title,
      description: description ?? this.description,
      timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
      passingScore: passingScore ?? this.passingScore,
      totalPoints: totalPoints ?? this.totalPoints,
      questionCount: questionCount ?? this.questionCount,
      shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
      shuffleAnswers: shuffleAnswers ?? this.shuffleAnswers,
      showCorrectAnswers: showCorrectAnswers ?? this.showCorrectAnswers,
      allowRetakes: allowRetakes ?? this.allowRetakes,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'QuizModel($id, $title, $questionCount questions)';
}
