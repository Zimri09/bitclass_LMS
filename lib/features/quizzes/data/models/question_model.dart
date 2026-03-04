import 'package:equatable/equatable.dart';

/// Types of questions supported
enum QuestionType {
  multipleChoice, // Single correct answer
  multipleSelect, // Multiple correct answers
  trueFalse,
  shortAnswer,
  coding, // Code challenge with test cases
}

/// Question model representing a quiz question
class QuestionModel extends Equatable {
  final String id;
  final String quizId;
  final QuestionType type;
  final String questionText;
  final String? questionCode; // Code snippet for coding questions
  final String? codeLanguage; // Programming language for code
  final List<AnswerOptionModel> options; // For multiple choice
  final List<String> correctAnswers; // Correct answer(s)
  final String? explanation; // Explanation shown after answering
  final int points;
  final int order;
  final String? hint;
  final List<TestCaseModel>? testCases; // For coding questions

  const QuestionModel({
    required this.id,
    required this.quizId,
    required this.type,
    required this.questionText,
    this.questionCode,
    this.codeLanguage,
    this.options = const [],
    this.correctAnswers = const [],
    this.explanation,
    this.points = 1,
    this.order = 0,
    this.hint,
    this.testCases,
  });

  @override
  List<Object?> get props => [
    id,
    quizId,
    type,
    questionText,
    questionCode,
    codeLanguage,
    options,
    correctAnswers,
    explanation,
    points,
    order,
    hint,
    testCases,
  ];

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      id: map['id'] as String,
      quizId: map['quizId'] as String,
      type: QuestionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => QuestionType.multipleChoice,
      ),
      questionText: map['questionText'] as String,
      questionCode: map['questionCode'] as String?,
      codeLanguage: map['codeLanguage'] as String?,
      options:
          (map['options'] as List<dynamic>?)
              ?.map((e) => AnswerOptionModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      correctAnswers:
          (map['correctAnswers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      explanation: map['explanation'] as String?,
      points: map['points'] as int? ?? 1,
      order: map['order'] as int? ?? 0,
      hint: map['hint'] as String?,
      testCases: (map['testCases'] as List<dynamic>?)
          ?.map((e) => TestCaseModel.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quizId': quizId,
      'type': type.name,
      'questionText': questionText,
      'questionCode': questionCode,
      'codeLanguage': codeLanguage,
      'options': options.map((e) => e.toMap()).toList(),
      'correctAnswers': correctAnswers,
      'explanation': explanation,
      'points': points,
      'order': order,
      'hint': hint,
      'testCases': testCases?.map((e) => e.toMap()).toList(),
    };
  }

  QuestionModel copyWith({
    String? id,
    String? quizId,
    QuestionType? type,
    String? questionText,
    String? questionCode,
    String? codeLanguage,
    List<AnswerOptionModel>? options,
    List<String>? correctAnswers,
    String? explanation,
    int? points,
    int? order,
    String? hint,
    List<TestCaseModel>? testCases,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      quizId: quizId ?? this.quizId,
      type: type ?? this.type,
      questionText: questionText ?? this.questionText,
      questionCode: questionCode ?? this.questionCode,
      codeLanguage: codeLanguage ?? this.codeLanguage,
      options: options ?? this.options,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      explanation: explanation ?? this.explanation,
      points: points ?? this.points,
      order: order ?? this.order,
      hint: hint ?? this.hint,
      testCases: testCases ?? this.testCases,
    );
  }

  @override
  String toString() =>
      'QuestionModel($id, ${type.name}, ${questionText.substring(0, questionText.length > 30 ? 30 : questionText.length)}...)';
}

/// Answer option for multiple choice questions
class AnswerOptionModel extends Equatable {
  final String id;
  final String text;
  final String? code; // Optional code snippet
  final bool isCorrect;

  const AnswerOptionModel({
    required this.id,
    required this.text,
    this.code,
    this.isCorrect = false,
  });

  @override
  List<Object?> get props => [id, text, code, isCorrect];

  factory AnswerOptionModel.fromMap(Map<String, dynamic> map) {
    return AnswerOptionModel(
      id: map['id'] as String,
      text: map['text'] as String,
      code: map['code'] as String?,
      isCorrect: map['isCorrect'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'text': text, 'code': code, 'isCorrect': isCorrect};
  }

  AnswerOptionModel copyWith({
    String? id,
    String? text,
    String? code,
    bool? isCorrect,
  }) {
    return AnswerOptionModel(
      id: id ?? this.id,
      text: text ?? this.text,
      code: code ?? this.code,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }
}

/// Test case for coding questions
class TestCaseModel extends Equatable {
  final String id;
  final String input;
  final String expectedOutput;
  final bool isHidden; // Hidden test cases not shown to user
  final String? description;

  const TestCaseModel({
    required this.id,
    required this.input,
    required this.expectedOutput,
    this.isHidden = false,
    this.description,
  });

  @override
  List<Object?> get props => [id, input, expectedOutput, isHidden, description];

  factory TestCaseModel.fromMap(Map<String, dynamic> map) {
    return TestCaseModel(
      id: map['id'] as String,
      input: map['input'] as String,
      expectedOutput: map['expectedOutput'] as String,
      isHidden: map['isHidden'] as bool? ?? false,
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'input': input,
      'expectedOutput': expectedOutput,
      'isHidden': isHidden,
      'description': description,
    };
  }
}
