import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../models/models.dart';

/// Repository for assignment operations.
class AssignmentRepository {
  static const String _assignmentsTable = 'assignments';
  static const String _submissionsTable = 'submissions';

  static const String _demoStudentUserId = 'demo-user-1';
  static const String _legacyDemoStudentUserId = 'demo_user';

  final SupabaseClient? _supabase;

  // Demo data storage
  final Map<String, AssignmentModel> _assignments = {};
  final Map<String, List<SubmissionModel>> _submissionsByAssignment = {};
  final Map<String, Map<String, SubmissionModel>> _submissionsByUser = {};

  AssignmentRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client) {
    if (EnvironmentConfig.isDemoMode) {
      _initDemoData();
    }
  }

  bool _isDemoStudentAlias(String userId) {
    return userId == _demoStudentUserId || userId == _legacyDemoStudentUserId;
  }

  String _normalizeDemoUserId(String userId) {
    return _isDemoStudentAlias(userId) ? _demoStudentUserId : userId;
  }

  Iterable<String> _demoUserKeys(String userId) sync* {
    final normalized = _normalizeDemoUserId(userId);
    yield normalized;
    if (normalized == _demoStudentUserId) {
      yield _legacyDemoStudentUserId;
    }
  }

  Map<String, dynamic> _rowToAssignmentMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'courseId': row['course_id'],
      'lessonId': row['lesson_id'],
      'title': row['title'],
      'description': row['description'],
      'instructions': row['instructions'],
      'language': row['language'],
      'starterCode': row['starter_code'],
      'solutionCode': row['solution_code'],
      'maxPoints': row['max_points'],
      'dueDate': row['due_date']?.toString(),
      'allowLateSubmission': row['allow_late_submission'],
      'latePenaltyPercent': row['late_penalty_percent'],
      'isPublished': row['is_published'],
      'createdAt': row['created_at']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
    };
  }

  AssignmentModel _assignmentFromRow(Map<String, dynamic> row) {
    return AssignmentModel.fromMap(_rowToAssignmentMap(row));
  }

  Map<String, dynamic> _rowToSubmissionMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'assignmentId': row['assignment_id'],
      'courseId': row['course_id'],
      'userId': row['user_id'],
      'userDisplayName': row['user_display_name'],
      'code': row['code'],
      'status': row['status'],
      'score': row['score'],
      'feedback': row['feedback'],
      'gradedBy': row['graded_by'],
      'gradedAt': row['graded_at']?.toString(),
      'isLate': row['is_late'],
      'createdAt': row['created_at']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
      'submittedAt': row['submitted_at']?.toString(),
    };
  }

  SubmissionModel _submissionFromRow(Map<String, dynamic> row) {
    return SubmissionModel.fromMap(_rowToSubmissionMap(row));
  }

  void _initDemoData() {
    // Flutter Course Assignments
    _assignments['assignment-flutter-1'] = AssignmentModel(
      id: 'assignment-flutter-1',
      courseId: 'course-1',
      lessonId: 'lesson-1-3-1',
      title: 'Build a Counter App',
      description: 'Create a simple counter application using Flutter widgets',
      instructions: '''
# Counter App Assignment

## Objective
Build a simple counter application that demonstrates your understanding of Flutter's StatefulWidget.

## Requirements
1. Display a counter value starting at 0
2. Include a **+** button that increments the counter
3. Include a **-** button that decrements the counter
4. The counter should not go below 0
5. Style the app with a dark theme

## Hints
- Use `StatefulWidget` for managing state
- Use `setState()` to update the counter value
- Consider using `FloatingActionButton` for the buttons

## Submission
Submit your `main.dart` file with the complete counter app implementation.
''',
      language: ProgrammingLanguage.dart,
      starterCode: '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter App',
      theme: ThemeData.dark(),
      home: const CounterPage(),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  // TODO: Add counter variable

  // TODO: Add increment method

  // TODO: Add decrement method

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TODO: Display counter value
            const Text(
              '0',
              style: TextStyle(fontSize: 48),
            ),
          ],
        ),
      ),
      // TODO: Add floating action buttons
    );
  }
}
''',
      maxPoints: 100,
      dueDate: DateTime.now().add(const Duration(days: 7)),
      allowLateSubmission: true,
      latePenaltyPercent: 10,
      isPublished: true,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    );

    _assignments['assignment-flutter-2'] = AssignmentModel(
      id: 'assignment-flutter-2',
      courseId: 'course-1',
      title: 'Todo List App',
      description: 'Build a fully functional todo list application',
      instructions: '''
# Todo List App Assignment

## Objective
Create a todo list application that allows users to add, complete, and delete tasks.

## Requirements
1. Add new todo items via a text input
2. Display all todo items in a list
3. Mark items as complete/incomplete with a checkbox
4. Delete items with a swipe or delete button
5. Show the total count of remaining items

## Bonus Points
- Persist data using SharedPreferences
- Add categories or priority levels
- Implement search/filter functionality

## Submission
Submit your complete project with all Dart files.
''',
      language: ProgrammingLanguage.dart,
      starterCode: '''
import 'package:flutter/material.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo List',
      theme: ThemeData.dark(),
      home: const TodoListPage(),
    );
  }
}

class TodoItem {
  final String id;
  final String title;
  bool isCompleted;

  TodoItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });
}

class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  final List<TodoItem> _todos = [];
  final TextEditingController _controller = TextEditingController();

  // TODO: Implement add todo method

  // TODO: Implement toggle complete method

  // TODO: Implement delete todo method

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
      ),
      body: Column(
        children: [
          // TODO: Add input field for new todos
          // TODO: Display list of todos
        ],
      ),
    );
  }
}
''',
      maxPoints: 150,
      dueDate: DateTime.now().add(const Duration(days: 14)),
      allowLateSubmission: true,
      latePenaltyPercent: 15,
      isPublished: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    );

    _assignments['assignment-dart-1'] = AssignmentModel(
      id: 'assignment-dart-1',
      courseId: 'course-2',
      lessonId: 'lesson-2-1-1',
      title: 'Async Data Fetcher',
      description:
          'Implement an async function that fetches and processes data',
      instructions: '''
# Async Data Fetcher Assignment

## Objective
Practice Dart async/await by building a data-fetching function.

## Requirements
Write a function `fetchUserData(int userId)` that:
1. Returns a `Future<Map<String, dynamic>>`
2. Simulates a network delay of 1 second using `Future.delayed`
3. Returns user data for valid IDs (1–5)
4. Throws an `Exception` for invalid IDs

## Example
```dart
final user = await fetchUserData(1);
print(user); // {id: 1, name: 'Alice', email: 'alice@example.com'}

await fetchUserData(99); // throws Exception('User not found')
```

## Testing
Your solution will be tested with valid and invalid user IDs.
''',
      language: ProgrammingLanguage.dart,
      starterCode: '''
Future<Map<String, dynamic>> fetchUserData(int userId) async {
  // TODO: Simulate a 1-second network delay
  // TODO: Return user data for IDs 1-5
  // TODO: Throw an Exception for invalid IDs
  throw UnimplementedError();
}

void main() async {
  try {
    final user = await fetchUserData(1);
    print('Got user: \$user');

    final invalid = await fetchUserData(99);
    print(invalid);
  } catch (e) {
    print('Error: \$e');
  }
}
''',
      maxPoints: 50,
      dueDate: DateTime.now().add(const Duration(days: 3)),
      allowLateSubmission: false,
      isPublished: true,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    );

    _submissionsByAssignment['assignment-flutter-1'] = [
      SubmissionModel(
        id: 'submission-1',
        assignmentId: 'assignment-flutter-1',
        courseId: 'course-1',
        userId: _demoStudentUserId,
        userDisplayName: 'Demo Student',
        code: '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter App',
      theme: ThemeData.dark(),
      home: const CounterPage(),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _counter = 0;

  void _increment() {
    setState(() {
      _counter++;
    });
  }

  void _decrement() {
    setState(() {
      if (_counter > 0) {
        _counter--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter App'),
      ),
      body: Center(
        child: Text(
          '\$_counter',
          style: TextStyle(fontSize: 48),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _decrement,
            child: Icon(Icons.remove),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: _increment,
            child: Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
''',
        status: SubmissionStatus.graded,
        score: 92,
        feedback: 'Great work on state management and clean widget structure.',
        gradedBy: 'demo-instructor-1',
        gradedAt: DateTime.now().subtract(const Duration(hours: 1)),
        isLate: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];

    _submissionsByUser[_demoStudentUserId] = {
      'assignment-flutter-1':
          _submissionsByAssignment['assignment-flutter-1']!.first,
    };
    _submissionsByUser[_legacyDemoStudentUserId] = {
      'assignment-flutter-1':
          _submissionsByAssignment['assignment-flutter-1']!.first,
    };
  }

  /// Get all assignments for a course
  Future<List<AssignmentModel>> getAssignmentsForCourse(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _assignments.values
          .where((a) => a.courseId == courseId && a.isPublished)
          .toList()
        ..sort(
          (a, b) => a.dueDate?.compareTo(b.dueDate ?? DateTime.now()) ?? 0,
        );
    }

    try {
      final rows = await _supabase!
          .from(_assignmentsTable)
          .select()
          .eq('course_id', courseId)
          .eq('is_published', true)
          .order('due_date', ascending: true);

      final assignments = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_assignmentFromRow)
          .toList();

      assignments.sort(
        (a, b) => a.dueDate?.compareTo(b.dueDate ?? DateTime.now()) ?? 0,
      );

      return assignments;
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching assignments: $e', name: 'AssignmentRepository');
      }
      return [];
    }
  }

  /// Get a single assignment by ID
  Future<AssignmentModel?> getAssignment(String assignmentId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _assignments[assignmentId];
    }

    try {
      final row = await _supabase!
          .from(_assignmentsTable)
          .select()
          .eq('id', assignmentId)
          .maybeSingle();

      if (row == null) return null;
      return _assignmentFromRow(row);
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching assignment: $e', name: 'AssignmentRepository');
      }
      return null;
    }
  }

  /// Create a new assignment (instructor only)
  Future<AssignmentModel> createAssignment(AssignmentModel assignment) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _assignments[assignment.id] = assignment;
      return assignment;
    }

    await _supabase!.from(_assignmentsTable).upsert({
      'id': assignment.id,
      'course_id': assignment.courseId,
      'lesson_id': assignment.lessonId,
      'title': assignment.title,
      'description': assignment.description,
      'instructions': assignment.instructions,
      'language': assignment.language.name,
      'starter_code': assignment.starterCode,
      'solution_code': assignment.solutionCode,
      'max_points': assignment.maxPoints,
      'due_date': assignment.dueDate?.toIso8601String(),
      'allow_late_submission': assignment.allowLateSubmission,
      'late_penalty_percent': assignment.latePenaltyPercent,
      'is_published': assignment.isPublished,
      'created_at': assignment.createdAt.toIso8601String(),
      'updated_at': assignment.updatedAt?.toIso8601String(),
    });

    return assignment;
  }

  /// Update an assignment (instructor only)
  Future<AssignmentModel> updateAssignment(AssignmentModel assignment) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _assignments[assignment.id] = assignment;
      return assignment;
    }

    await _supabase!
        .from(_assignmentsTable)
        .update({
          'course_id': assignment.courseId,
          'lesson_id': assignment.lessonId,
          'title': assignment.title,
          'description': assignment.description,
          'instructions': assignment.instructions,
          'language': assignment.language.name,
          'starter_code': assignment.starterCode,
          'solution_code': assignment.solutionCode,
          'max_points': assignment.maxPoints,
          'due_date': assignment.dueDate?.toIso8601String(),
          'allow_late_submission': assignment.allowLateSubmission,
          'late_penalty_percent': assignment.latePenaltyPercent,
          'is_published': assignment.isPublished,
          'updated_at':
              assignment.updatedAt?.toIso8601String() ??
              DateTime.now().toIso8601String(),
        })
        .eq('id', assignment.id);

    return assignment;
  }

  /// Delete an assignment (instructor only)
  Future<void> deleteAssignment(String assignmentId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _assignments.remove(assignmentId);
      _submissionsByAssignment.remove(assignmentId);
      return;
    }

    await _supabase!
        .from(_submissionsTable)
        .delete()
        .eq('assignment_id', assignmentId);
    await _supabase!.from(_assignmentsTable).delete().eq('id', assignmentId);
  }

  /// Get user's submission for an assignment
  Future<SubmissionModel?> getUserSubmission(
    String assignmentId,
    String userId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      for (final key in _demoUserKeys(userId)) {
        final submission = _submissionsByUser[key]?[assignmentId];
        if (submission != null) return submission;
      }
      return null;
    }

    try {
      final row = await _supabase!
          .from(_submissionsTable)
          .select()
          .eq('assignment_id', assignmentId)
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return null;
      return _submissionFromRow(row);
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching user submission: $e', name: 'AssignmentRepository');
      }
      return null;
    }
  }

  /// Get all submissions for an assignment (instructor only)
  Future<List<SubmissionModel>> getAssignmentSubmissions(
    String assignmentId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _submissionsByAssignment[assignmentId] ?? [];
    }

    try {
      final rows = await _supabase!
          .from(_submissionsTable)
          .select()
          .eq('assignment_id', assignmentId)
          .order('created_at', ascending: false);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_submissionFromRow)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        log(
          'Error fetching assignment submissions: $e',
          name: 'AssignmentRepository',
        );
      }
      return [];
    }
  }

  /// Save a draft submission
  Future<SubmissionModel> saveDraft({
    required String assignmentId,
    required String courseId,
    required String userId,
    required String userDisplayName,
    required String code,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));

      final normalizedUserId = _normalizeDemoUserId(userId);
      final existingSubmission =
          _submissionsByUser[normalizedUserId]?[assignmentId];

      final submission = SubmissionModel(
        id:
            existingSubmission?.id ??
            'submission-${DateTime.now().millisecondsSinceEpoch}',
        assignmentId: assignmentId,
        courseId: courseId,
        userId: normalizedUserId,
        userDisplayName: userDisplayName,
        code: code,
        status: SubmissionStatus.draft,
        createdAt: existingSubmission?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      for (final key in _demoUserKeys(normalizedUserId)) {
        _submissionsByUser[key] ??= {};
        _submissionsByUser[key]![assignmentId] = submission;
      }

      final assignmentSubmissions =
          _submissionsByAssignment[assignmentId] ?? [];
      final existingIndex = assignmentSubmissions.indexWhere(
        (s) => _normalizeDemoUserId(s.userId) == normalizedUserId,
      );
      if (existingIndex >= 0) {
        assignmentSubmissions[existingIndex] = submission;
      } else {
        assignmentSubmissions.add(submission);
      }
      _submissionsByAssignment[assignmentId] = assignmentSubmissions;

      return submission;
    }

    final existing = await getUserSubmission(assignmentId, userId);
    final submission = SubmissionModel(
      id: existing?.id ?? 'submission-${DateTime.now().millisecondsSinceEpoch}',
      assignmentId: assignmentId,
      courseId: courseId,
      userId: userId,
      userDisplayName: userDisplayName,
      code: code,
      status: SubmissionStatus.draft,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _supabase!.from(_submissionsTable).upsert({
      'id': submission.id,
      'assignment_id': submission.assignmentId,
      'course_id': submission.courseId,
      'user_id': submission.userId,
      'user_display_name': submission.userDisplayName,
      'code': submission.code,
      'status': submission.status.name,
      'score': submission.score,
      'feedback': submission.feedback,
      'graded_by': submission.gradedBy,
      'graded_at': submission.gradedAt?.toIso8601String(),
      'is_late': submission.isLate,
      'created_at': submission.createdAt.toIso8601String(),
      'updated_at':
          submission.updatedAt?.toIso8601String() ??
          DateTime.now().toIso8601String(),
      'submitted_at': submission.submittedAt?.toIso8601String(),
    });

    return submission;
  }

  /// Submit an assignment
  Future<SubmissionModel> submitAssignment({
    required String assignmentId,
    required String courseId,
    required String userId,
    required String userDisplayName,
    required String code,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));

      final normalizedUserId = _normalizeDemoUserId(userId);
      final assignment = _assignments[assignmentId];
      final isLate =
          assignment?.dueDate != null &&
          DateTime.now().isAfter(assignment!.dueDate!);
      final existingSubmission =
          _submissionsByUser[normalizedUserId]?[assignmentId];

      final submission = SubmissionModel(
        id:
            existingSubmission?.id ??
            'submission-${DateTime.now().millisecondsSinceEpoch}',
        assignmentId: assignmentId,
        courseId: courseId,
        userId: normalizedUserId,
        userDisplayName: userDisplayName,
        code: code,
        status: SubmissionStatus.submitted,
        isLate: isLate,
        createdAt: existingSubmission?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        submittedAt: DateTime.now(),
      );

      for (final key in _demoUserKeys(normalizedUserId)) {
        _submissionsByUser[key] ??= {};
        _submissionsByUser[key]![assignmentId] = submission;
      }

      final assignmentSubmissions =
          _submissionsByAssignment[assignmentId] ?? [];
      final existingIndex = assignmentSubmissions.indexWhere(
        (s) => _normalizeDemoUserId(s.userId) == normalizedUserId,
      );
      if (existingIndex >= 0) {
        assignmentSubmissions[existingIndex] = submission;
      } else {
        assignmentSubmissions.add(submission);
      }
      _submissionsByAssignment[assignmentId] = assignmentSubmissions;

      return submission;
    }

    final assignment = await getAssignment(assignmentId);
    final existing = await getUserSubmission(assignmentId, userId);
    final isLate =
        assignment?.dueDate != null &&
        DateTime.now().isAfter(assignment!.dueDate!);

    final submission = SubmissionModel(
      id: existing?.id ?? 'submission-${DateTime.now().millisecondsSinceEpoch}',
      assignmentId: assignmentId,
      courseId: courseId,
      userId: userId,
      userDisplayName: userDisplayName,
      code: code,
      status: SubmissionStatus.submitted,
      isLate: isLate,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      submittedAt: DateTime.now(),
    );

    await _supabase!.from(_submissionsTable).upsert({
      'id': submission.id,
      'assignment_id': submission.assignmentId,
      'course_id': submission.courseId,
      'user_id': submission.userId,
      'user_display_name': submission.userDisplayName,
      'code': submission.code,
      'status': submission.status.name,
      'score': submission.score,
      'feedback': submission.feedback,
      'graded_by': submission.gradedBy,
      'graded_at': submission.gradedAt?.toIso8601String(),
      'is_late': submission.isLate,
      'created_at': submission.createdAt.toIso8601String(),
      'updated_at':
          submission.updatedAt?.toIso8601String() ??
          DateTime.now().toIso8601String(),
      'submitted_at': submission.submittedAt?.toIso8601String(),
    });

    return submission;
  }

  /// Grade a submission (instructor only)
  Future<SubmissionModel> gradeSubmission({
    required String submissionId,
    required String assignmentId,
    required int score,
    required String feedback,
    required String gradedBy,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 400));

      final submissions = _submissionsByAssignment[assignmentId];
      if (submissions == null) {
        throw Exception('Submission not found');
      }

      final index = submissions.indexWhere((s) => s.id == submissionId);
      if (index < 0) {
        throw Exception('Submission not found');
      }

      final updatedSubmission = submissions[index].copyWith(
        status: SubmissionStatus.graded,
        score: score,
        feedback: feedback,
        gradedBy: gradedBy,
        gradedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      submissions[index] = updatedSubmission;
      for (final key in _demoUserKeys(updatedSubmission.userId)) {
        _submissionsByUser[key] ??= {};
        _submissionsByUser[key]![assignmentId] = updatedSubmission;
      }

      return updatedSubmission;
    }

    await _supabase!
        .from(_submissionsTable)
        .update({
          'status': SubmissionStatus.graded.name,
          'score': score,
          'feedback': feedback,
          'graded_by': gradedBy,
          'graded_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', submissionId);

    final row = await _supabase!
        .from(_submissionsTable)
        .select()
        .eq('id', submissionId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Submission not found');
    }

    return _submissionFromRow(row);
  }

  /// Get pending submissions for instructor (ungraded submissions)
  Future<List<SubmissionModel>> getPendingSubmissions(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final pending = <SubmissionModel>[];
      for (final submissions in _submissionsByAssignment.values) {
        pending.addAll(
          submissions.where(
            (s) =>
                s.courseId == courseId &&
                s.status == SubmissionStatus.submitted,
          ),
        );
      }
      return pending;
    }

    try {
      final rows = await _supabase!
          .from(_submissionsTable)
          .select()
          .eq('course_id', courseId)
          .eq('status', SubmissionStatus.submitted.name);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_submissionFromRow)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        log(
          'Error fetching pending submissions: $e',
          name: 'AssignmentRepository',
        );
      }
      return [];
    }
  }

  /// Get user's submissions across all assignments in a course
  Future<List<SubmissionModel>> getUserSubmissionsForCourse(
    String courseId,
    String userId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final byId = <String, SubmissionModel>{};
      for (final key in _demoUserKeys(userId)) {
        final userSubmissions = _submissionsByUser[key];
        if (userSubmissions == null) continue;
        for (final submission in userSubmissions.values) {
          if (submission.courseId == courseId) {
            byId[submission.id] = submission;
          }
        }
      }
      return byId.values.toList();
    }

    try {
      final rows = await _supabase!
          .from(_submissionsTable)
          .select()
          .eq('course_id', courseId)
          .eq('user_id', userId);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_submissionFromRow)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        log(
          'Error fetching user submissions: $e',
          name: 'AssignmentRepository',
        );
      }
      return [];
    }
  }
}
