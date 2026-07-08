import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/environment.dart';
import '../models/models.dart';

class TodosRepository {
  static const String _todosTable = 'todos';

  final SupabaseClient? _supabase;

  // Demo data (used in demo mode)
  final List<TodoModel> _demoTodos = [];
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
    _demoTodos.addAll([
      TodoModel(
        id: 'todo-1',
        name: 'Finish lesson widgets',
        isCompleted: false,
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: null,
      ),
      TodoModel(
        id: 'todo-2',
        name: 'Submit assignment',
        isCompleted: true,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 20)),
      ),
      TodoModel(
        id: 'todo-3',
        name: 'Review quiz results',
        isCompleted: false,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: null,
      ),
    ]);
    _todosController.add(List.unmodifiable(_demoTodos));
  }

  Future<List<TodoModel>> getTodos() async {
    final userId = _supabase?.auth.currentUser?.id;

    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 250));
      return List.unmodifiable(_demoTodos);
    }

    final rows = await _supabase!
        .from(_todosTable)
        .select()
        .order('created_at', ascending: false);

    final list = (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => TodoModel.fromMap(row, row['id'] as String))
        .toList();

    return list;
  }

  Future<void> toggleCompleted({required String todoId}) async {
    if (EnvironmentConfig.isDemoMode) {
      final idx = _demoTodos.indexWhere((t) => t.id == todoId);
      if (idx == -1) return;
      _demoTodos[idx] = _demoTodos[idx].copyWith(
        isCompleted: !_demoTodos[idx].isCompleted,
        updatedAt: DateTime.now(),
      );
      _todosController.add(List.unmodifiable(_demoTodos));
      return;
    }

    // Fetch current value first (simple & safe)
    final current = await _supabase!
        .from(_todosTable)
        .select('id,is_completed')
        .eq('id', todoId)
        .maybeSingle();

    if (current == null) return;

    final newVal = !(current['is_completed'] as bool? ?? false);

    await _supabase!
        .from(_todosTable)
        .update({
          'is_completed': newVal,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', todoId);
  }

  Future<void> dispose() async {
    await _todosController.close();
  }
}
