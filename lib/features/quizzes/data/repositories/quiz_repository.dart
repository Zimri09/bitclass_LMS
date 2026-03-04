import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/models.dart';

/// Repository for quiz operations
class QuizRepository {
  final FirebaseFirestore? _firestore;

  // Demo data storage
  final Map<String, QuizModel> _quizzes = {};
  final Map<String, List<QuestionModel>> _questionsByQuiz = {};
  final Map<String, List<QuizAttemptModel>> _attemptsByUser = {};

  QuizRepository({FirebaseFirestore? firestore})
    : _firestore = EnvironmentConfig.isDemoMode
          ? null
          : (firestore ?? FirebaseFirestore.instance) {
    if (EnvironmentConfig.isDemoMode) {
      _initDemoData();
    }
  }

  void _initDemoData() {
    // Flutter Course Quiz
    _quizzes['quiz-flutter-basics'] = QuizModel(
      id: 'quiz-flutter-basics',
      courseId: 'course-1',
      lessonId: 'lesson-1-1-2',
      title: 'Flutter Basics Quiz',
      description: 'Test your understanding of Flutter fundamentals',
      timeLimitMinutes: 15,
      passingScore: 70,
      totalPoints: 10,
      questionCount: 5,
      shuffleQuestions: true,
      shuffleAnswers: true,
      showCorrectAnswers: true,
      allowRetakes: true,
      maxAttempts: 3,
      isPublished: true,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );

    _questionsByQuiz['quiz-flutter-basics'] = [
      QuestionModel(
        id: 'q-flutter-1',
        quizId: 'quiz-flutter-basics',
        type: QuestionType.multipleChoice,
        questionText: 'What is Flutter?',
        options: const [
          AnswerOptionModel(
            id: 'opt-1',
            text: 'A cross-platform UI toolkit by Google',
            isCorrect: true,
          ),
          AnswerOptionModel(
            id: 'opt-2',
            text: 'A programming language',
            isCorrect: false,
          ),
          AnswerOptionModel(
            id: 'opt-3',
            text: 'A database management system',
            isCorrect: false,
          ),
          AnswerOptionModel(
            id: 'opt-4',
            text: 'An operating system',
            isCorrect: false,
          ),
        ],
        correctAnswers: const ['opt-1'],
        explanation:
            'Flutter is Google\'s UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.',
        points: 2,
        order: 0,
      ),
      QuestionModel(
        id: 'q-flutter-2',
        quizId: 'quiz-flutter-basics',
        type: QuestionType.multipleChoice,
        questionText: 'Which programming language does Flutter use?',
        options: const [
          AnswerOptionModel(id: 'opt-1', text: 'Java', isCorrect: false),
          AnswerOptionModel(id: 'opt-2', text: 'Kotlin', isCorrect: false),
          AnswerOptionModel(id: 'opt-3', text: 'Dart', isCorrect: true),
          AnswerOptionModel(id: 'opt-4', text: 'Swift', isCorrect: false),
        ],
        correctAnswers: const ['opt-3'],
        explanation:
            'Flutter uses Dart, a modern programming language developed by Google.',
        points: 2,
        order: 1,
      ),
      QuestionModel(
        id: 'q-flutter-3',
        quizId: 'quiz-flutter-basics',
        type: QuestionType.trueFalse,
        questionText: 'Flutter can only be used to build mobile applications.',
        options: const [
          AnswerOptionModel(id: 'true', text: 'True', isCorrect: false),
          AnswerOptionModel(id: 'false', text: 'False', isCorrect: true),
        ],
        correctAnswers: const ['false'],
        explanation:
            'Flutter can build applications for mobile, web, desktop, and embedded devices.',
        points: 2,
        order: 2,
      ),
      QuestionModel(
        id: 'q-flutter-4',
        quizId: 'quiz-flutter-basics',
        type: QuestionType.multipleSelect,
        questionText:
            'Which of the following are valid Flutter widget types? (Select all that apply)',
        options: const [
          AnswerOptionModel(
            id: 'opt-1',
            text: 'StatelessWidget',
            isCorrect: true,
          ),
          AnswerOptionModel(
            id: 'opt-2',
            text: 'StatefulWidget',
            isCorrect: true,
          ),
          AnswerOptionModel(
            id: 'opt-3',
            text: 'MutableWidget',
            isCorrect: false,
          ),
          AnswerOptionModel(
            id: 'opt-4',
            text: 'InheritedWidget',
            isCorrect: true,
          ),
        ],
        correctAnswers: const ['opt-1', 'opt-2', 'opt-4'],
        explanation:
            'StatelessWidget, StatefulWidget, and InheritedWidget are core Flutter widget types.',
        points: 2,
        order: 3,
      ),
      QuestionModel(
        id: 'q-flutter-5',
        quizId: 'quiz-flutter-basics',
        type: QuestionType.multipleChoice,
        questionText: 'What is the main() function in a Flutter app?',
        options: const [
          AnswerOptionModel(
            id: 'opt-1',
            text: 'The entry point of the application',
            isCorrect: true,
          ),
          AnswerOptionModel(
            id: 'opt-2',
            text: 'A widget builder function',
            isCorrect: false,
          ),
          AnswerOptionModel(
            id: 'opt-3',
            text: 'A state management function',
            isCorrect: false,
          ),
          AnswerOptionModel(
            id: 'opt-4',
            text: 'A routing function',
            isCorrect: false,
          ),
        ],
        correctAnswers: const ['opt-1'],
        explanation:
            'main() is the entry point where the app starts execution and calls runApp().',
        points: 2,
        order: 4,
      ),
    ];

    // Dart Programming Quiz
    _quizzes['quiz-dart-basics'] = QuizModel(
      id: 'quiz-dart-basics',
      courseId: 'course-2',
      title: 'Dart Programming Fundamentals',
      description: 'Assess your Dart programming knowledge',
      timeLimitMinutes: 20,
      passingScore: 60,
      totalPoints: 15,
      questionCount: 6,
      shuffleQuestions: true,
      shuffleAnswers: true,
      showCorrectAnswers: true,
      allowRetakes: true,
      maxAttempts: 0,
      isPublished: true,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    );

    _questionsByQuiz['quiz-dart-basics'] = [
      QuestionModel(
        id: 'q-dart-1',
        quizId: 'quiz-dart-basics',
        type: QuestionType.multipleChoice,
        questionText: 'How do you declare a nullable variable in Dart?',
        options: const [
          AnswerOptionModel(id: 'opt-1', text: 'String? name', isCorrect: true),
          AnswerOptionModel(
            id: 'opt-2',
            text: 'String name?',
            isCorrect: false,
          ),
          AnswerOptionModel(
            id: 'opt-3',
            text: 'nullable String name',
            isCorrect: false,
          ),
          AnswerOptionModel(
            id: 'opt-4',
            text: 'String name = null',
            isCorrect: false,
          ),
        ],
        correctAnswers: const ['opt-1'],
        explanation:
            'In Dart, you add ? after the type to make it nullable: String? name',
        points: 2,
        order: 0,
      ),
      QuestionModel(
        id: 'q-dart-2',
        quizId: 'quiz-dart-basics',
        type: QuestionType.coding,
        questionText: 'Write a function that returns the sum of two integers.',
        questionCode: '''
// Complete the function below
int sum(int a, int b) {
  // Your code here
}
''',
        codeLanguage: 'dart',
        correctAnswers: const ['return a + b;'],
        explanation:
            'The function should return the sum of parameters a and b.',
        points: 3,
        order: 1,
        testCases: const [
          TestCaseModel(
            id: 'tc-1',
            input: 'sum(2, 3)',
            expectedOutput: '5',
            description: 'Basic addition',
          ),
          TestCaseModel(
            id: 'tc-2',
            input: 'sum(-1, 1)',
            expectedOutput: '0',
            description: 'Adding negative number',
          ),
          TestCaseModel(
            id: 'tc-3',
            input: 'sum(0, 0)',
            expectedOutput: '0',
            description: 'Adding zeros',
            isHidden: true,
          ),
        ],
      ),
      QuestionModel(
        id: 'q-dart-3',
        quizId: 'quiz-dart-basics',
        type: QuestionType.trueFalse,
        questionText: 'Dart is a statically typed language.',
        options: const [
          AnswerOptionModel(id: 'true', text: 'True', isCorrect: true),
          AnswerOptionModel(id: 'false', text: 'False', isCorrect: false),
        ],
        correctAnswers: const ['true'],
        explanation: 'Dart is indeed statically typed with sound null safety.',
        points: 2,
        order: 2,
      ),
      QuestionModel(
        id: 'q-dart-4',
        quizId: 'quiz-dart-basics',
        type: QuestionType.multipleChoice,
        questionText:
            'What keyword is used to create an asynchronous function?',
        options: const [
          AnswerOptionModel(id: 'opt-1', text: 'async', isCorrect: true),
          AnswerOptionModel(id: 'opt-2', text: 'await', isCorrect: false),
          AnswerOptionModel(id: 'opt-3', text: 'future', isCorrect: false),
          AnswerOptionModel(id: 'opt-4', text: 'defer', isCorrect: false),
        ],
        correctAnswers: const ['opt-1'],
        explanation:
            'The async keyword marks a function as asynchronous, allowing use of await.',
        points: 2,
        order: 3,
      ),
      QuestionModel(
        id: 'q-dart-5',
        quizId: 'quiz-dart-basics',
        type: QuestionType.shortAnswer,
        questionText:
            'What is the keyword used to define a constant at compile time in Dart?',
        correctAnswers: const ['const'],
        explanation:
            'The const keyword creates compile-time constants in Dart.',
        points: 3,
        order: 4,
        hint: 'It starts with "c"',
      ),
      QuestionModel(
        id: 'q-dart-6',
        quizId: 'quiz-dart-basics',
        type: QuestionType.multipleSelect,
        questionText:
            'Which of the following are valid collection types in Dart?',
        options: const [
          AnswerOptionModel(id: 'opt-1', text: 'List', isCorrect: true),
          AnswerOptionModel(id: 'opt-2', text: 'Set', isCorrect: true),
          AnswerOptionModel(id: 'opt-3', text: 'Map', isCorrect: true),
          AnswerOptionModel(id: 'opt-4', text: 'Tuple', isCorrect: false),
        ],
        correctAnswers: const ['opt-1', 'opt-2', 'opt-3'],
        explanation: 'Dart has List, Set, and Map as core collection types.',
        points: 3,
        order: 5,
      ),
    ];

    // Data Structures Quiz
    _quizzes['quiz-data-structures'] = QuizModel(
      id: 'quiz-data-structures',
      courseId: 'course-3',
      title: 'Data Structures Challenge',
      description: 'Test your knowledge of arrays, trees, and algorithms',
      timeLimitMinutes: 30,
      passingScore: 70,
      totalPoints: 20,
      questionCount: 5,
      shuffleQuestions: false,
      shuffleAnswers: true,
      showCorrectAnswers: true,
      allowRetakes: true,
      maxAttempts: 2,
      isPublished: true,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    );

    _questionsByQuiz['quiz-data-structures'] = [
      QuestionModel(
        id: 'q-ds-1',
        quizId: 'quiz-data-structures',
        type: QuestionType.multipleChoice,
        questionText:
            'What is the time complexity of accessing an element in an array by index?',
        options: const [
          AnswerOptionModel(id: 'opt-1', text: 'O(1)', isCorrect: true),
          AnswerOptionModel(id: 'opt-2', text: 'O(n)', isCorrect: false),
          AnswerOptionModel(id: 'opt-3', text: 'O(log n)', isCorrect: false),
          AnswerOptionModel(id: 'opt-4', text: 'O(n²)', isCorrect: false),
        ],
        correctAnswers: const ['opt-1'],
        explanation:
            'Array access by index is O(1) because arrays use contiguous memory.',
        points: 4,
        order: 0,
      ),
      QuestionModel(
        id: 'q-ds-2',
        quizId: 'quiz-data-structures',
        type: QuestionType.coding,
        questionText: 'Write a function to reverse a list of integers.',
        questionCode: '''
List<int> reverseList(List<int> numbers) {
  // Your code here
}
''',
        codeLanguage: 'dart',
        correctAnswers: const ['return numbers.reversed.toList();'],
        explanation: 'You can use .reversed.toList() or implement manually.',
        points: 5,
        order: 1,
        testCases: const [
          TestCaseModel(
            id: 'tc-1',
            input: 'reverseList([1, 2, 3])',
            expectedOutput: '[3, 2, 1]',
          ),
          TestCaseModel(
            id: 'tc-2',
            input: 'reverseList([])',
            expectedOutput: '[]',
          ),
        ],
      ),
      QuestionModel(
        id: 'q-ds-3',
        quizId: 'quiz-data-structures',
        type: QuestionType.multipleChoice,
        questionText:
            'In a binary search tree, where is the smallest element located?',
        options: const [
          AnswerOptionModel(id: 'opt-1', text: 'Root node', isCorrect: false),
          AnswerOptionModel(
            id: 'opt-2',
            text: 'Leftmost leaf node',
            isCorrect: true,
          ),
          AnswerOptionModel(
            id: 'opt-3',
            text: 'Rightmost leaf node',
            isCorrect: false,
          ),
          AnswerOptionModel(
            id: 'opt-4',
            text: 'Any leaf node',
            isCorrect: false,
          ),
        ],
        correctAnswers: const ['opt-2'],
        explanation:
            'In a BST, smaller values go left, so the smallest is the leftmost node.',
        points: 4,
        order: 2,
      ),
      QuestionModel(
        id: 'q-ds-4',
        quizId: 'quiz-data-structures',
        type: QuestionType.trueFalse,
        questionText: 'A stack follows FIFO (First-In-First-Out) principle.',
        options: const [
          AnswerOptionModel(id: 'true', text: 'True', isCorrect: false),
          AnswerOptionModel(id: 'false', text: 'False', isCorrect: true),
        ],
        correctAnswers: const ['false'],
        explanation:
            'A stack follows LIFO (Last-In-First-Out). Queues follow FIFO.',
        points: 3,
        order: 3,
      ),
      QuestionModel(
        id: 'q-ds-5',
        quizId: 'quiz-data-structures',
        type: QuestionType.multipleChoice,
        questionText: 'What is the space complexity of merge sort?',
        options: const [
          AnswerOptionModel(id: 'opt-1', text: 'O(1)', isCorrect: false),
          AnswerOptionModel(id: 'opt-2', text: 'O(log n)', isCorrect: false),
          AnswerOptionModel(id: 'opt-3', text: 'O(n)', isCorrect: true),
          AnswerOptionModel(id: 'opt-4', text: 'O(n log n)', isCorrect: false),
        ],
        correctAnswers: const ['opt-3'],
        explanation:
            'Merge sort requires O(n) auxiliary space for the temporary arrays.',
        points: 4,
        order: 4,
      ),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Quiz Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all quizzes for a course
  Future<List<QuizModel>> getQuizzesByCourse(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _quizzes.values
          .where((q) => q.courseId == courseId && q.isPublished)
          .toList();
    }

    try {
      final snapshot = await _firestore!
          .collection(FirestorePaths.quizzes)
          .where('courseId', isEqualTo: courseId)
          .where('isPublished', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => QuizModel.fromMap(doc.data())).toList();
    } catch (e) {
      if (kDebugMode) log('Error fetching quizzes: $e', name: 'QuizRepository');
      return [];
    }
  }

  /// Get a specific quiz
  Future<QuizModel?> getQuiz(String quizId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _quizzes[quizId];
    }

    try {
      final doc = await _firestore!
          .collection(FirestorePaths.quizzes)
          .doc(quizId)
          .get();

      if (!doc.exists) return null;
      return QuizModel.fromMap(doc.data()!);
    } catch (e) {
      if (kDebugMode) log('Error fetching quiz: $e', name: 'QuizRepository');
      return null;
    }
  }

  /// Get quiz by lesson ID
  Future<QuizModel?> getQuizByLesson(String lessonId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        return _quizzes.values.firstWhere((q) => q.lessonId == lessonId);
      } catch (_) {
        return null; // No quiz found for this lesson
      }
    }

    try {
      final snapshot = await _firestore!
          .collection(FirestorePaths.quizzes)
          .where('lessonId', isEqualTo: lessonId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return QuizModel.fromMap(snapshot.docs.first.data());
    } catch (e) {
      if (kDebugMode)
        log('Error fetching quiz by lesson: $e', name: 'QuizRepository');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Question Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all questions for a quiz
  Future<List<QuestionModel>> getQuestions(String quizId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (EnvironmentConfig.isDemoMode) {
      final questions = _questionsByQuiz[quizId] ?? [];
      return List.from(questions)..sort((a, b) => a.order.compareTo(b.order));
    }

    return [];
  }

  /// Get a specific question
  Future<QuestionModel?> getQuestion(String quizId, String questionId) async {
    await Future.delayed(const Duration(milliseconds: 100));

    if (EnvironmentConfig.isDemoMode) {
      final questions = _questionsByQuiz[quizId] ?? [];
      try {
        return questions.firstWhere((q) => q.id == questionId);
      } catch (_) {
        return null; // Question not found
      }
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Attempt Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start a new quiz attempt
  Future<QuizAttemptModel> startAttempt({
    required String quizId,
    required String userId,
    String? enrollmentId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final quiz = await getQuiz(quizId);
    if (quiz == null) {
      throw Exception('Quiz not found');
    }

    // Check attempt limits
    final existingAttempts = await getAttempts(quizId: quizId, userId: userId);
    if (quiz.maxAttempts > 0 && existingAttempts.length >= quiz.maxAttempts) {
      throw Exception('Maximum attempts reached');
    }

    final attemptId = 'attempt-${DateTime.now().millisecondsSinceEpoch}';
    final attempt = QuizAttemptModel(
      id: attemptId,
      quizId: quizId,
      userId: userId,
      enrollmentId: enrollmentId,
      status: AttemptStatus.inProgress,
      attemptNumber: existingAttempts.length + 1,
      startedAt: DateTime.now(),
      totalPoints: quiz.totalPoints,
    );

    if (EnvironmentConfig.isDemoMode) {
      _attemptsByUser.putIfAbsent(userId, () => []);
      _attemptsByUser[userId]!.add(attempt);
    }

    return attempt;
  }

  /// Get attempts for a user/quiz
  Future<List<QuizAttemptModel>> getAttempts({
    required String quizId,
    required String userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    if (EnvironmentConfig.isDemoMode) {
      final userAttempts = _attemptsByUser[userId] ?? [];
      return userAttempts.where((a) => a.quizId == quizId).toList();
    }

    return [];
  }

  /// Get a specific attempt
  Future<QuizAttemptModel?> getAttempt(String attemptId) async {
    await Future.delayed(const Duration(milliseconds: 100));

    if (EnvironmentConfig.isDemoMode) {
      for (final attempts in _attemptsByUser.values) {
        for (final attempt in attempts) {
          if (attempt.id == attemptId) {
            return attempt;
          }
        }
      }
    }

    return null;
  }

  /// Save an answer during the quiz
  Future<QuizAttemptModel> saveAnswer({
    required String attemptId,
    required String questionId,
    List<String>? selectedAnswers,
    String? textAnswer,
    String? codeAnswer,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final attempt = await getAttempt(attemptId);
    if (attempt == null) {
      throw Exception('Attempt not found');
    }

    final answer = UserAnswerModel(
      questionId: questionId,
      selectedAnswers: selectedAnswers ?? [],
      textAnswer: textAnswer,
      codeAnswer: codeAnswer,
      answeredAt: DateTime.now(),
    );

    final updatedAnswers = Map<String, UserAnswerModel>.from(attempt.answers);
    updatedAnswers[questionId] = answer;

    final updatedAttempt = attempt.copyWith(answers: updatedAnswers);

    if (EnvironmentConfig.isDemoMode) {
      _updateAttempt(updatedAttempt);
    }

    return updatedAttempt;
  }

  /// Submit and grade the quiz
  Future<QuizAttemptModel> submitAttempt(String attemptId) async {
    await Future.delayed(const Duration(milliseconds: 500));

    var attempt = await getAttempt(attemptId);
    if (attempt == null) {
      throw Exception('Attempt not found');
    }

    final quiz = await getQuiz(attempt.quizId);
    if (quiz == null) {
      throw Exception('Quiz not found');
    }

    final questions = await getQuestions(attempt.quizId);

    // Grade each answer
    int totalScore = 0;
    final gradedAnswers = <String, UserAnswerModel>{};

    for (final question in questions) {
      final userAnswer = attempt.answers[question.id];
      if (userAnswer == null) {
        // No answer provided
        gradedAnswers[question.id] = UserAnswerModel(
          questionId: question.id,
          isCorrect: false,
          pointsEarned: 0,
          maxPoints: question.points,
          feedback: 'No answer provided',
          answeredAt: DateTime.now(),
        );
        continue;
      }

      final gradeResult = _gradeQuestion(question, userAnswer);
      totalScore += gradeResult.pointsEarned;
      gradedAnswers[question.id] = gradeResult;
    }

    final percentage = quiz.totalPoints > 0
        ? (totalScore / quiz.totalPoints * 100)
        : 0.0;
    final passed = percentage >= quiz.passingScore;
    final timeSpent = DateTime.now().difference(attempt.startedAt).inSeconds;

    final gradedAttempt = attempt.copyWith(
      status: AttemptStatus.graded,
      submittedAt: DateTime.now(),
      gradedAt: DateTime.now(),
      score: totalScore,
      percentage: percentage,
      passed: passed,
      timeSpentSeconds: timeSpent,
      answers: gradedAnswers,
    );

    if (EnvironmentConfig.isDemoMode) {
      _updateAttempt(gradedAttempt);
    }

    return gradedAttempt;
  }

  /// Grade a single question
  UserAnswerModel _gradeQuestion(
    QuestionModel question,
    UserAnswerModel answer,
  ) {
    bool isCorrect = false;
    String feedback = '';

    switch (question.type) {
      case QuestionType.multipleChoice:
      case QuestionType.trueFalse:
        isCorrect =
            answer.selectedAnswers.length == 1 &&
            question.correctAnswers.contains(answer.selectedAnswers.first);
        feedback = isCorrect
            ? 'Correct!'
            : 'Incorrect. ${question.explanation ?? ''}';
        break;

      case QuestionType.multipleSelect:
        final selectedSet = answer.selectedAnswers.toSet();
        final correctSet = question.correctAnswers.toSet();
        isCorrect =
            selectedSet.length == correctSet.length &&
            selectedSet.containsAll(correctSet);
        feedback = isCorrect
            ? 'Correct!'
            : 'Incorrect. You needed to select: ${question.correctAnswers.length} options. ${question.explanation ?? ''}';
        break;

      case QuestionType.shortAnswer:
        final userText = answer.textAnswer?.trim().toLowerCase() ?? '';
        isCorrect = question.correctAnswers.any(
          (a) => a.toLowerCase() == userText,
        );
        feedback = isCorrect
            ? 'Correct!'
            : 'Incorrect. Expected: ${question.correctAnswers.join(' or ')}';
        break;

      case QuestionType.coding:
        // Simplified grading for demo - check if answer contains key parts
        final userCode = answer.codeAnswer?.trim() ?? '';
        isCorrect = question.correctAnswers.any(
          (a) => userCode.contains(a.trim()),
        );
        feedback = isCorrect
            ? 'Code looks correct!'
            : 'Code needs revision. ${question.explanation ?? ''}';
        break;
    }

    return answer.copyWith(
      isCorrect: isCorrect,
      pointsEarned: isCorrect ? question.points : 0,
      maxPoints: question.points,
      feedback: feedback,
    );
  }

  void _updateAttempt(QuizAttemptModel attempt) {
    final userAttempts = _attemptsByUser[attempt.userId];
    if (userAttempts != null) {
      final index = userAttempts.indexWhere((a) => a.id == attempt.id);
      if (index != -1) {
        userAttempts[index] = attempt;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Statistics
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get user's best score for a quiz
  Future<QuizAttemptModel?> getBestAttempt({
    required String quizId,
    required String userId,
  }) async {
    final attempts = await getAttempts(quizId: quizId, userId: userId);
    if (attempts.isEmpty) return null;

    final gradedAttempts = attempts
        .where((a) => a.status == AttemptStatus.graded)
        .toList();
    if (gradedAttempts.isEmpty) return null;

    gradedAttempts.sort((a, b) => b.percentage.compareTo(a.percentage));
    return gradedAttempts.first;
  }

  /// Check if user has passed a quiz
  Future<bool> hasPassedQuiz({
    required String quizId,
    required String userId,
  }) async {
    final attempts = await getAttempts(quizId: quizId, userId: userId);
    return attempts.any((a) => a.passed);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Quiz CRUD Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a new quiz
  Future<void> createQuiz(QuizModel quiz) async {
    if (EnvironmentConfig.isDemoMode) {
      _quizzes[quiz.id] = quiz;
      return;
    }

    await _firestore!
        .collection(FirestorePaths.quizzes)
        .doc(quiz.id)
        .set(quiz.toMap());
  }

  /// Update an existing quiz
  Future<void> updateQuiz(QuizModel quiz) async {
    if (EnvironmentConfig.isDemoMode) {
      _quizzes[quiz.id] = quiz;
      return;
    }

    await _firestore!
        .collection(FirestorePaths.quizzes)
        .doc(quiz.id)
        .update(quiz.toMap());
  }

  /// Delete a quiz
  Future<void> deleteQuiz(String quizId) async {
    if (EnvironmentConfig.isDemoMode) {
      _quizzes.remove(quizId);
      _questionsByQuiz.remove(quizId);
      return;
    }

    // Delete all questions first
    final questionsSnapshot = await _firestore!
        .collection(FirestorePaths.questions)
        .where('quizId', isEqualTo: quizId)
        .get();

    final batch = _firestore.batch();
    for (final doc in questionsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection(FirestorePaths.quizzes).doc(quizId));
    await batch.commit();
  }

  /// Save a question (create or update)
  Future<void> saveQuestion(QuestionModel question) async {
    if (EnvironmentConfig.isDemoMode) {
      final questions = _questionsByQuiz[question.quizId] ?? [];
      final index = questions.indexWhere((q) => q.id == question.id);
      if (index >= 0) {
        questions[index] = question;
      } else {
        questions.add(question);
      }
      _questionsByQuiz[question.quizId] = questions;
      return;
    }

    await _firestore!
        .collection(FirestorePaths.questions)
        .doc(question.id)
        .set(question.toMap());
  }

  /// Delete a question
  Future<void> deleteQuestion(String quizId, String questionId) async {
    if (EnvironmentConfig.isDemoMode) {
      final questions = _questionsByQuiz[quizId] ?? [];
      questions.removeWhere((q) => q.id == questionId);
      return;
    }

    await _firestore!
        .collection(FirestorePaths.questions)
        .doc(questionId)
        .delete();
  }
}
