import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/url_utils.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/models.dart';
import '../../data/repositories/assignment_repository.dart';
import '../widgets/widgets.dart';

enum _AssignmentExitAction { keepEditing, discard, saveDraft }

class _PendingMaterial {
  final String id;
  final PickedAssignmentFile file;

  const _PendingMaterial({required this.id, required this.file});

  AssignmentAttachment get preview => AssignmentAttachment(
    id: id,
    name: file.name,
    kind: AssignmentAttachmentKind.file,
    mimeType: file.mimeType,
    sizeBytes: file.bytes.length,
  );
}

/// A simple, Classroom-style editor for assignments and activities.
class AssignmentEditorScreen extends StatefulWidget {
  final String courseId;
  final String? assignmentId;

  const AssignmentEditorScreen({
    super.key,
    required this.courseId,
    this.assignmentId,
  });

  @override
  State<AssignmentEditorScreen> createState() => _AssignmentEditorScreenState();
}

class _AssignmentEditorScreenState extends State<AssignmentEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _pointsController = TextEditingController(text: '100');
  final _starterCodeController = TextEditingController();
  final _solutionCodeController = TextEditingController();

  late final String _workingAssignmentId;
  AssignmentModel? _assignment;
  List<AssignmentAttachment> _attachments = [];
  final List<_PendingMaterial> _pendingMaterials = [];
  final List<AssignmentAttachment> _removedStoredMaterials = [];

  ProgrammingLanguage _language = ProgrammingLanguage.plaintext;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _requiresAttachment = true;
  bool _allowLateSubmission = true;
  bool _isPublished = false;
  bool _isCodeActivity = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPickingFile = false;
  bool _recordExists = false;
  bool _hasChanges = false;
  bool _allowPop = false;
  bool _isExitDialogOpen = false;

  String get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated
        ? authState.user.id
        : 'demo-instructor-1';
  }

  int get _attachmentCount => _attachments.length + _pendingMaterials.length;

  @override
  void initState() {
    super.initState();
    _workingAssignmentId = widget.assignmentId ?? const Uuid().v4();
    if (widget.assignmentId != null) _loadAssignment();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _pointsController.dispose();
    _starterCodeController.dispose();
    _solutionCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignment() async {
    setState(() => _isLoading = true);
    try {
      final assignment = await context
          .read<AssignmentRepository>()
          .getAssignment(_workingAssignmentId);
      if (assignment == null) throw Exception('Assignment not found.');
      if (!mounted) return;
      setState(() {
        _assignment = assignment;
        _recordExists = true;
        _titleController.text = assignment.title;
        _instructionsController.text = assignment.instructions ?? '';
        _pointsController.text = assignment.maxPoints.toString();
        _starterCodeController.text = assignment.starterCode ?? '';
        _solutionCodeController.text = assignment.solutionCode ?? '';
        _attachments = List.of(assignment.attachments);
        _language = assignment.language;
        _dueDate = assignment.dueDate?.toLocal();
        _dueTime = assignment.dueDate == null
            ? null
            : TimeOfDay.fromDateTime(assignment.dueDate!.toLocal());
        _requiresAttachment = assignment.requiresAttachment;
        _allowLateSubmission = assignment.allowLateSubmission;
        _isPublished = assignment.isPublished;
        _isCodeActivity = assignment.isCodeActivity;
        _hasChanges = false;
      });
    } catch (error) {
      _showError('Failed to load assignment: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  AssignmentModel _buildAssignment({
    required List<AssignmentAttachment> attachments,
    required bool isPublished,
  }) {
    DateTime? dueDateTime;
    if (_dueDate != null) {
      final time = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);
      dueDateTime = DateTime(
        _dueDate!.year,
        _dueDate!.month,
        _dueDate!.day,
        time.hour,
        time.minute,
      );
    }

    final instructions = _instructionsController.text.trim();
    final normalizedSummary = instructions.replaceAll(RegExp(r'\s+'), ' ');
    final existingDescription = _assignment?.description.trim() ?? '';
    final description = normalizedSummary.isEmpty
        ? (existingDescription.isEmpty
              ? 'Assignment activity'
              : existingDescription)
        : normalizedSummary.substring(
            0,
            normalizedSummary.length.clamp(0, 180),
          );
    final now = DateTime.now();

    return AssignmentModel(
      id: _workingAssignmentId,
      courseId: widget.courseId,
      lessonId: _assignment?.lessonId,
      title: _titleController.text.trim(),
      description: description,
      instructions: instructions.isEmpty ? null : instructions,
      language: _isCodeActivity ? _language : ProgrammingLanguage.plaintext,
      starterCode:
          _isCodeActivity && _starterCodeController.text.trim().isNotEmpty
          ? _starterCodeController.text.trim()
          : null,
      solutionCode:
          _isCodeActivity && _solutionCodeController.text.trim().isNotEmpty
          ? _solutionCodeController.text.trim()
          : null,
      attachments: attachments,
      requiresAttachment: _requiresAttachment,
      maxPoints: int.tryParse(_pointsController.text.trim()) ?? 100,
      dueDate: dueDateTime,
      allowLateSubmission: _allowLateSubmission,
      latePenaltyPercent: _assignment?.latePenaltyPercent ?? 10,
      isPublished: isPublished,
      createdAt: _assignment?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _saveAssignment({bool forceDraft = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final repository = context.read<AssignmentRepository>();
    final uploadedThisAttempt = <AssignmentAttachment>[];
    var assignmentSaved = false;

    try {
      if (!_recordExists && _pendingMaterials.isNotEmpty) {
        final initialDraft = _buildAssignment(
          attachments: _attachments,
          isPublished: false,
        );
        await repository.createAssignment(initialDraft);
        _recordExists = true;
        _assignment = initialDraft;
      }

      for (final pending in _pendingMaterials) {
        final uploaded = await repository.uploadAttachment(
          courseId: widget.courseId,
          assignmentId: _workingAssignmentId,
          userId: _currentUserId,
          fileName: pending.file.name,
          mimeType: pending.file.mimeType,
          bytes: pending.file.bytes,
          isSubmission: false,
        );
        uploadedThisAttempt.add(uploaded);
      }

      final saved = _buildAssignment(
        attachments: [..._attachments, ...uploadedThisAttempt],
        isPublished: forceDraft ? false : _isPublished,
      );
      if (_recordExists) {
        await repository.updateAssignment(saved);
      } else {
        await repository.createAssignment(saved);
        _recordExists = true;
      }
      assignmentSaved = true;

      for (final attachment in _removedStoredMaterials) {
        try {
          await repository.deleteStoredAttachment(attachment);
        } catch (_) {
          // The assignment record is authoritative; orphan cleanup can retry later.
        }
      }

      if (!mounted) return;
      setState(() {
        _assignment = saved;
        _attachments = saved.attachments;
        _pendingMaterials.clear();
        _removedStoredMaterials.clear();
        _hasChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            forceDraft || !saved.isPublished
                ? 'Assignment saved as a draft.'
                : 'Assignment published.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      _leaveEditor();
    } catch (error) {
      if (!assignmentSaved) {
        for (final attachment in uploadedThisAttempt) {
          try {
            await repository.deleteStoredAttachment(attachment);
          } catch (_) {}
        }
      }
      if (mounted) _showError('Failed to save assignment: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickMaterial() async {
    if (_isPickingFile || _isSaving) return;
    if (_attachmentCount >= AssignmentRepository.maxAttachments) {
      _showError('You can attach up to 10 items.');
      return;
    }
    setState(() => _isPickingFile = true);
    try {
      final file = await pickAssignmentFile();
      if (file == null || !mounted) return;
      setState(() {
        _pendingMaterials.add(
          _PendingMaterial(id: const Uuid().v4(), file: file),
        );
        _hasChanges = true;
      });
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  Future<void> _addLink() async {
    if (_attachmentCount >= AssignmentRepository.maxAttachments) {
      _showError('You can attach up to 10 items.');
      return;
    }

    var linkName = '';
    var linkUrl = '';
    final formKey = GlobalKey<FormState>();
    final attachment = await showDialog<AssignmentAttachment>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a web link'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('assignment-material-link-url'),
                autofocus: true,
                keyboardType: TextInputType.url,
                onChanged: (value) => linkUrl = value,
                decoration: const InputDecoration(
                  labelText: 'Web address',
                  hintText: 'https://example.com',
                  prefixIcon: Icon(Icons.link),
                ),
                validator: validateWebUrl,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('assignment-material-link-name'),
                onChanged: (value) => linkName = value,
                decoration: const InputDecoration(
                  labelText: 'Display name (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final uri = normalizeWebUrl(linkUrl);
              Navigator.pop(
                dialogContext,
                AssignmentAttachment(
                  id: const Uuid().v4(),
                  name: linkName.trim().isEmpty ? uri.host : linkName.trim(),
                  kind: AssignmentAttachmentKind.link,
                  url: uri.toString(),
                ),
              );
            },
            child: const Text('Add link'),
          ),
        ],
      ),
    );

    if (attachment != null && mounted) {
      setState(() {
        _attachments.add(attachment);
        _hasChanges = true;
      });
    }
  }

  Future<void> _openAttachment(AssignmentAttachment attachment) async {
    try {
      final value = await context.read<AssignmentRepository>().getAttachmentUrl(
        attachment,
      );
      final opened = await launchUrl(
        Uri.parse(value),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('No app can open this attachment.');
    } catch (error) {
      if (mounted) _showError('Could not open attachment: $error');
    }
  }

  void _removeAttachment(AssignmentAttachment attachment) {
    setState(() {
      _attachments.removeWhere((item) => item.id == attachment.id);
      if (attachment.isStoredFile) _removedStoredMaterials.add(attachment);
      _hasChanges = true;
    });
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _dueDate = date;
      _dueTime ??= const TimeOfDay(hour: 23, minute: 59);
      _hasChanges = true;
    });
  }

  Future<void> _selectDueTime() async {
    if (_dueDate == null) await _selectDueDate();
    if (!mounted || _dueDate == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 23, minute: 59),
    );
    if (time != null && mounted) {
      setState(() {
        _dueTime = time;
        _hasChanges = true;
      });
    }
  }

  void _leaveEditor() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _handleExitRequest() async {
    if (_allowPop || _isExitDialogOpen || _isSaving) return;
    if (!_hasChanges) {
      _leaveEditor();
      return;
    }

    _isExitDialogOpen = true;
    final action = await showDialog<_AssignmentExitAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        title: const Text('Leave assignment editor?'),
        content: const Text(
          'Unsaved assignment details and attachments will be lost. You can '
          'save this assignment as a draft and finish it later.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _AssignmentExitAction.keepEditing),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _AssignmentExitAction.discard),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _AssignmentExitAction.saveDraft),
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
    _isExitDialogOpen = false;
    if (!mounted) return;

    switch (action) {
      case _AssignmentExitAction.discard:
        _leaveEditor();
      case _AssignmentExitAction.saveDraft:
        await _saveAssignment(forceDraft: true);
      case _AssignmentExitAction.keepEditing:
      case null:
        return;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(userFriendlyErrorMessage(message)),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final canEdit =
        authState is AuthAuthenticated &&
        (authState.user.role == 'instructor' || authState.user.role == 'admin');
    if (!canEdit) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assignment Editor')),
        body: const Center(
          child: Text('Only instructors can edit assignments.'),
        ),
      );
    }

    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleExitRequest();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            onPressed: _handleExitRequest,
            icon: const Icon(Icons.close),
          ),
          title: Text(
            widget.assignmentId == null
                ? 'Create assignment'
                : 'Edit assignment',
            style: AppTextStyles.h4,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: _isLoading || _isSaving
                    ? null
                    : () => _saveAssignment(),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isPublished
                            ? Icons.send_outlined
                            : Icons.save_outlined,
                      ),
                label: Text(_isPublished ? 'Assign' : 'Save draft'),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 850;
                    final main = _buildMainEditor();
                    final settings = _buildSettings();
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.all(isWide ? 28 : 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: main),
                                    const SizedBox(width: 20),
                                    SizedBox(width: 310, child: settings),
                                  ],
                                )
                              : Column(
                                  children: [
                                    main,
                                    const SizedBox(height: 16),
                                    settings,
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildMainEditor() {
    return _EditorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    TextFormField(
                      key: const ValueKey('assignment-title'),
                      controller: _titleController,
                      onChanged: (_) => _markChanged(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Assignment title',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter an assignment title.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const ValueKey('assignment-instructions'),
                      controller: _instructionsController,
                      onChanged: (_) => _markChanged(),
                      minLines: 6,
                      maxLines: 14,
                      decoration: const InputDecoration(
                        labelText: 'Instructions',
                        hintText: 'Explain what students need to do...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Materials', style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text(
            'Add reference files or web links for students.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          if (_attachments.isNotEmpty || _pendingMaterials.isNotEmpty) ...[
            const SizedBox(height: 14),
            ..._attachments.map(
              (attachment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AssignmentAttachmentTile(
                  attachment: attachment,
                  onOpen: () => _openAttachment(attachment),
                  onRemove: () => _removeAttachment(attachment),
                ),
              ),
            ),
            ..._pendingMaterials.map(
              (pending) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AssignmentAttachmentTile(
                  attachment: pending.preview,
                  onRemove: () {
                    setState(() {
                      _pendingMaterials.remove(pending);
                      _hasChanges = true;
                    });
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isPickingFile ? null : _pickMaterial,
                icon: _isPickingFile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: const Text('Upload file'),
              ),
              OutlinedButton.icon(
                onPressed: _addLink,
                icon: const Icon(Icons.link),
                label: const Text('Add link'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: _isCodeActivity,
            title: const Text('Advanced code activity'),
            subtitle: const Text('Optional built-in code editor settings'),
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable code editor'),
                value: _isCodeActivity,
                onChanged: (value) {
                  setState(() {
                    _isCodeActivity = value;
                    if (value && _language == ProgrammingLanguage.plaintext) {
                      _language = ProgrammingLanguage.python;
                    }
                    _hasChanges = true;
                  });
                },
              ),
              if (_isCodeActivity) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<ProgrammingLanguage>(
                  initialValue: _language,
                  decoration: const InputDecoration(
                    labelText: 'Programming language',
                    prefixIcon: Icon(Icons.code),
                  ),
                  items: ProgrammingLanguage.values
                      .where(
                        (language) => language != ProgrammingLanguage.plaintext,
                      )
                      .map(
                        (language) => DropdownMenuItem(
                          value: language,
                          child: Text(language.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _language = value;
                      _hasChanges = true;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _starterCodeController,
                  onChanged: (_) => _markChanged(),
                  minLines: 5,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Starter code (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _solutionCodeController,
                  onChanged: (_) => _markChanged(),
                  minLines: 5,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Reference solution (instructor only)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    final dateLabel = _dueDate == null
        ? 'No due date'
        : DateFormat('MMM d, y').format(_dueDate!);
    final timeLabel = _dueTime == null ? 'No time' : _dueTime!.format(context);

    return _EditorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assignment settings', style: AppTextStyles.h4),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('assignment-points'),
            controller: _pointsController,
            onChanged: (_) => _markChanged(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Points',
              prefixIcon: Icon(Icons.star_outline),
            ),
            validator: (value) {
              final points = int.tryParse(value?.trim() ?? '');
              if (points == null || points < 0 || points > 10000) {
                return 'Enter 0 to 10,000 points.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Due date'),
            subtitle: Text(dateLabel),
            onTap: _selectDueDate,
            trailing: _dueDate == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    tooltip: 'Remove due date',
                    onPressed: () {
                      setState(() {
                        _dueDate = null;
                        _dueTime = null;
                        _hasChanges = true;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          if (_dueDate != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Due time'),
              subtitle: Text(timeLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectDueTime,
            ),
          const Divider(height: 24),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Require student work'),
            subtitle: const Text('Students must attach a file or link'),
            value: _requiresAttachment,
            onChanged: (value) {
              setState(() {
                _requiresAttachment = value;
                _hasChanges = true;
              });
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow late submissions'),
            value: _allowLateSubmission,
            onChanged: (value) {
              setState(() {
                _allowLateSubmission = value;
                _hasChanges = true;
              });
            },
          ),
          const Divider(height: 24),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Publish now'),
            subtitle: Text(
              _isPublished
                  ? 'Students can see this assignment'
                  : 'Only instructors can see this draft',
            ),
            value: _isPublished,
            onChanged: (value) {
              setState(() {
                _isPublished = value;
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  final Widget child;

  const _EditorCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.backgroundSecondary,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}
