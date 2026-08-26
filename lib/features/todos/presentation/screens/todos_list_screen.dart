import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../data/models/todo_model.dart';
import '../state/todos_cubit.dart';

enum _TodoTab { primary, secondary, done }

class TodosListScreen extends StatefulWidget {
  final TodoAudience audience;

  const TodosListScreen({super.key, required this.audience});

  @override
  State<TodosListScreen> createState() => _TodosListScreenState();
}

class _TodosListScreenState extends State<TodosListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool get _isInstructor => widget.audience == TodoAudience.instructor;

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
        title: Text(_isInstructor ? 'Work queue' : 'To-do'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.info,
          unselectedLabelColor: colors.textSecondary,
          indicatorColor: AppColors.info,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTextStyles.bodyLarge,
          tabs: _isInstructor
              ? const [
                  Tab(text: 'Review'),
                  Tab(text: 'Plan'),
                  Tab(text: 'Done'),
                ]
              : const [
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
              message: state.errorMessage ?? 'Failed to load tasks',
              color: AppColors.error,
            );
          }

          return RefreshIndicator(
            onRefresh: context.read<TodosCubit>().load,
            color: AppColors.info,
            child: TabBarView(
              controller: _tabController,
              children: _TodoTab.values
                  .map(
                    (tab) => _TodoList(
                      todos: _todosForTab(state.todos, tab),
                      tab: tab,
                      audience: widget.audience,
                    ),
                  )
                  .toList(growable: false),
            ),
          );
        },
      ),
    );
  }

  List<TodoModel> _todosForTab(List<TodoModel> todos, _TodoTab tab) {
    if (_isInstructor) {
      return switch (tab) {
        _TodoTab.primary =>
          todos
              .where((todo) => todo.isInstructorReview && !todo.isCompleted)
              .toList(),
        _TodoTab.secondary =>
          todos
              .where((todo) => !todo.isInstructorReview && !todo.isCompleted)
              .toList(),
        _TodoTab.done => todos.where((todo) => todo.isCompleted).toList(),
      };
    }

    return switch (tab) {
      _TodoTab.primary =>
        todos.where((todo) => !todo.isCompleted && !_isMissing(todo)).toList(),
      _TodoTab.secondary => todos.where(_isMissing).toList(),
      _TodoTab.done => todos.where((todo) => todo.isCompleted).toList(),
    };
  }
}

class _TodoList extends StatelessWidget {
  final List<TodoModel> todos;
  final _TodoTab tab;
  final TodoAudience audience;

  const _TodoList({
    required this.todos,
    required this.tab,
    required this.audience,
  });

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) {
      final isInstructor = audience == TodoAudience.instructor;
      final message = isInstructor
          ? switch (tab) {
              _TodoTab.primary => 'No submissions waiting for review',
              _TodoTab.secondary => 'No drafts or planning tasks',
              _TodoTab.done => 'No completed work yet',
            }
          : switch (tab) {
              _TodoTab.primary => 'No assigned work',
              _TodoTab.secondary => 'No missing work',
              _TodoTab.done => 'No completed work yet',
            };
      return _ScrollableMessageState(
        icon: tab == _TodoTab.done
            ? Icons.task_alt_outlined
            : isInstructor
            ? Icons.inbox_outlined
            : Icons.assignment_turned_in_outlined,
        message: message,
        color: AppColors.of(context).textSecondary,
      );
    }

    final groups = _groupsFor(todos, tab, audience);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 20, bottom: 32),
      children: groups
          .map(
            (group) => _TodoGroup(
              title: group.title,
              todos: group.todos,
              initiallyExpanded: group.initiallyExpanded,
              isMissing:
                  audience == TodoAudience.student && tab == _TodoTab.secondary,
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
  final bool isMissing;

  const _TodoGroup({
    required this.title,
    required this.todos,
    required this.initiallyExpanded,
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
              style: AppTextStyles.bodyLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 18),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
        children: todos
            .map((todo) => _TodoRow(todo: todo, isMissing: isMissing))
            .toList(),
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  final TodoModel todo;
  final bool isMissing;

  const _TodoRow({required this.todo, required this.isMissing});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final iconColor = isMissing
        ? AppColors.error
        : todo.isCompleted
        ? AppColors.success
        : _taskColor(todo.taskType);
    final subtitle = _subtitle(todo, isMissing: isMissing);
    final actionDescription = todo.actionUrl != null
        ? 'Double tap to open.'
        : 'Double tap to mark as '
              '${todo.isCompleted ? 'incomplete' : 'completed'}.';

    return Semantics(
      button: true,
      label: '${todo.name}. $subtitle. $actionDescription',
      child: InkWell(
        onTap: () => _handleTap(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 14, 24, 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _taskIcon(todo.taskType, isCompleted: todo.isCompleted),
                  color: Colors.white,
                  size: 27,
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
                        color: todo.isCompleted
                            ? colors.textSecondary
                            : colors.textPrimary,
                        decoration: todo.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isMissing
                            ? AppColors.error
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                todo.actionUrl != null
                    ? Icons.chevron_right_rounded
                    : todo.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: todo.isCompleted
                    ? AppColors.success
                    : colors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    if (todo.actionUrl == null) {
      await context.read<TodosCubit>().toggle(todo: todo);
      return;
    }

    try {
      await context.push(todo.actionUrl!);
      if (context.mounted) {
        await context.read<TodosCubit>().load();
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This task could not be opened.')),
      );
    }
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

class _ScrollableMessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _ScrollableMessageState({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: _MessageState(icon: icon, message: message, color: color),
        ),
      ],
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

List<_TodoGroupData> _groupsFor(
  List<TodoModel> todos,
  _TodoTab tab,
  TodoAudience audience,
) {
  if (audience == TodoAudience.instructor) {
    if (tab == _TodoTab.primary) {
      return _groupsByCourse(todos);
    }
    if (tab == _TodoTab.secondary) {
      const planningGroups = [
        (TodoTaskType.draftCourse, 'Draft courses'),
        (TodoTaskType.draftLesson, 'Draft lessons'),
        (TodoTaskType.draftAssignment, 'Draft assignments'),
        (TodoTaskType.draftQuiz, 'Draft quizzes'),
        (TodoTaskType.personal, 'Personal tasks'),
      ];
      return planningGroups
          .map(
            (group) => _TodoGroupData(
              title: group.$2,
              todos: _sortTodos(
                todos.where((todo) => todo.taskType == group.$1).toList(),
              ),
              initiallyExpanded: true,
            ),
          )
          .where((group) => group.todos.isNotEmpty)
          .toList();
    }
    return [
      _TodoGroupData(
        title: 'Completed',
        todos: _sortTodos(todos),
        initiallyExpanded: true,
      ),
    ];
  }

  if (tab == _TodoTab.secondary) {
    return [
      _TodoGroupData(
        title: 'Overdue',
        todos: _sortTodos(todos),
        initiallyExpanded: true,
      ),
    ];
  }
  if (tab == _TodoTab.done) {
    return [
      _TodoGroupData(
        title: 'Completed',
        todos: _sortTodos(todos),
        initiallyExpanded: true,
      ),
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
    _TodoGroupData(
      title: 'This week',
      todos: _sortTodos(thisWeek),
      initiallyExpanded: true,
    ),
    _TodoGroupData(
      title: 'Next week',
      todos: _sortTodos(nextWeek),
      initiallyExpanded: false,
    ),
    _TodoGroupData(
      title: 'Later',
      todos: _sortTodos(later),
      initiallyExpanded: false,
    ),
  ].where((group) => group.todos.isNotEmpty).toList();
}

List<_TodoGroupData> _groupsByCourse(List<TodoModel> todos) {
  final grouped = <String, List<TodoModel>>{};
  for (final todo in todos) {
    grouped.putIfAbsent(todo.courseName ?? 'Other', () => []).add(todo);
  }
  final names = grouped.keys.toList()..sort();
  return names
      .map(
        (name) => _TodoGroupData(
          title: name,
          todos: _sortTodos(grouped[name]!),
          initiallyExpanded: true,
        ),
      )
      .toList();
}

List<TodoModel> _sortTodos(List<TodoModel> todos) {
  return [...todos]..sort((a, b) {
    final aDue = _parseDueDate(a);
    final bDue = _parseDueDate(b);
    if (aDue == null && bDue == null) {
      return b.createdAt.compareTo(a.createdAt);
    }
    if (aDue == null) return 1;
    if (bDue == null) return -1;
    return aDue.compareTo(bDue);
  });
}

String _subtitle(TodoModel todo, {required bool isMissing}) {
  final parts = <String>[_taskLabel(todo.taskType)];
  if (todo.courseName?.isNotEmpty == true) {
    parts.add(todo.courseName!);
  }
  final dueDate = _parseDueDate(todo);
  if (dueDate != null) {
    final prefix = todo.taskType == TodoTaskType.grading
        ? 'Submitted'
        : isMissing
        ? 'Missing'
        : todo.isCompleted
        ? 'Completed'
        : 'Due';
    parts.add('$prefix ${_dateLabel(dueDate)}');
  }
  return parts.join(' • ');
}

String _taskLabel(TodoTaskType type) {
  return switch (type) {
    TodoTaskType.personal => 'Personal task',
    TodoTaskType.assignment => 'Assignment',
    TodoTaskType.quiz => 'Quiz',
    TodoTaskType.lesson => 'Lesson',
    TodoTaskType.grading => 'Submission',
    TodoTaskType.draftCourse => 'Draft course',
    TodoTaskType.draftAssignment => 'Draft assignment',
    TodoTaskType.draftQuiz => 'Draft quiz',
    TodoTaskType.draftLesson => 'Draft lesson',
  };
}

IconData _taskIcon(TodoTaskType type, {required bool isCompleted}) {
  if (isCompleted) return Icons.task_alt_rounded;
  return switch (type) {
    TodoTaskType.personal => Icons.check_box_outlined,
    TodoTaskType.assignment => Icons.assignment_outlined,
    TodoTaskType.quiz => Icons.quiz_outlined,
    TodoTaskType.lesson => Icons.menu_book_outlined,
    TodoTaskType.grading => Icons.rate_review_outlined,
    TodoTaskType.draftCourse => Icons.school_outlined,
    TodoTaskType.draftAssignment => Icons.assignment_add,
    TodoTaskType.draftQuiz => Icons.quiz_outlined,
    TodoTaskType.draftLesson => Icons.edit_note_outlined,
  };
}

Color _taskColor(TodoTaskType type) {
  return switch (type) {
    TodoTaskType.personal => AppColors.secondary,
    TodoTaskType.assignment => AppColors.info,
    TodoTaskType.quiz => AppColors.primary,
    TodoTaskType.lesson => AppColors.secondary,
    TodoTaskType.grading => AppColors.warning,
    TodoTaskType.draftCourse ||
    TodoTaskType.draftAssignment ||
    TodoTaskType.draftQuiz ||
    TodoTaskType.draftLesson => AppColors.warning,
  };
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
