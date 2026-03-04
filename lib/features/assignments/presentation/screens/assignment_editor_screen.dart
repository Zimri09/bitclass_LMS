import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/assignment_model.dart';
import '../../data/repositories/assignment_repository.dart';

/// Screen for creating and editing assignments
class AssignmentEditorScreen extends StatefulWidget {
  final String courseId;
  final String? assignmentId; // null = create new, otherwise edit

  const AssignmentEditorScreen({
    super.key,
    required this.courseId,
    this.assignmentId,
  });

  @override
  State<AssignmentEditorScreen> createState() => _AssignmentEditorScreenState();
}

class _AssignmentEditorScreenState extends State<AssignmentEditorScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _starterCodeController = TextEditingController();
  final _solutionCodeController = TextEditingController();
  final _maxPointsController = TextEditingController(text: '100');
  final _latePenaltyController = TextEditingController(text: '10');

  late TabController _tabController;

  bool _isLoading = false;
  bool _isSaving = false;
  AssignmentModel? _assignment;

  // Assignment settings
  ProgrammingLanguage _language = ProgrammingLanguage.dart;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _allowLateSubmission = true;
  bool _isPublished = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.assignmentId != null) {
      _loadAssignment();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _starterCodeController.dispose();
    _solutionCodeController.dispose();
    _maxPointsController.dispose();
    _latePenaltyController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignment() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<AssignmentRepository>();
      final assignment = await repo.getAssignment(widget.assignmentId!);
      if (assignment != null) {
        setState(() {
          _assignment = assignment;
          _titleController.text = assignment.title;
          _descriptionController.text = assignment.description;
          _instructionsController.text = assignment.instructions ?? '';
          _starterCodeController.text = assignment.starterCode ?? '';
          _solutionCodeController.text = assignment.solutionCode ?? '';
          _maxPointsController.text = assignment.maxPoints.toString();
          _latePenaltyController.text = assignment.latePenaltyPercent
              .toString();
          _language = assignment.language;
          _dueDate = assignment.dueDate;
          if (assignment.dueDate != null) {
            _dueTime = TimeOfDay.fromDateTime(assignment.dueDate!);
          }
          _allowLateSubmission = assignment.allowLateSubmission;
          _isPublished = assignment.isPublished;
        });
      }
    } catch (e) {
      _showError('Failed to load assignment: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final repo = context.read<AssignmentRepository>();
      final now = DateTime.now();
      final assignmentId = widget.assignmentId ?? const Uuid().v4();

      // Combine date and time for due date
      DateTime? combinedDueDate;
      if (_dueDate != null) {
        final time = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);
        combinedDueDate = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          time.hour,
          time.minute,
        );
      }

      final assignment = AssignmentModel(
        id: assignmentId,
        courseId: widget.courseId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        instructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        language: _language,
        starterCode: _starterCodeController.text.trim().isEmpty
            ? null
            : _starterCodeController.text.trim(),
        solutionCode: _solutionCodeController.text.trim().isEmpty
            ? null
            : _solutionCodeController.text.trim(),
        maxPoints: int.tryParse(_maxPointsController.text) ?? 100,
        dueDate: combinedDueDate,
        allowLateSubmission: _allowLateSubmission,
        latePenaltyPercent: int.tryParse(_latePenaltyController.text) ?? 10,
        isPublished: _isPublished,
        createdAt: _assignment?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.assignmentId == null) {
        await repo.createAssignment(assignment);
      } else {
        await repo.updateAssignment(assignment);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.assignmentId == null
                  ? 'Assignment created successfully!'
                  : 'Assignment updated successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      _showError('Failed to save assignment: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _dueDate = date);
      _selectDueTime();
    }
  }

  Future<void> _selectDueTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 23, minute: 59),
    );
    if (time != null) {
      setState(() => _dueTime = time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.assignmentId == null ? 'Create Assignment' : 'Edit Assignment',
          style: AppTextStyles.h4,
        ),
        backgroundColor: AppColors.surface,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Instructions'),
            Tab(text: 'Code'),
          ],
          indicatorColor: AppColors.primary,
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton(
                onPressed: _isSaving ? null : _saveAssignment,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDetailsTab(),
                  _buildInstructionsTab(),
                  _buildCodeTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailsTab() {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final padding = isMobile ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info Card
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Basic Information', style: AppTextStyles.h4),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Assignment Title',
                    hintText: 'Enter assignment title',
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Short Description',
                    hintText: 'Brief description of the assignment',
                  ),
                  maxLines: 2,
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Description is required'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ProgrammingLanguage>(
                  initialValue: _language,
                  decoration: const InputDecoration(
                    labelText: 'Programming Language',
                  ),
                  items: ProgrammingLanguage.values.map((lang) {
                    return DropdownMenuItem(
                      value: lang,
                      child: Text(lang.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _language = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Settings Card
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings', style: AppTextStyles.h4),
                const SizedBox(height: 16),

                // Max points
                TextFormField(
                  controller: _maxPointsController,
                  decoration: const InputDecoration(
                    labelText: 'Maximum Points',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Due date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due Date'),
                  subtitle: _dueDate != null
                      ? Text(
                          '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year} '
                          '${_dueTime?.format(context) ?? '23:59'}',
                        )
                      : const Text('No due date set'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _selectDueDate,
                      ),
                      if (_dueDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _dueDate = null;
                              _dueTime = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                const Divider(),

                // Late submission settings
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow Late Submission'),
                  value: _allowLateSubmission,
                  onChanged: (value) =>
                      setState(() => _allowLateSubmission = value),
                  activeThumbColor: AppColors.primary,
                ),
                if (_allowLateSubmission)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: TextFormField(
                      controller: _latePenaltyController,
                      decoration: const InputDecoration(
                        labelText: 'Late Penalty (%)',
                        hintText: 'Percentage deducted for late submission',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                const Divider(),

                // Published
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published'),
                  subtitle: const Text('Make visible to students'),
                  value: _isPublished,
                  onChanged: (value) => setState(() => _isPublished = value),
                  activeThumbColor: AppColors.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsTab() {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final padding = isMobile ? 16.0 : 24.0;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Instructions', style: AppTextStyles.h4),
                const Spacer(),
                Text(
                  'Supports Markdown',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextFormField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  hintText:
                      'Write detailed instructions for students...\n\n'
                      '## Example\n'
                      '- Use Markdown formatting\n'
                      '- Include code examples with ```dart blocks\n'
                      '- Explain requirements clearly',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeTab() {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final padding = isMobile ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Starter Code
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Starter Code', style: AppTextStyles.h4),
                const SizedBox(height: 8),
                Text(
                  'Initial code provided to students',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextFormField(
                    controller: _starterCodeController,
                    decoration: InputDecoration(
                      hintText: '// Enter starter code here...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      hintStyle: TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppColors.info,
                      height: 1.4,
                    ),
                    cursorColor: AppColors.info,
                    maxLines: null,
                    expands: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Solution Code
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Solution Code', style: AppTextStyles.h4),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Hidden from students',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Reference solution for grading',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextFormField(
                    controller: _solutionCodeController,
                    decoration: InputDecoration(
                      hintText: '// Enter solution code here...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      hintStyle: TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppColors.secondary,
                      height: 1.4,
                    ),
                    cursorColor: AppColors.secondary,
                    maxLines: null,
                    expands: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
