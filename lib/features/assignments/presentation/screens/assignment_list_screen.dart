import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../courses/data/repositories/course_repository.dart';
import '../../data/models/models.dart';
import '../../data/repositories/assignment_repository.dart';
import '../bloc/assignment_bloc.dart';
import '../bloc/assignment_event.dart';
import '../bloc/assignment_state.dart';

/// Screen displaying list of assignments for a course
class AssignmentListScreen extends StatefulWidget {
  final String courseId;

  const AssignmentListScreen({super.key, required this.courseId});

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  late AssignmentBloc _assignmentBloc;
  bool _canManageAssignments = false;

  @override
  void initState() {
    super.initState();
    _assignmentBloc = AssignmentBloc(
      assignmentRepository: context.read<AssignmentRepository>(),
    );
    _loadManagementPermission();
    _loadAssignments();
  }

  Future<void> _loadManagementPermission() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated ||
        authState.user.role != 'instructor') {
      return;
    }

    try {
      final course = await context.read<CourseRepository>().getCourse(
        widget.courseId,
      );
      if (mounted) {
        setState(() {
          _canManageAssignments = course?.instructorId == authState.user.id;
        });
      }
    } catch (_) {
      // RLS remains the authority; hide management controls when uncertain.
    }
  }

  void _loadAssignments() {
    _assignmentBloc.add(LoadAssignments(courseId: widget.courseId));
  }

  @override
  void dispose() {
    _assignmentBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _assignmentBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Assignments',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          actions: [
            if (_canManageAssignments)
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Create assignment',
                onPressed: _createAssignment,
              ),
          ],
        ),
        body: BlocBuilder<AssignmentBloc, AssignmentState>(
          builder: (context, state) {
            if (state is AssignmentsLoading) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (state is AssignmentError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadAssignments,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is AssignmentsLoaded) {
              if (state.assignments.isEmpty) {
                return _buildEmptyState();
              }
              return _buildAssignmentList(state.assignments);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'No assignments yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _canManageAssignments
                ? 'Create an assignment to get started'
                : 'Assignments will appear here when published',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          if (_canManageAssignments) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _createAssignment,
              icon: const Icon(Icons.add),
              label: const Text('Create Assignment'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignmentList(List<AssignmentModel> assignments) {
    return RefreshIndicator(
      onRefresh: () async => _loadAssignments(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: assignments.length,
        itemBuilder: (context, index) {
          final assignment = assignments[index];
          return _AssignmentCard(
            assignment: assignment,
            onTap: () {
              context.push(
                '/courses/${widget.courseId}/assignments/${assignment.id}',
              );
            },
            onEdit: _canManageAssignments
                ? () => _editAssignment(assignment.id)
                : null,
            onDelete: _canManageAssignments
                ? () => _confirmDeleteAssignment(assignment)
                : null,
            onGrade: _canManageAssignments
                ? () => context.push(
                    AppRoutes.gradeAssignmentPath(
                      widget.courseId,
                      assignment.id,
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  Future<void> _createAssignment() async {
    await context.push(AppRoutes.createAssignmentPath(widget.courseId));
    if (mounted) _loadAssignments();
  }

  Future<void> _editAssignment(String assignmentId) async {
    await context.push(
      AppRoutes.editAssignmentPath(widget.courseId, assignmentId),
    );
    if (mounted) _loadAssignments();
  }

  Future<void> _confirmDeleteAssignment(AssignmentModel assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete assignment?'),
        content: Text(
          '"${assignment.title}" and all student submissions will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<AssignmentRepository>().deleteAssignment(assignment.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment deleted.')),
      );
      _loadAssignments();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to delete this assignment.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _AssignmentCard extends StatelessWidget {
  final AssignmentModel assignment;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onGrade;

  const _AssignmentCard({
    required this.assignment,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onGrade,
  });

  @override
  Widget build(BuildContext context) {
    final isPastDue = assignment.isPastDue;
    final timeRemaining = assignment.timeRemaining;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPastDue
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.code, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assignment.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') {
                          onEdit!();
                        } else if (action == 'grade') {
                          onGrade!();
                        } else if (action == 'delete') {
                          onDelete!();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit assignment'),
                        ),
                        PopupMenuItem(
                          value: 'grade',
                          child: Text('Grade submissions'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete assignment',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    )
                  else
                    Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildMetaChip(
                    icon: Icons.code,
                    label: assignment.language.displayName,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _buildMetaChip(
                    icon: Icons.star_outline,
                    label: '${assignment.maxPoints} pts',
                  ),
                  if (assignment.dueDate != null) ...[
                    const Spacer(),
                    _buildDueDate(isPastDue, timeRemaining),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final chipColor = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: chipColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDate(bool isPastDue, Duration? timeRemaining) {
    String label;
    Color color;

    if (isPastDue) {
      label = 'Past due';
      color = AppColors.error;
    } else if (timeRemaining != null && timeRemaining.inDays < 1) {
      label = 'Due soon';
      color = AppColors.warning;
    } else if (timeRemaining != null) {
      label = '${timeRemaining.inDays} days left';
      color = AppColors.success;
    } else {
      label = 'No due date';
      color = AppColors.textSecondary;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
