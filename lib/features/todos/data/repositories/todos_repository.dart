import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/router/app_routes.dart';
import '../models/models.dart';

class TodosRepository {
  static const String _todosTable = 'todos';

  final SupabaseClient? _supabase;
  final List<TodoModel> _demoStudentTodos = [];
  final List<TodoModel> _demoInstructorTodos = [];
  final _todosController = StreamController<List<TodoModel>>.broadcast();

  Stream<List<TodoModel>> get todosStream => _todosController.stream;

  TodosRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client) {
    if (EnvironmentConfig.isDemoMode) {
      _initDemo();
    }
  }

  void _initDemo() {
    final now = DateTime.now();
    _demoStudentTodos.addAll([
      TodoModel(
        id: 'student-assignment-1',
        name: 'Submit Flutter State Management project',
        isCompleted: false,
        dueAtIso: now.add(const Duration(days: 2)).toIso8601String(),
        createdAt: now.subtract(const Duration(days: 3)),
        taskType: TodoTaskType.assignment,
        courseId: 'course-1',
        courseName: 'Flutter Development',
        actionUrl: AppRoutes.submitAssignmentPath('course-1', 'assignment-1'),
      ),
      TodoModel(
        id: 'student-quiz-1',
        name: 'Complete Dart fundamentals quiz',
        isCompleted: false,
        createdAt: now.subtract(const Duration(days: 1)),
        taskType: TodoTaskType.quiz,
        courseId: 'course-1',
        courseName: 'Flutter Development',
        actionUrl: AppRoutes.quizPath('course-1', 'quiz-1'),
      ),
      TodoModel(
        id: 'student-lesson-1',
        name: 'Review widget lifecycle',
        isCompleted: true,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 1)),
        taskType: TodoTaskType.lesson,
        courseId: 'course-1',
        courseName: 'Flutter Development',
        actionUrl: AppRoutes.lessonPath('course-1', 'lesson-1'),
      ),
    ]);
    _demoInstructorTodos.addAll([
      TodoModel(
        id: 'instructor-submission-1',
        name: 'Grade Flutter State Management project — Alex Student',
        isCompleted: false,
        createdAt: now.subtract(const Duration(hours: 2)),
        taskType: TodoTaskType.grading,
        courseId: 'course-1',
        courseName: 'Flutter Development',
        actionUrl: AppRoutes.gradeAssignmentPath('course-1', 'assignment-1'),
      ),
      TodoModel(
        id: 'instructor-draft-1',
        name: 'Publish async programming lesson',
        isCompleted: false,
        createdAt: now.subtract(const Duration(days: 1)),
        taskType: TodoTaskType.draftLesson,
        courseId: 'course-1',
        courseName: 'Flutter Development',
        actionUrl: AppRoutes.editLessonPath('course-1', 'lesson-2'),
      ),
      TodoModel(
        id: 'instructor-submission-2',
        name: 'Grade Dart fundamentals quiz app — Jamie Student',
        isCompleted: true,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
        taskType: TodoTaskType.grading,
        courseId: 'course-1',
        courseName: 'Flutter Development',
        actionUrl: AppRoutes.gradeAssignmentPath('course-1', 'assignment-2'),
      ),
    ]);
  }

  Future<List<TodoModel>> getTodos({required TodoAudience audience}) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 250));
      return List.unmodifiable(
        audience == TodoAudience.instructor
            ? _demoInstructorTodos
            : _demoStudentTodos,
      );
    }

    final userId = _supabase!.auth.currentUser?.id;
    if (userId == null) {
      return const [];
    }

    final manualTodos = await _getManualTodos(userId);
    List<TodoModel> generatedTodos;
    try {
      generatedTodos = audience == TodoAudience.instructor
          ? await _getInstructorWorkQueue(userId)
          : await _getStudentCoursework(userId);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to generate ${audience.name} todo items: $error');
      }
      generatedTodos = const [];
    }

    return List.unmodifiable([...manualTodos, ...generatedTodos]);
  }

  Future<List<TodoModel>> _getManualTodos(String userId) async {
    final rows = await _supabase!
        .from(_todosTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return _asRows(rows)
        .map((row) => TodoModel.fromMap(row, row['id'] as String))
        .toList(growable: false);
  }

  Future<List<TodoModel>> _getStudentCoursework(String userId) async {
    final supabase = _supabase!;
    final enrollmentRows = _asRows(
      await supabase
          .from('enrollments')
          .select('id,course_id')
          .eq('user_id', userId),
    );
    if (enrollmentRows.isEmpty) return const [];

    final courseIds = enrollmentRows
        .map((row) => row['course_id'] as String)
        .toSet()
        .toList(growable: false);
    final enrollmentIds = enrollmentRows
        .map((row) => row['id'] as String)
        .toList(growable: false);
    final courseNames = await _getCourseNames(courseIds);

    final assignmentRows = _asRows(
      await supabase
          .from('assignments')
          .select('id,course_id,title,due_date,created_at,updated_at')
          .inFilter('course_id', courseIds)
          .eq('is_published', true),
    );
    final submissionRows = _asRows(
      await supabase
          .from('submissions')
          .select('assignment_id,status,submitted_at,updated_at')
          .eq('user_id', userId)
          .inFilter('course_id', courseIds),
    );
    final submissionsByAssignment = {
      for (final row in submissionRows) row['assignment_id'] as String: row,
    };

    final lessonRows = _asRows(
      await supabase
          .from('lessons')
          .select('id,course_id,title,created_at,updated_at')
          .inFilter('course_id', courseIds)
          .eq('is_published', true),
    );
    final progressRows = _asRows(
      await supabase
          .from('lesson_progress')
          .select('lesson_id,is_completed,completed_at,last_accessed_at')
          .eq('user_id', userId)
          .inFilter('enrollment_id', enrollmentIds),
    );
    final progressByLesson = {
      for (final row in progressRows) row['lesson_id'] as String: row,
    };

    final quizRows = _asRows(
      await supabase
          .from('quizzes')
          .select('id,course_id,title,created_at,updated_at')
          .inFilter('course_id', courseIds)
          .eq('is_published', true),
    );
    final quizIds = quizRows
        .map((row) => row['id'] as String)
        .toList(growable: false);
    final attemptRows = quizIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _asRows(
            await supabase
                .from('quiz_attempts')
                .select('quiz_id,status,submitted_at,graded_at,started_at')
                .eq('user_id', userId)
                .inFilter('quiz_id', quizIds),
          );
    final attemptsByQuiz = <String, List<Map<String, dynamic>>>{};
    for (final row in attemptRows) {
      attemptsByQuiz.putIfAbsent(row['quiz_id'] as String, () => []).add(row);
    }

    return [
      ...assignmentRows.map((row) {
        final assignmentId = row['id'] as String;
        final courseId = row['course_id'] as String;
        final submission = submissionsByAssignment[assignmentId];
        final status = submission?['status']?.toString();
        final isCompleted = const {
          'submitted',
          'grading',
          'graded',
          'returned',
          'done',
        }.contains(status);
        return TodoModel(
          id: 'assignment:$assignmentId',
          name: row['title'] as String,
          isCompleted: isCompleted,
          dueAtIso: row['due_date']?.toString(),
          createdAt: _timestamp(row['created_at']),
          updatedAt: _optionalTimestamp(
            submission?['updated_at'] ?? row['updated_at'],
          ),
          taskType: TodoTaskType.assignment,
          courseId: courseId,
          courseName: courseNames[courseId],
          actionUrl: AppRoutes.submitAssignmentPath(courseId, assignmentId),
        );
      }),
      ...lessonRows.map((row) {
        final lessonId = row['id'] as String;
        final courseId = row['course_id'] as String;
        final progress = progressByLesson[lessonId];
        return TodoModel(
          id: 'lesson:$lessonId',
          name: row['title'] as String,
          isCompleted: progress?['is_completed'] as bool? ?? false,
          createdAt: _timestamp(row['created_at']),
          updatedAt: _optionalTimestamp(
            progress?['completed_at'] ??
                progress?['last_accessed_at'] ??
                row['updated_at'],
          ),
          taskType: TodoTaskType.lesson,
          courseId: courseId,
          courseName: courseNames[courseId],
          actionUrl: AppRoutes.lessonPath(courseId, lessonId),
        );
      }),
      ...quizRows.map((row) {
        final quizId = row['id'] as String;
        final courseId = row['course_id'] as String;
        final attempts = attemptsByQuiz[quizId] ?? const [];
        final isCompleted = attempts.any(
          (attempt) => const {
            'submitted',
            'graded',
            'timedOut',
          }.contains(attempt['status']?.toString()),
        );
        return TodoModel(
          id: 'quiz:$quizId',
          name: row['title'] as String,
          isCompleted: isCompleted,
          createdAt: _timestamp(row['created_at']),
          updatedAt: _latestAttemptTimestamp(attempts),
          taskType: TodoTaskType.quiz,
          courseId: courseId,
          courseName: courseNames[courseId],
          actionUrl: AppRoutes.quizPath(courseId, quizId),
        );
      }),
    ];
  }

  Future<List<TodoModel>> _getInstructorWorkQueue(String userId) async {
    final supabase = _supabase!;
    final courseRows = _asRows(
      await supabase
          .from('courses')
          .select('id,title,is_published,created_at,updated_at')
          .eq('instructor_id', userId),
    );
    if (courseRows.isEmpty) return const [];

    final courseIds = courseRows
        .map((row) => row['id'] as String)
        .toList(growable: false);
    final courseNames = {
      for (final row in courseRows) row['id'] as String: row['title'] as String,
    };
    final assignmentRows = _asRows(
      await supabase
          .from('assignments')
          .select(
            'id,course_id,title,due_date,is_published,created_at,updated_at',
          )
          .inFilter('course_id', courseIds),
    );
    final assignmentsById = {
      for (final row in assignmentRows) row['id'] as String: row,
    };
    final submissionRows = _asRows(
      await supabase
          .from('submissions')
          .select(
            'id,assignment_id,course_id,user_display_name,status,'
            'submitted_at,graded_at,created_at,updated_at',
          )
          .inFilter('course_id', courseIds)
          .neq('status', 'draft')
          .order('updated_at', ascending: false)
          .limit(100),
    );
    final lessonRows = _asRows(
      await supabase
          .from('lessons')
          .select('id,course_id,title,is_published,created_at,updated_at')
          .inFilter('course_id', courseIds)
          .eq('is_published', false),
    );
    final quizRows = _asRows(
      await supabase
          .from('quizzes')
          .select('id,course_id,title,is_published,created_at,updated_at')
          .inFilter('course_id', courseIds)
          .eq('is_published', false),
    );

    return [
      ...submissionRows.map((row) {
        final assignmentId = row['assignment_id'] as String;
        final courseId = row['course_id'] as String;
        final assignmentTitle =
            assignmentsById[assignmentId]?['title'] as String? ?? 'Assignment';
        final studentName =
            row['user_display_name'] as String? ?? 'Student submission';
        final status = row['status']?.toString();
        return TodoModel(
          id: 'submission:${row['id']}',
          name: '$assignmentTitle — $studentName',
          isCompleted: status == 'graded' || status == 'returned',
          dueAtIso: row['submitted_at']?.toString(),
          createdAt: _timestamp(row['created_at']),
          updatedAt: _optionalTimestamp(row['graded_at'] ?? row['updated_at']),
          taskType: TodoTaskType.grading,
          courseId: courseId,
          courseName: courseNames[courseId],
          actionUrl: AppRoutes.gradeAssignmentPath(courseId, assignmentId),
        );
      }),
      ...courseRows.where((row) => row['is_published'] != true).map((row) {
        final courseId = row['id'] as String;
        return TodoModel(
          id: 'draft-course:$courseId',
          name: row['title'] as String,
          isCompleted: false,
          createdAt: _timestamp(row['created_at']),
          updatedAt: _optionalTimestamp(row['updated_at']),
          taskType: TodoTaskType.draftCourse,
          courseId: courseId,
          courseName: row['title'] as String,
          actionUrl: AppRoutes.editCoursePath(courseId),
        );
      }),
      ...assignmentRows
          .where((row) => row['is_published'] != true)
          .map(
            (row) => _draftTodo(
              row: row,
              taskType: TodoTaskType.draftAssignment,
              courseNames: courseNames,
              actionUrl: AppRoutes.editAssignmentPath(
                row['course_id'] as String,
                row['id'] as String,
              ),
            ),
          ),
      ...lessonRows.map(
        (row) => _draftTodo(
          row: row,
          taskType: TodoTaskType.draftLesson,
          courseNames: courseNames,
          actionUrl: AppRoutes.editLessonPath(
            row['course_id'] as String,
            row['id'] as String,
          ),
        ),
      ),
      ...quizRows.map(
        (row) => _draftTodo(
          row: row,
          taskType: TodoTaskType.draftQuiz,
          courseNames: courseNames,
          actionUrl: AppRoutes.editQuizPath(
            row['course_id'] as String,
            row['id'] as String,
          ),
        ),
      ),
    ];
  }

  TodoModel _draftTodo({
    required Map<String, dynamic> row,
    required TodoTaskType taskType,
    required Map<String, String> courseNames,
    required String actionUrl,
  }) {
    final courseId = row['course_id'] as String;
    return TodoModel(
      id: '${taskType.name}:${row['id']}',
      name: row['title'] as String,
      isCompleted: false,
      dueAtIso: row['due_date']?.toString(),
      createdAt: _timestamp(row['created_at']),
      updatedAt: _optionalTimestamp(row['updated_at']),
      taskType: taskType,
      courseId: courseId,
      courseName: courseNames[courseId],
      actionUrl: actionUrl,
    );
  }

  Future<Map<String, String>> _getCourseNames(List<String> courseIds) async {
    final supabase = _supabase!;
    final rows = _asRows(
      await supabase
          .from('courses')
          .select('id,title')
          .inFilter('id', courseIds),
    );
    return {
      for (final row in rows) row['id'] as String: row['title'] as String,
    };
  }

  Future<void> toggleCompleted({required String todoId}) async {
    if (EnvironmentConfig.isDemoMode) {
      for (final todos in [_demoStudentTodos, _demoInstructorTodos]) {
        final index = todos.indexWhere((todo) => todo.id == todoId);
        if (index == -1 || !todos[index].isPersonal) continue;
        todos[index] = todos[index].copyWith(
          isCompleted: !todos[index].isCompleted,
          updatedAt: DateTime.now(),
        );
        _todosController.add(List.unmodifiable(todos));
        return;
      }
      return;
    }

    final supabase = _supabase!;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final current = await supabase
        .from(_todosTable)
        .select('id,is_completed')
        .eq('id', todoId)
        .eq('user_id', userId)
        .maybeSingle();
    if (current == null) return;

    await supabase
        .from(_todosTable)
        .update({
          'is_completed': !(current['is_completed'] as bool? ?? false),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', todoId)
        .eq('user_id', userId);
  }

  Future<void> dispose() async {
    await _todosController.close();
  }
}

List<Map<String, dynamic>> _asRows(Object? rows) {
  return (rows as List<dynamic>)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList(growable: false);
}

DateTime _timestamp(Object? value) {
  return _optionalTimestamp(value) ?? DateTime.now();
}

DateTime? _optionalTimestamp(Object? value) {
  return value == null ? null : DateTime.tryParse(value.toString());
}

DateTime? _latestAttemptTimestamp(List<Map<String, dynamic>> attempts) {
  DateTime? latest;
  for (final attempt in attempts) {
    final timestamp = _optionalTimestamp(
      attempt['graded_at'] ?? attempt['submitted_at'] ?? attempt['started_at'],
    );
    if (timestamp != null && (latest == null || timestamp.isAfter(latest))) {
      latest = timestamp;
    }
  }
  return latest;
}
