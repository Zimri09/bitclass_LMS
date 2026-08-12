import 'package:bitclass/features/quizzes/data/models/question_model.dart';
import 'package:bitclass/features/quizzes/data/models/quiz_generation_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeneratedQuizQuestions', () {
    test('parses valid questions and creates editable question models', () {
      final generated = GeneratedQuizQuestions.fromMap({
        'questions': [
          {
            'type': 'multipleChoice',
            'questionText': 'Which structure uses FIFO ordering?',
            'options': ['Stack', 'Queue', 'Tree', 'Graph'],
            'correctAnswer': 'Queue',
            'explanation':
                'A queue removes items in first-in, first-out order.',
          },
          {
            'type': 'trueFalse',
            'questionText': 'Binary search requires sorted input.',
            'options': ['True', 'False'],
            'correctAnswer': 'True',
            'explanation': 'The search eliminates ordered halves of the input.',
          },
          {
            'type': 'shortAnswer',
            'questionText': 'Which ordering does a queue use?',
            'options': <String>[],
            'correctAnswer': 'First in, first out',
            'explanation': 'Queue items leave in the order they entered.',
          },
        ],
      }, expectedCount: 3);

      var nextId = 0;
      String createId() => 'generated-${nextId++}';
      final questionModels = generated.toQuestionModels(
        createId: createId,
        points: QuizGenerationPoints.defaults,
        startingOrder: 3,
      );
      final multipleChoice = generated.questions.first.toQuestionModel(
        createId: createId,
        order: 3,
        points: 2,
      );

      final shortAnswer = generated.questions.last.toQuestionModel(
        createId: createId,
        order: 5,
        points: QuizGenerationPoints.defaults.forType(QuestionType.shortAnswer),
      );

      expect(generated.questions[1].type, QuestionType.trueFalse);
      expect(multipleChoice.type, QuestionType.multipleChoice);
      expect(multipleChoice.options, hasLength(4));
      expect(
        multipleChoice.options.where((option) => option.isCorrect),
        hasLength(1),
      );
      expect(multipleChoice.correctAnswers, [
        multipleChoice.options.singleWhere((option) => option.isCorrect).id,
      ]);
      expect(multipleChoice.order, 3);
      expect(multipleChoice.points, 2);
      expect(shortAnswer.type, QuestionType.shortAnswer);
      expect(shortAnswer.options, isEmpty);
      expect(shortAnswer.correctAnswers, ['First in, first out']);
      expect(shortAnswer.points, 3);
      expect(questionModels.map((question) => question.points), [2, 1, 3]);
      expect(questionModels.map((question) => question.order), [3, 4, 5]);
    });

    test('rejects a correct answer that is not one of the choices', () {
      expect(
        () => GeneratedQuizQuestions.fromMap({
          'questions': [
            {
              'type': 'multipleChoice',
              'questionText': 'What is O(1)?',
              'options': ['Constant', 'Linear', 'Quadratic', 'Logarithmic'],
              'correctAnswer': 'Exponential',
              'explanation': 'Constant work does not grow with input size.',
            },
          ],
        }, expectedCount: 1),
        throwsFormatException,
      );
    });

    test('rejects duplicate answer choices', () {
      expect(
        () => GeneratedQuizQuestions.fromMap({
          'questions': [
            {
              'type': 'multipleChoice',
              'questionText': 'Choose a data structure.',
              'options': ['Queue', 'queue', 'Tree', 'Graph'],
              'correctAnswer': 'Queue',
              'explanation': 'A queue is a data structure.',
            },
          ],
        }, expectedCount: 1),
        throwsFormatException,
      );
    });

    test('rejects answer choices on a short-answer question', () {
      expect(
        () => GeneratedQuizQuestions.fromMap({
          'questions': [
            {
              'type': 'shortAnswer',
              'questionText': 'What does FIFO mean?',
              'options': ['First in, first out'],
              'correctAnswer': 'First in, first out',
              'explanation': 'FIFO describes queue ordering.',
            },
          ],
        }, expectedCount: 1),
        throwsFormatException,
      );
    });

    test('rejects a response with the wrong question count', () {
      expect(
        () => GeneratedQuizQuestions.fromMap(const {
          'questions': <Object>[],
        }, expectedCount: 5),
        throwsFormatException,
      );
    });
  });
}
