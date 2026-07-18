import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../models/models.dart';

/// Repository for quiz operations.
class QuizRepository {
  static const String _quizzesTable = 'quizzes';
  static const String _questionsTable = 'questions';
  static const String _attemptsTable = 'quiz_attempts';
  static const String _answersTable = 'quiz_answers';

  final SupabaseClient? _supabase;

  // Demo data storage
  final Map<String, QuizModel> _quizzes = {};
  final Map<String, List<QuestionModel>> _questionsByQuiz = {};
  final Map<String, List<QuizAttemptModel>> _attemptsByUser = {};

  QuizRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client) {
    if (EnvironmentConfig.isDemoMode) {
      _initDemoData();
    }
  }

  Map<String, dynamic> _rowToQuizMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'courseId': row['course_id'],
      'lessonId': row['lesson_id'],
      'title': row['title'],
      'description': row['description'],
      'timeLimitMinutes': row['time_limit_minutes'],
      'passingScore': row['passing_score'],
      'totalPoints': row['total_points'],
      'questionCount': row['question_count'],
      'shuffleQuestions': row['shuffle_questions'],
      'shuffleAnswers': row['shuffle_answers'],
      'showCorrectAnswers': row['show_correct_answers'],
      'allowRetakes': row['allow_retakes'],
      'maxAttempts': row['max_attempts'],
      'isPublished': row['is_published'],
      'createdAt': row['created_at']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
    };
  }

  QuizModel _quizFromRow(Map<String, dynamic> row) =>
      QuizModel.fromMap(_rowToQuizMap(row));

  Map<String, dynamic> _rowToQuestionMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'quizId': row['quiz_id'],
      'type': row['question_type'],
      'questionText': row['prompt'],
      'questionCode': row['question_code'],
      'codeLanguage': row['code_language'],
      'options': row['options'] ?? const [],
      'correctAnswers': row['correct_answer'] ?? const [],
      'explanation': row['explanation'],
      'points': row['points'],
      'order': row['sort_order'],
      'hint': row['hint'],
      'testCases': row['test_cases'] ?? const [],
    };
  }

  QuestionModel _questionFromRow(Map<String, dynamic> row) =>
      QuestionModel.fromMap(_rowToQuestionMap(row));

  Map<String, dynamic> _rowToAttemptMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'quizId': row['quiz_id'],
      'userId': row['user_id'],
      'enrollmentId': row['enrollment_id'],
      'status': row['status'],
      'attemptNumber': row['attempt_number'],
      'startedAt': row['started_at']?.toString(),
      'submittedAt': row['submitted_at']?.toString(),
      'gradedAt': row['graded_at']?.toString(),
      'score': row['score'],
      'totalPoints': row['total_points'],
      'percentage': row['percentage'],
      'passed': row['passed'],
      'timeSpentSeconds': row['time_spent_seconds'],
      'answers': row['answers'] ?? const {},
    };
  }

  QuizAttemptModel _attemptFromRow(Map<String, dynamic> row) =>
      QuizAttemptModel.fromMap(_rowToAttemptMap(row));

  void _initDemoData() {
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
    ];
  }

  Future<List<QuizModel>> getQuizzesByCourse(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _quizzes.values
          .where((q) => q.courseId == courseId && q.isPublished)
          .toList();
    }

    try {
      final rows = await _supabase!
          .from(_quizzesTable)
          .select()
          .eq('course_id', courseId)
          .eq('is_published', true)
          .order('created_at', ascending: false);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_quizFromRow)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching quizzes: $e', name: 'QuizRepository');
      }
      return [];
    }
  }

  Future<QuizModel?> getQuiz(String quizId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _quizzes[quizId];
    }

    try {
      final row = await _supabase!
          .from(_quizzesTable)
          .select()
          .eq('id', quizId)
          .maybeSingle();
      if (row == null) return null;
      return _quizFromRow(row);
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching quiz: $e', name: 'QuizRepository');
      }
      return null;
    }
  }

  Future<QuizModel?> getQuizByLesson(String lessonId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        return _quizzes.values.firstWhere((q) => q.lessonId == lessonId);
      } catch (_) {
        return null;
      }
    }

    try {
      final row = await _supabase!
          .from(_quizzesTable)
          .select()
          .eq('lesson_id', lessonId)
          .maybeSingle();
      if (row == null) return null;
      return _quizFromRow(row);
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching quiz by lesson: $e', name: 'QuizRepository');
      }
      return null;
    }
  }

  Future<List<QuestionModel>> getQuestions(String quizId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final questions = _questionsByQuiz[quizId] ?? [];
      return List.from(questions)..sort((a, b) => a.order.compareTo(b.order));
    }

    try {
      final rows = await _supabase!
          .from(_questionsTable)
          .select()
          .eq('quiz_id', quizId)
          .order('sort_order', ascending: true);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_questionFromRow)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<QuestionModel?> getQuestion(String quizId, String questionId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 100));
      final questions = _questionsByQuiz[quizId] ?? [];
      try {
        return questions.firstWhere((q) => q.id == questionId);
      } catch (_) {
        return null;
      }
    }

    try {
      final row = await _supabase!
          .from(_questionsTable)
          .select()
          .eq('quiz_id', quizId)
          .eq('id', questionId)
          .maybeSingle();
      if (row == null) return null;
      return _questionFromRow(row);
    } catch (_) {
      return null;
    }
  }

  Future<QuizAttemptModel> startAttempt({
    required String quizId,
    required String userId,
    String? enrollmentId,
  }) async {
    final quiz = await getQuiz(quizId);
    if (quiz == null) {
      throw Exception('Quiz not found');
    }

    final existingAttempts = await getAttempts(quizId: quizId, userId: userId);
    if (quiz.maxAttempts > 0 && existingAttempts.length >= quiz.maxAttempts) {
      throw Exception('Maximum attempts reached');
    }

    final attempt = QuizAttemptModel(
      id: 'attempt-${DateTime.now().millisecondsSinceEpoch}',
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
      return attempt;
    }

    final inserted = await _supabase!.from(_attemptsTable).insert({
      'quiz_id': attempt.quizId,
      'user_id': attempt.userId,
      'enrollment_id': attempt.enrollmentId,
      'status': attempt.status.name,
      'attempt_number': attempt.attemptNumber,
      'started_at': attempt.startedAt.toIso8601String(),
      'score': attempt.score,
      'total_points': attempt.totalPoints,
      'percentage': attempt.percentage,
      'passed': attempt.passed,
      'time_spent_seconds': attempt.timeSpentSeconds,
      'answers': attempt.answers.map((k, v) => MapEntry(k, v.toMap())),
    }).select().single();

    return _attemptFromRow(inserted);
  }

  Future<List<QuizAttemptModel>> getAttempts({
    required String quizId,
    required String userId,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      final userAttempts = _attemptsByUser[userId] ?? [];
      return userAttempts.where((a) => a.quizId == quizId).toList();
    }

    try {
      final rows = await _supabase!
          .from(_attemptsTable)
          .select()
          .eq('quiz_id', quizId)
          .eq('user_id', userId)
          .order('attempt_number', ascending: true);
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_attemptFromRow)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<QuizAttemptModel?> getAttempt(String attemptId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 100));
      for (final attempts in _attemptsByUser.values) {
        for (final attempt in attempts) {
          if (attempt.id == attemptId) return attempt;
        }
      }
      return null;
    }

    try {
      final row = await _supabase!
          .from(_attemptsTable)
          .select()
          .eq('id', attemptId)
          .maybeSingle();
      if (row == null) return null;
      return _attemptFromRow(row);
    } catch (_) {
      return null;
    }
  }

  Future<QuizAttemptModel> saveAnswer({
    required String attemptId,
    required String questionId,
    List<String>? selectedAnswers,
    String? textAnswer,
    String? codeAnswer,
  }) async {
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
      return updatedAttempt;
    }

    await _supabase!
        .from(_attemptsTable)
        .update({
          'answers': updatedAttempt.answers.map(
            (k, v) => MapEntry(k, v.toMap()),
          ),
        })
        .eq('id', attemptId);

    return updatedAttempt;
  }

  Future<QuizAttemptModel> submitAttempt(String attemptId) async {
    var attempt = await getAttempt(attemptId);
    if (attempt == null) {
      throw Exception('Attempt not found');
    }

    final quiz = await getQuiz(attempt.quizId);
    if (quiz == null) {
      throw Exception('Quiz not found');
    }

    final questions = await getQuestions(attempt.quizId);
    int totalScore = 0;
    final gradedAnswers = <String, UserAnswerModel>{};

    for (final question in questions) {
      final userAnswer = attempt.answers[question.id];
      if (userAnswer == null) {
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
      return gradedAttempt;
    }

    await _supabase!
        .from(_attemptsTable)
        .update({
          'status': gradedAttempt.status.name,
          'submitted_at': gradedAttempt.submittedAt?.toIso8601String(),
          'graded_at': gradedAttempt.gradedAt?.toIso8601String(),
          'score': gradedAttempt.score,
          'percentage': gradedAttempt.percentage,
          'passed': gradedAttempt.passed,
          'time_spent_seconds': gradedAttempt.timeSpentSeconds,
          'answers': gradedAttempt.answers.map(
            (k, v) => MapEntry(k, v.toMap()),
          ),
        })
        .eq('id', attemptId);

    return gradedAttempt;
  }

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

  Future<QuizAttemptModel?> getBestAttempt({
    required String quizId,
    required String userId,
  }) async {
    final attempts = await getAttempts(quizId: quizId, userId: userId);
    final gradedAttempts = attempts
        .where((a) => a.status == AttemptStatus.graded)
        .toList();
    if (gradedAttempts.isEmpty) return null;
    gradedAttempts.sort((a, b) => b.percentage.compareTo(a.percentage));
    return gradedAttempts.first;
  }

  Future<bool> hasPassedQuiz({
    required String quizId,
    required String userId,
  }) async {
    final attempts = await getAttempts(quizId: quizId, userId: userId);
    return attempts.any((a) => a.passed);
  }

  Future<void> createQuiz(QuizModel quiz) async {
    if (EnvironmentConfig.isDemoMode) {
      _quizzes[quiz.id] = quiz;
      return;
    }

    await _supabase!.from(_quizzesTable).upsert({
      'id': quiz.id,
      'course_id': quiz.courseId,
      'lesson_id': quiz.lessonId,
      'title': quiz.title,
      'description': quiz.description,
      'time_limit_minutes': quiz.timeLimitMinutes,
      'passing_score': quiz.passingScore,
      'total_points': quiz.totalPoints,
      'question_count': quiz.questionCount,
      'shuffle_questions': quiz.shuffleQuestions,
      'shuffle_answers': quiz.shuffleAnswers,
      'show_correct_answers': quiz.showCorrectAnswers,
      'allow_retakes': quiz.allowRetakes,
      'max_attempts': quiz.maxAttempts,
      'is_published': quiz.isPublished,
      'created_at': quiz.createdAt.toIso8601String(),
      'updated_at': quiz.updatedAt?.toIso8601String(),
    });
  }

  Future<void> updateQuiz(QuizModel quiz) async {
    if (EnvironmentConfig.isDemoMode) {
      _quizzes[quiz.id] = quiz;
      return;
    }

    await _supabase!
        .from(_quizzesTable)
        .update({
          'course_id': quiz.courseId,
          'lesson_id': quiz.lessonId,
          'title': quiz.title,
          'description': quiz.description,
          'time_limit_minutes': quiz.timeLimitMinutes,
          'passing_score': quiz.passingScore,
          'total_points': quiz.totalPoints,
          'question_count': quiz.questionCount,
          'shuffle_questions': quiz.shuffleQuestions,
          'shuffle_answers': quiz.shuffleAnswers,
          'show_correct_answers': quiz.showCorrectAnswers,
          'allow_retakes': quiz.allowRetakes,
          'max_attempts': quiz.maxAttempts,
          'is_published': quiz.isPublished,
          'updated_at':
              quiz.updatedAt?.toIso8601String() ??
              DateTime.now().toIso8601String(),
        })
        .eq('id', quiz.id);
  }

  Future<void> deleteQuiz(String quizId) async {
    if (EnvironmentConfig.isDemoMode) {
      _quizzes.remove(quizId);
      _questionsByQuiz.remove(quizId);
      return;
    }

    await _supabase!.from(_questionsTable).delete().eq('quiz_id', quizId);
    await _supabase!.from(_attemptsTable).delete().eq('quiz_id', quizId);
    await _supabase!.from(_quizzesTable).delete().eq('id', quizId);
  }

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

    await _supabase!.from(_questionsTable).upsert({
      'id': question.id,
      'quiz_id': question.quizId,
      'question_type': question.type.name,
      'prompt': question.questionText,
      'question_code': question.questionCode,
      'code_language': question.codeLanguage,
      'options': question.options.map((e) => e.toMap()).toList(),
      'correct_answer': question.correctAnswers,
      'explanation': question.explanation,
      'points': question.points,
      'sort_order': question.order,
      'hint': question.hint,
      'test_cases': question.testCases?.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> deleteQuestion(String quizId, String questionId) async {
    if (EnvironmentConfig.isDemoMode) {
      final questions = _questionsByQuiz[quizId] ?? [];
      questions.removeWhere((q) => q.id == questionId);
      return;
    }

    await _supabase!.from(_questionsTable).delete().eq('id', questionId);
  }
}
