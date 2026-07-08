import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/todos_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class TodosListScreen extends StatelessWidget {
  const TodosListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todos')),
      body: BlocBuilder<TodosCubit, TodosState>(
        builder: (context, state) {
          if (state.status == TodosStatus.loading ||
              state.status == TodosStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == TodosStatus.error) {
            return Center(
              child: Text(
                state.errorMessage ?? 'Failed to load todos',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (state.todos.isEmpty) {
            return Center(
              child: Text(
                'No todos yet',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.of(context).textSecondary,
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: state.todos.length,
            itemBuilder: (context, index) {
              final todo = state.todos[index];
              return ListTile(
                leading: Checkbox(
                  value: todo.isCompleted,
                  onChanged: (_) {
                    context.read<TodosCubit>().toggle(todoId: todo.id);
                  },
                ),
                title: Text(
                  todo.name,
                  style: todo.isCompleted
                      ? AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.of(context).textMuted,
                          decoration: TextDecoration.lineThrough,
                        )
                      : AppTextStyles.bodyMedium,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
