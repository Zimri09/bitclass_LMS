import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../data/models/todo_model.dart';
import '../state/todos_cubit.dart';

enum _TodoTab { assigned, missing, done }

class TodosListScreen extends StatefulWidget {
  const TodosListScreen({super.key});

  @override
  State<TodosListScreen> createState() => _TodosListScreenState();
}

class _TodosListScreenState extends State<TodosListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _TodoTab.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: const AppDrawerButton(),
        title: const Text('To-do'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.info,
          unselectedLabelColor: colors.textSecondary,
          indicatorColor: AppColors.info,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTextStyles.bodyLarge,
          tabs: const [
            Tab(text: 'Assigned'),
            Tab(text: 'Missing'),
            Tab(text: 'Done'),
          ],
        ),
      ),
      body: BlocBuilder<TodosCubit, TodosState>(
        builder: (context, state) {
          if (state.status == TodosStatus.loading ||
              state.status == TodosStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == TodosStatus.error) {
            return _MessageState(
              icon: Icons.error_outline,
              message: state.errorMessage ?? 'Failed to load your to-do list',
              color: AppColors.error,
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _TodoList(
                todos: state.todos
                    .where((todo) => !todo.isCompleted && !_isMissing(todo))
                    .toList(),
                tab: _TodoTab.assigned,
              ),
              _TodoList(
                todos: state.todos.where(_isMissing).toList(),
                tab: _TodoTab.missing,
              ),
              _TodoList(
                todos: state.todos.where((todo) => todo.isCompleted).toList(),
                tab: _TodoTab.done,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TodoList extends StatelessWidget {
  final List<TodoModel> todos;
  final _TodoTab tab;

  const _TodoList({required this.todos, required this.tab});

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) {
      final message = switch (tab) {
        _TodoTab.assigned => 'No assigned work',
        _TodoTab.missing => 'No missing work',
        _TodoTab.done => 'No completed work yet',
      };
      return _MessageState(
        icon: tab == _TodoTab.done
            ? Icons.task_alt_outlined
            : Icons.assignment_turned_in_outlined,
        message: message,
        color: AppColors.of(context).textSecondary,
      );
    }

    final groups = _groupsFor(todos, tab);
    return ListView(
      padding: const EdgeInsets.only(top: 20, bottom: 32),
      children: groups
          .map(
            (group) => _TodoGroup(
              title: group.title,
              todos: group.todos,
              initiallyExpanded: group.initiallyExpanded,
              isCompleted: tab == _TodoTab.done,
              isMissing: tab == _TodoTab.missing,
            ),
          )
          .toList(),
    );
  }
}

class _TodoGroup extends StatelessWidget {
  final String title;
  final List<TodoModel> todos;
  final bool initiallyExpanded;
  final bool isCompleted;
  final bool isMissing;

  const _TodoGroup({
    required this.title,
    required this.todos,
    required this.initiallyExpanded,
    required this.isCompleted,
    required this.isMissing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        iconColor: colors.textPrimary,
        collapsedIconColor: colors.textSecondary,
        title: Text(
          title,
          style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${todos.length}',
              style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(width: 18),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
        children: todos
            .map(
              (todo) => _TodoRow(
                todo: todo,
                isCompleted: isCompleted,
                isMissing: isMissing,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  final TodoModel todo;
  final bool isCompleted;
  final bool isMissing;

  const _TodoRow({
    required this.todo,
    required this.isCompleted,
    required this.isMissing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final iconColor = isMissing
        ? AppColors.error
        : isCompleted
        ? AppColors.success
        : const Color(0xFF0B57D0);
    final dueDate = _parseDueDate(todo);
    final subtitle = dueDate == null
        ? 'Class activity'
        : '${isMissing ? 'Missing' : isCompleted ? 'Completed' : 'Due'} ${_dateLabel(dueDate)}';

    return Semantics(
      button: true,
      label: '${todo.name}. $subtitle. Double tap to mark as '
          '${isCompleted ? 'assigned' : 'completed'}.',
      child: InkWell(
        onTap: () => context.read<TodosCubit>().toggle(todoId: todo.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 14, 24, 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                child: Icon(
                  isCompleted
                      ? Icons.assignment_turned_in_outlined
                      : Icons.assignment_outlined,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: isCompleted ? colors.textSecondary : colors.textPrimary,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isMissing ? AppColors.error : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _MessageState({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoGroupData {
  final String title;
  final List<TodoModel> todos;
  final bool initiallyExpanded;

  const _TodoGroupData({
    required this.title,
    required this.todos,
    required this.initiallyExpanded,
  });
}

bool _isMissing(TodoModel todo) {
  final dueDate = _parseDueDate(todo);
  return !todo.isCompleted &&
      dueDate != null &&
      dueDate.isBefore(_startOfToday());
}

List<_TodoGroupData> _groupsFor(List<TodoModel> todos, _TodoTab tab) {
  if (tab == _TodoTab.missing) {
    return [
      _TodoGroupData(title: 'Overdue', todos: _sortTodos(todos), initiallyExpanded: true),
    ];
  }

  if (tab == _TodoTab.done) {
    return [
      _TodoGroupData(title: 'Completed', todos: _sortTodos(todos), initiallyExpanded: true),
    ];
  }

  final noDueDate = <TodoModel>[];
  final thisWeek = <TodoModel>[];
  final nextWeek = <TodoModel>[];
  final later = <TodoModel>[];
  final today = _startOfToday();

  for (final todo in todos) {
    final dueDate = _parseDueDate(todo);
    if (dueDate == null) {
      noDueDate.add(todo);
    } else if (dueDate.isBefore(today.add(const Duration(days: 7)))) {
      thisWeek.add(todo);
    } else if (dueDate.isBefore(today.add(const Duration(days: 14)))) {
      nextWeek.add(todo);
    } else {
      later.add(todo);
    }
  }

  return [
    _TodoGroupData(
      title: 'No due date',
      todos: _sortTodos(noDueDate),
      initiallyExpanded: true,
    ),
    _TodoGroupData(title: 'This week', todos: _sortTodos(thisWeek), initiallyExpanded: false),
    _TodoGroupData(title: 'Next week', todos: _sortTodos(nextWeek), initiallyExpanded: false),
    _TodoGroupData(title: 'Later', todos: _sortTodos(later), initiallyExpanded: false),
  ];
}

List<TodoModel> _sortTodos(List<TodoModel> todos) {
  return [...todos]..sort((a, b) {
    final aDue = _parseDueDate(a);
    final bDue = _parseDueDate(b);
    if (aDue == null && bDue == null) return b.createdAt.compareTo(a.createdAt);
    if (aDue == null) return 1;
    if (bDue == null) return -1;
    return aDue.compareTo(bDue);
  });
}

DateTime _startOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime? _parseDueDate(TodoModel todo) {
  final value = todo.dueAtIso;
  return value == null ? null : DateTime.tryParse(value)?.toLocal();
}

String _dateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}
