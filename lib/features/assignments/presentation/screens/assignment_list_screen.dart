import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _assignmentBloc = AssignmentBloc(
      assignmentRepository: context.read<AssignmentRepository>(),
    );
    _loadAssignments();
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
            'Assignments will appear here when published',
            style: TextStyle(color: AppColors.textSecondary),
          ),
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
          );
        },
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final AssignmentModel assignment;
  final VoidCallback onTap;

  const _AssignmentCard({required this.assignment, required this.onTap});

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
