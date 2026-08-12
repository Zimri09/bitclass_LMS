import 'question_model.dart';

enum QuizGenerationQuestionType {
  multipleChoice,
  trueFalse,
  shortAnswer,
  mixed,
}

extension QuizGenerationQuestionTypeX on QuizGenerationQuestionType {
  String get apiValue => name;

  String get label => switch (this) {
    QuizGenerationQuestionType.multipleChoice => 'Multiple Choice',
    QuizGenerationQuestionType.trueFalse => 'True/False',
    QuizGenerationQuestionType.shortAnswer => 'Short Answer',
    QuizGenerationQuestionType.mixed => 'Mixed',
  };
}

class QuizGenerationPoints {
  final int multipleChoice;
  final int trueFalse;
  final int shortAnswer;

  const QuizGenerationPoints({
    required this.multipleChoice,
    required this.trueFalse,
    required this.shortAnswer,
  });

  static const defaults = QuizGenerationPoints(
    multipleChoice: 2,
    trueFalse: 1,
    shortAnswer: 3,
  );

  int forType(QuestionType type) => switch (type) {
    QuestionType.multipleChoice => multipleChoice,
    QuestionType.trueFalse => trueFalse,
    QuestionType.shortAnswer => shortAnswer,
    QuestionType.multipleSelect || QuestionType.coding => throw ArgumentError(
      'Unsupported generated question type: ${type.name}',
    ),
  };

  List<int> get values => [multipleChoice, trueFalse, shortAnswer];
}

enum QuizGenerationDifficulty { easy, medium, hard, mixed }

extension QuizGenerationDifficultyX on QuizGenerationDifficulty {
  String get apiValue => name;

  String get label => switch (this) {
    QuizGenerationDifficulty.easy => 'Easy',
    QuizGenerationDifficulty.medium => 'Medium',
    QuizGenerationDifficulty.hard => 'Hard',
    QuizGenerationDifficulty.mixed => 'Mixed',
  };
}

class GeneratedQuizQuestion {
  final QuestionType type;
  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  const GeneratedQuizQuestion({
    required this.type,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory GeneratedQuizQuestion.fromMap(Map<String, dynamic> map) {
    final type = switch (map['type']) {
      'multipleChoice' => QuestionType.multipleChoice,
      'trueFalse' => QuestionType.trueFalse,
      'shortAnswer' => QuestionType.shortAnswer,
      _ => throw const FormatException('Unsupported generated question type.'),
    };
    final questionText = _requiredText(map['questionText'], 'question text');
    final explanation = _requiredText(map['explanation'], 'explanation');
    final correctAnswer = _requiredText(map['correctAnswer'], 'correct answer');
    final rawOptions = map['options'];
    if (rawOptions is! List && type != QuestionType.shortAnswer) {
      throw const FormatException('Generated answer choices are missing.');
    }
    final options = rawOptions is List
        ? rawOptions
              .map((option) => _requiredText(option, 'answer choice'))
              .toList(growable: false)
        : const <String>[];
    final expectedCount = switch (type) {
      QuestionType.multipleChoice => 4,
      QuestionType.trueFalse => 2,
      QuestionType.shortAnswer => 0,
      QuestionType.multipleSelect || QuestionType.coding => 0,
    };
    if (options.length != expectedCount) {
      throw FormatException(switch (type) {
        QuestionType.trueFalse =>
          'True/False questions must contain two choices.',
        QuestionType.shortAnswer =>
          'Short-answer questions must not contain answer choices.',
        _ => 'Multiple-choice questions must contain four choices.',
      });
    }

    final normalizedOptions = options
        .map((option) => option.toLowerCase())
        .toSet();
    if (normalizedOptions.length != options.length) {
      throw const FormatException('Generated answer choices must be unique.');
    }
    if (type == QuestionType.trueFalse &&
        !(normalizedOptions.contains('true') &&
            normalizedOptions.contains('false'))) {
      throw const FormatException(
        'True/False questions must use True and False choices.',
      );
    }

    final matchingAnswer = type == QuestionType.shortAnswer
        ? const <String>[]
        : options
              .where(
                (option) => option.toLowerCase() == correctAnswer.toLowerCase(),
              )
              .toList(growable: false);
    if (type != QuestionType.shortAnswer && matchingAnswer.length != 1) {
      throw const FormatException(
        'A generated correct answer does not match its choices.',
      );
    }

    return GeneratedQuizQuestion(
      type: type,
      questionText: questionText,
      options: options,
      correctAnswer: type == QuestionType.shortAnswer
          ? correctAnswer
          : matchingAnswer.single,
      explanation: explanation,
    );
  }

  QuestionModel toQuestionModel({
    required String Function() createId,
    required int order,
    required int points,
  }) {
    if (type == QuestionType.shortAnswer) {
      return QuestionModel(
        id: createId(),
        quizId: '',
        type: type,
        questionText: questionText,
        correctAnswers: [correctAnswer],
        explanation: explanation,
        points: points,
        order: order,
      );
    }

    final answerOptions = options
        .map((option) {
          return AnswerOptionModel(
            id: createId(),
            text: option,
            isCorrect: option == correctAnswer,
          );
        })
        .toList(growable: false);

    return QuestionModel(
      id: createId(),
      quizId: '',
      type: type,
      questionText: questionText,
      options: answerOptions,
      correctAnswers: [
        answerOptions.singleWhere((option) => option.isCorrect).id,
      ],
      explanation: explanation,
      points: points,
      order: order,
    );
  }
}

class GeneratedQuizQuestions {
  final List<GeneratedQuizQuestion> questions;

  const GeneratedQuizQuestions(this.questions);

  factory GeneratedQuizQuestions.fromMap(
    Map<String, dynamic> map, {
    required int expectedCount,
  }) {
    final rawQuestions = map['questions'];
    if (rawQuestions is! List) {
      throw const FormatException('The generated quiz has no questions.');
    }
    if (rawQuestions.length != expectedCount) {
      throw FormatException(
        'Expected $expectedCount generated questions, but received '
        '${rawQuestions.length}.',
      );
    }

    final questions = rawQuestions
        .map((question) {
          if (question is! Map) {
            throw const FormatException('A generated question is malformed.');
          }
          return GeneratedQuizQuestion.fromMap(
            Map<String, dynamic>.from(question),
          );
        })
        .toList(growable: false);

    return GeneratedQuizQuestions(questions);
  }

  List<QuestionModel> toQuestionModels({
    required String Function() createId,
    required QuizGenerationPoints points,
    int startingOrder = 0,
  }) {
    return [
      for (var index = 0; index < questions.length; index++)
        questions[index].toQuestionModel(
          createId: createId,
          order: startingOrder + index,
          points: points.forType(questions[index].type),
        ),
    ];
  }
}

String _requiredText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Generated $field is missing.');
  }
  return value.trim();
}
