import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
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

String _criterionId(String? storedId, {Set<String>? usedIds}) {
  final isUsable =
      storedId != null &&
      storedId.trim().isNotEmpty &&
      storedId.length <= 64 &&
      (usedIds == null || !usedIds.contains(storedId));
  if (isUsable) {
    usedIds?.add(storedId);
    return storedId;
  }

  var generated = const Uuid().v4();
  while (usedIds?.contains(generated) ?? false) {
    generated = const Uuid().v4();
  }
  usedIds?.add(generated);
  return generated;
}

class _CriterionInput {
  final String id;
  final TextEditingController nameController;
  final TextEditingController percentageController;

  _CriterionInput({String? id, String? name, double? percentage})
    : id = _criterionId(id),
      nameController = TextEditingController(text: name ?? ''),
      percentageController = TextEditingController(
        text: percentage == null ? '' : _formatNumber(percentage),
      );

  void dispose() {
    nameController.dispose();
    percentageController.dispose();
  }
}

String _formatNumber(num value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String? _optionalCode(String value) => value.trim().isEmpty ? null : value;

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
  static const _activityCodeLanguages = <ProgrammingLanguage>[
    ProgrammingLanguage.python,
    ProgrammingLanguage.c,
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _pointsController = TextEditingController(text: '100');
  final _starterCodeController = TextEditingController();
  final _solutionCodeController = TextEditingController();
  final List<_CriterionInput> _criteria = [];

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
    if (widget.assignmentId != null) {
      _loadAssignment();
    } else {
      _criteria.add(_CriterionInput());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _pointsController.dispose();
    _starterCodeController.dispose();
    _solutionCodeController.dispose();
    for (final criterion in _criteria) {
      criterion.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAssignment() async {
    setState(() => _isLoading = true);
    try {
      final assignment = await context
          .read<AssignmentRepository>()
          .getAssignment(_workingAssignmentId);
      if (assignment == null) throw Exception('Activity not found.');
      if (!mounted) return;
      setState(() {
        _assignment = assignment;
        _recordExists = true;
        _titleController.text = assignment.title;
        _instructionsController.text = assignment.instructions ?? '';
        _pointsController.text = assignment.maxPoints.toString();
        for (final criterion in _criteria) {
          criterion.dispose();
        }
        final storedCriteria = assignment.gradingCriteria.isEmpty
            ? [
                GradingCriterion(
                  id: const Uuid().v4(),
                  name: 'Overall',
                  percentage: 100,
                ),
              ]
            : assignment.gradingCriteria;
        final usedCriterionIds = <String>{};
        _criteria
          ..clear()
          ..addAll(
            storedCriteria.map(
              (criterion) => _CriterionInput(
                id: _criterionId(criterion.id, usedIds: usedCriterionIds),
                name: criterion.name,
                percentage: criterion.percentage,
              ),
            ),
          );
        _starterCodeController.text = assignment.starterCode ?? '';
        _solutionCodeController.text = assignment.solutionCode ?? '';
        _attachments = List.of(assignment.attachments);
        _language = _activityEditorLanguage(assignment);
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
      _showError('Failed to load activity: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markChanged({bool rebuild = false}) {
    if (rebuild || !_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  ProgrammingLanguage _activityEditorLanguage(AssignmentModel assignment) {
    if (!assignment.isCodeActivity) return ProgrammingLanguage.plaintext;
    return switch (assignment.language) {
      ProgrammingLanguage.python => ProgrammingLanguage.python,
      ProgrammingLanguage.c || ProgrammingLanguage.cpp => ProgrammingLanguage.c,
      _ => ProgrammingLanguage.python,
    };
  }

  void _addCriterion({bool markChanged = true}) {
    setState(() {
      _criteria.add(_CriterionInput());
      if (markChanged) _hasChanges = true;
    });
  }

  void _removeCriterion(_CriterionInput criterion) {
    setState(() {
      _criteria.remove(criterion);
      criterion.dispose();
      _hasChanges = true;
    });
  }

  List<GradingCriterion> get _gradingCriteria => _criteria
      .map(
        (criterion) => GradingCriterion(
          id: criterion.id,
          name: criterion.nameController.text.trim(),
          percentage:
              double.tryParse(criterion.percentageController.text.trim()) ?? 0,
        ),
      )
      .toList(growable: false);

  double get _criteriaTotal => _gradingCriteria.totalPercentage;

  int get _totalPoints => int.tryParse(_pointsController.text.trim()) ?? 0;

  String? _validateCriteriaTotal() {
    if (_criteria.isEmpty) return 'Add at least one grading criterion.';
    final total = _criteriaTotal;
    if ((total - 100).abs() < 0.001) return null;
    if (total < 100) {
      return 'Criteria are ${_formatNumber(100 - total)}% below 100%.';
    }
    return 'Criteria are ${_formatNumber(total - 100)}% above 100%.';
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
        ? (existingDescription.isEmpty ? 'Activity' : existingDescription)
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
      starterCode: _isCodeActivity
          ? _optionalCode(_starterCodeController.text)
          : null,
      solutionCode: _isCodeActivity
          ? _optionalCode(_solutionCodeController.text)
          : null,
      attachments: attachments,
      requiresAttachment: _isCodeActivity ? false : _requiresAttachment,
      maxPoints: int.tryParse(_pointsController.text.trim()) ?? 100,
      gradingCriteria: _gradingCriteria,
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
                ? 'Activity saved as a draft.'
                : 'Activity published.',
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
      if (mounted) _showError('Failed to save activity: $error');
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
        title: const Text('Leave activity editor?'),
        content: const Text(
          'Unsaved activity details and attachments will be lost. You can '
          'save this activity as a draft and finish it later.',
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
    final canEdit = authState is AuthAuthenticated && authState.user.isStaff;
    if (!canEdit) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity Editor')),
        body: const Center(
          child: Text('Only instructors can edit activities.'),
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
            widget.assignmentId == null ? 'Create activity' : 'Edit activity',
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
                label: Text(_isPublished ? 'Publish' : 'Save draft'),
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
                        hintText: 'Activity title',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter an activity title.'
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
          const Divider(),
          const SizedBox(height: 20),
          _buildGradingCriteriaSection(),
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
                    if (value) {
                      _requiresAttachment = false;
                      if (_language == ProgrammingLanguage.plaintext) {
                        _language = ProgrammingLanguage.python;
                      }
                    }
                    _hasChanges = true;
                  });
                },
              ),
              if (_isCodeActivity) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<ProgrammingLanguage>(
                  key: const ValueKey('activity-language-dropdown'),
                  initialValue: _language,
                  decoration: const InputDecoration(
                    labelText: 'Programming language',
                    prefixIcon: Icon(Icons.code),
                  ),
                  items: _activityCodeLanguages
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Starter code (optional)',
                    style: AppTextStyles.label,
                  ),
                ),
                const SizedBox(height: 8),
                CodeEditor(
                  key: const ValueKey('activity-starter-code-editor'),
                  initialCode: _starterCodeController.text,
                  language: _language,
                  languageLabel: 'Starter · ${_language.displayName}',
                  height: 240,
                  onChanged: (code) {
                    _starterCodeController.text = code;
                    _markChanged();
                  },
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Reference solution (instructor only)',
                    style: AppTextStyles.label,
                  ),
                ),
                const SizedBox(height: 8),
                CodeEditor(
                  key: const ValueKey('activity-reference-code-editor'),
                  initialCode: _solutionCodeController.text,
                  language: _language,
                  languageLabel: 'Solution · ${_language.displayName}',
                  height: 240,
                  onChanged: (code) {
                    _solutionCodeController.text = code;
                    _markChanged();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradingCriteriaSection() {
    final percentageTotal = _criteriaTotal;
    final isComplete = (percentageTotal - 100).abs() < 0.001;
    final isOver = percentageTotal > 100;
    final statusColor = isComplete
        ? AppColors.success
        : isOver
        ? AppColors.error
        : AppColors.warning;
    final statusText = isComplete
        ? 'Ready - criteria total exactly 100%.'
        : isOver
        ? 'Reduce criteria by ${_formatNumber(percentageTotal - 100)}%.'
        : 'Add ${_formatNumber(100 - percentageTotal)}% more.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Grading criteria', style: AppTextStyles.h4)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_formatNumber(percentageTotal)} / 100%',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Enter Total Points first, then divide the activity into percentage-based criteria.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: TextFormField(
            key: const ValueKey('assignment-points'),
            controller: _pointsController,
            onChanged: (_) => _markChanged(rebuild: true),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Total Points',
              prefixIcon: Icon(Icons.star_outline),
            ),
            validator: (value) {
              final points = int.tryParse(value?.trim() ?? '');
              if (points == null || points < 1 || points > 10000) {
                return 'Enter 1 to 10,000 points.';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 18),
        ..._criteria.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCriterionInput(entry.key, entry.value),
          ),
        ),
        FormField<bool>(
          initialValue: true,
          validator: (_) => _validateCriteriaTotal(),
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusText,
                style: TextStyle(
                  color: field.hasError ? AppColors.error : statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (field.hasError && field.errorText != statusText) ...[
                const SizedBox(height: 4),
                Text(
                  field.errorText!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _criteria.length >= 50 ? null : () => _addCriterion(),
          icon: const Icon(Icons.add),
          label: const Text('Add criterion'),
        ),
      ],
    );
  }

  Widget _buildCriterionInput(int index, _CriterionInput criterion) {
    final percentage =
        double.tryParse(criterion.percentageController.text.trim()) ?? 0;
    final equivalentPoints = _totalPoints * percentage / 100;

    final nameField = TextFormField(
      key: ValueKey('activity-criterion-name-${criterion.id}'),
      controller: criterion.nameController,
      onChanged: (_) => _markChanged(rebuild: true),
      maxLength: 120,
      decoration: const InputDecoration(
        labelText: 'Criteria Name',
        hintText: 'e.g. Accuracy',
        counterText: '',
        prefixIcon: Icon(Icons.checklist_outlined),
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Enter a criteria name.'
          : null,
    );
    final percentageField = TextFormField(
      key: ValueKey('activity-criterion-percentage-${criterion.id}'),
      controller: criterion.percentageController,
      onChanged: (_) => _markChanged(rebuild: true),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(?:\.\d{0,2})?$')),
      ],
      decoration: const InputDecoration(
        labelText: 'Percentage Weight',
        suffixText: '%',
      ),
      validator: (value) {
        final parsed = double.tryParse(value?.trim() ?? '');
        if (parsed == null || parsed <= 0 || parsed > 100) {
          return 'Enter over 0, up to 100.';
        }
        return null;
      },
    );
    final pointsDisplay = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Equivalent Points',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '${_formatNumber(equivalentPoints)} pts',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    final removeButton = IconButton(
      tooltip: 'Remove criterion ${index + 1}',
      onPressed: () => _removeCriterion(criterion),
      icon: const Icon(Icons.delete_outline),
      color: AppColors.error,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 620) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: nameField),
              const SizedBox(width: 10),
              SizedBox(width: 170, child: percentageField),
              const SizedBox(width: 10),
              SizedBox(width: 145, child: pointsDisplay),
              removeButton,
            ],
          );
        }
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Criterion ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  removeButton,
                ],
              ),
              nameField,
              const SizedBox(height: 10),
              percentageField,
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: pointsDisplay),
            ],
          ),
        );
      },
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
          Text('Activity settings', style: AppTextStyles.h4),
          const SizedBox(height: 18),
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
            subtitle: Text(
              _isCodeActivity
                  ? 'Students turn in code from the editor. A file or link is optional.'
                  : 'Students must attach a file or link',
            ),
            value: _isCodeActivity ? false : _requiresAttachment,
            onChanged: _isCodeActivity
                ? null
                : (value) {
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
                  ? 'Students can see this activity'
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
