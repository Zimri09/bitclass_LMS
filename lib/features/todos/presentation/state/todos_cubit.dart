import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/todos_repository.dart';
import '../../data/models/models.dart';

enum TodosStatus { initial, loading, loaded, error }

class TodosState {
  final TodosStatus status;
  final List<TodoModel> todos;
  final String? errorMessage;

  const TodosState({
    this.status = TodosStatus.initial,
    this.todos = const [],
    this.errorMessage,
  });

  TodosState copyWith({
    TodosStatus? status,
    List<TodoModel>? todos,
    String? errorMessage,
  }) {
    return TodosState(
      status: status ?? this.status,
      todos: todos ?? this.todos,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class TodosCubit extends Cubit<TodosState> {
  final TodosRepository todosRepository;
  final TodoAudience audience;

  TodosCubit({required this.todosRepository, required this.audience})
    : super(const TodosState());

  Future<void> load() async {
    emit(state.copyWith(status: TodosStatus.loading, errorMessage: null));
    try {
      final todos = await todosRepository.getTodos(audience: audience);
      emit(state.copyWith(status: TodosStatus.loaded, todos: todos));
    } catch (e) {
      emit(
        state.copyWith(
          status: TodosStatus.error,
          errorMessage: 'Failed to load todos',
        ),
      );
    }
  }

  Future<void> toggle({required TodoModel todo}) async {
    if (!todo.isPersonal) return;
    try {
      await todosRepository.toggleCompleted(todoId: todo.id);
      await load();
    } catch (_) {
      // Keep UI stable on failure
    }
  }

  @override
  Future<void> close() async {
    await todosRepository.dispose();
    return super.close();
  }
}
