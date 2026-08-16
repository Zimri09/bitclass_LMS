import 'package:bitclass/features/todos/data/models/todo_model.dart';
import 'package:bitclass/features/todos/data/repositories/todos_repository.dart';
import 'package:bitclass/features/todos/presentation/screens/todos_list_screen.dart';
import 'package:bitclass/features/todos/presentation/state/todos_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('student page separates assigned, missing, and completed work', (
    tester,
  ) async {
    final now = DateTime.now();
    final repository = _FakeTodosRepository(
      studentTodos: [
        _todo(
          id: 'assigned',
          name: 'Upcoming assignment',
          type: TodoTaskType.assignment,
          dueAt: now.add(const Duration(days: 2)),
        ),
        _todo(
          id: 'missing',
          name: 'Overdue assignment',
          type: TodoTaskType.assignment,
          dueAt: now.subtract(const Duration(days: 2)),
        ),
        _todo(
          id: 'done',
          name: 'Completed quiz',
          type: TodoTaskType.quiz,
          isCompleted: true,
        ),
      ],
    );
    await _pumpTodos(tester, repository, TodoAudience.student);

    expect(find.text('To-do'), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
    expect(find.text('Missing'), findsOneWidget);
    expect(find.text('Upcoming assignment'), findsOneWidget);
    expect(find.text('Overdue assignment'), findsNothing);

    await tester.tap(find.text('Missing'));
    await tester.pumpAndSettle();
    expect(find.text('Overdue assignment'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Completed quiz'), findsOneWidget);
  });

  testWidgets('instructor page separates review, planning, and done work', (
    tester,
  ) async {
    final repository = _FakeTodosRepository(
      instructorTodos: [
        _todo(
          id: 'review',
          name: 'Algorithms project — Taylor Student',
          type: TodoTaskType.grading,
        ),
        _todo(
          id: 'draft',
          name: 'Sorting algorithms lesson',
          type: TodoTaskType.draftLesson,
        ),
        _todo(
          id: 'graded',
          name: 'Data structures project — Morgan Student',
          type: TodoTaskType.grading,
          isCompleted: true,
        ),
      ],
    );
    await _pumpTodos(tester, repository, TodoAudience.instructor);

    expect(find.text('Work queue'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Algorithms project — Taylor Student'), findsOneWidget);
    expect(find.text('Sorting algorithms lesson'), findsNothing);

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Sorting algorithms lesson'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(
      find.text('Data structures project — Morgan Student'),
      findsOneWidget,
    );
  });

  testWidgets('personal tasks can be completed and move to Done', (
    tester,
  ) async {
    final repository = _FakeTodosRepository(
      studentTodos: [
        _todo(
          id: 'personal',
          name: 'Prepare study notes',
          type: TodoTaskType.personal,
        ),
      ],
    );
    await _pumpTodos(tester, repository, TodoAudience.student);

    await tester.tap(find.text('Prepare study notes'));
    await tester.pumpAndSettle();
    expect(repository.toggleCalls, 1);
    expect(find.text('No assigned work'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare study notes'), findsOneWidget);
  });
}

TodoModel _todo({
  required String id,
  required String name,
  required TodoTaskType type,
  bool isCompleted = false,
  DateTime? dueAt,
}) {
  return TodoModel(
    id: id,
    name: name,
    isCompleted: isCompleted,
    dueAtIso: dueAt?.toIso8601String(),
    createdAt: DateTime.now(),
    taskType: type,
    courseName: type == TodoTaskType.personal ? null : 'Algorithms',
  );
}

Future<void> _pumpTodos(
  WidgetTester tester,
  _FakeTodosRepository repository,
  TodoAudience audience,
) async {
  await tester.pumpWidget(
    BlocProvider<TodosCubit>(
      create: (_) =>
          TodosCubit(todosRepository: repository, audience: audience)..load(),
      child: MaterialApp(home: TodosListScreen(audience: audience)),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeTodosRepository extends TodosRepository {
  final SupabaseClient _client;
  final List<TodoModel> studentTodos;
  final List<TodoModel> instructorTodos;
  int toggleCalls = 0;

  factory _FakeTodosRepository({
    List<TodoModel> studentTodos = const [],
    List<TodoModel> instructorTodos = const [],
  }) {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FakeTodosRepository._(
      client,
      studentTodos: studentTodos,
      instructorTodos: instructorTodos,
    );
  }

  _FakeTodosRepository._(
    this._client, {
    required this.studentTodos,
    required this.instructorTodos,
  }) : super(supabase: _client);

  @override
  Future<List<TodoModel>> getTodos({required TodoAudience audience}) async =>
      audience == TodoAudience.instructor ? instructorTodos : studentTodos;

  @override
  Future<void> toggleCompleted({required String todoId}) async {
    toggleCalls++;
    final index = studentTodos.indexWhere((todo) => todo.id == todoId);
    if (index != -1) {
      studentTodos[index] = studentTodos[index].copyWith(
        isCompleted: !studentTodos[index].isCompleted,
      );
    }
  }

  @override
  Future<void> dispose() async {
    _client.auth.dispose();
    await super.dispose();
  }
}
