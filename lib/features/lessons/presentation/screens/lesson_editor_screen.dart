import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/url_utils.dart';
import '../../data/models/models.dart';
import '../../data/repositories/lesson_repository.dart';

/// Screen for creating and editing lessons
class LessonEditorScreen extends StatefulWidget {
  final String courseId;
  final String? lessonId; // null = create new, otherwise edit

  const LessonEditorScreen({super.key, required this.courseId, this.lessonId});

  @override
  State<LessonEditorScreen> createState() => _LessonEditorScreenState();
}

class _LessonEditorScreenState extends State<LessonEditorScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _durationController = TextEditingController(text: '10');

  late TabController _tabController;

  bool _isLoading = false;
  bool _isSaving = false;
  LessonModel? _lesson;
  List<ModuleModel> _modules = [];

  // New lessons use the database-compatible default. Existing lessons keep
  // their stored type when edited, without exposing it as a form choice.
  LessonType get _effectiveLessonType => _lesson?.type ?? LessonType.text;

  // Lesson settings
  String? _moduleId; // loaded dynamically
  bool _isPublished = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadModules();
    if (widget.lessonId != null) {
      _loadLesson();
    }
  }

  Future<void> _loadModules() async {
    try {
      final repo = context.read<LessonRepository>();
      final modules = await repo.getModules(widget.courseId);
      if (mounted) {
        setState(() {
          _modules = modules;
          if (_moduleId == null && modules.isNotEmpty) {
            _moduleId = modules.first.id;
          }
        });
      }
    } catch (_) {
      // ignore — module picker will be empty
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _videoUrlController.dispose();
    _durationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLesson() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<LessonRepository>();
      final lesson = await repo.getLesson(widget.courseId, widget.lessonId!);
      if (lesson != null) {
        setState(() {
          _lesson = lesson;
          _titleController.text = lesson.title;
          _descriptionController.text = lesson.description ?? '';
          _contentController.text = lesson.content ?? '';
          _videoUrlController.text = lesson.videoUrl ?? '';
          _durationController.text = lesson.durationMinutes.toString();
          _moduleId = lesson.moduleId;
          _isPublished = lesson.isPublished;
        });
      }
    } catch (e) {
      _showError('Failed to load lesson: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLesson({bool attachAfterSave = false}) async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      if (attachAfterSave && !_isPublished) {
        final shouldPublish = await _confirmPublishBeforeAttaching();
        if (shouldPublish != true || !mounted) return;
        setState(() => _isPublished = true);
      }

      final repo = context.read<LessonRepository>();
      final now = DateTime.now();
      String? savedLessonId = widget.lessonId;
      final rawVideoUrl = _effectiveLessonType == LessonType.video
          ? _videoUrlController.text.trim()
          : '';
      final videoUrl = rawVideoUrl.isEmpty
          ? null
          : normalizeWebUrl(rawVideoUrl).toString();

      if (widget.lessonId == null) {
        final lesson = await repo.createLesson(
          courseId: widget.courseId,
          moduleId:
              _moduleId ??
              (_modules.isNotEmpty ? _modules.first.id : const Uuid().v4()),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          order: _lesson?.order ?? 0,
          type: LessonType.text,
          content: _contentController.text.trim().isEmpty
              ? null
              : _contentController.text.trim(),
          videoUrl: videoUrl,
          durationMinutes: int.tryParse(_durationController.text) ?? 10,
          isPublished: _isPublished,
        );
        savedLessonId = lesson.id;
      } else {
        await repo.updateLesson(widget.courseId, widget.lessonId!, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'content': _contentController.text.trim().isEmpty
              ? null
              : _contentController.text.trim(),
          'videoUrl': videoUrl,
          'durationMinutes': int.tryParse(_durationController.text) ?? 10,
          'isPublished': _isPublished,
          'updatedAt': now.toIso8601String(),
        });
      }

      if (mounted) {
        if (attachAfterSave && savedLessonId != null) {
          await context.push(
            AppRoutes.uploadLessonFilePath(widget.courseId, savedLessonId),
          );
          if (mounted) context.pop(true);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lessonId == null
                  ? 'Lesson created successfully!'
                  : 'Lesson updated successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      _showError('Failed to save lesson: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(userFriendlyErrorMessage(message)),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<bool?> _confirmPublishBeforeAttaching() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish lesson?'),
        content: const Text(
          'Students can only see resources in published lessons. '
          'Publish this lesson and continue to attach a file or web link?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep draft'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish & attach'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.lessonId == null ? 'Create Lesson' : 'Edit Lesson',
          style: AppTextStyles.h4,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Content'),
          ],
          indicatorColor: AppColors.primary,
        ),
        actions: [
          if (!_isLoading) ...[
            TextButton(
              onPressed: _isSaving ? null : _saveLesson,
              child: const Text('Save'),
            ),
            IconButton(
              tooltip: 'Publish and attach a file or web link',
              onPressed: _isSaving
                  ? null
                  : () => _saveLesson(attachAfterSave: true),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_outlined),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [_buildDetailsTab(), _buildContentTab()],
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
                    labelText: 'Lesson Title',
                    hintText: 'Enter lesson title',
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief description of the lesson',
                  ),
                  maxLines: 2,
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

                // Module picker
                if (_modules.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _moduleId,
                    decoration: const InputDecoration(labelText: 'Module'),
                    items: _modules.map<DropdownMenuItem<String>>((m) {
                      return DropdownMenuItem<String>(
                        value: m.id,
                        child: Text(m.title),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _moduleId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Duration
                TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    hintText: 'Estimated time to complete',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Video URL (for video lessons)
                if (_effectiveLessonType == LessonType.video) ...[
                  TextFormField(
                    controller: _videoUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Video URL',
                      hintText: 'YouTube, Vimeo, or direct video URL',
                      prefixIcon: Icon(Icons.video_library),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    validator: validateWebUrl,
                  ),
                  const SizedBox(height: 16),
                ],

                // Published
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Published'),
                    subtitle: const Text('Make visible to students'),
                    value: _isPublished,
                    onChanged: (value) => setState(() => _isPublished = value),
                    activeThumbColor: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
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
                Text('Lesson Content', style: AppTextStyles.h4),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Markdown',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getContentHint(),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextFormField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText: _getContentPlaceholder(),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                    fontFamily: _effectiveLessonType == LessonType.code
                        ? 'monospace'
                        : null,
                    color: _effectiveLessonType == LessonType.code
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    height: _effectiveLessonType == LessonType.code
                        ? 1.4
                        : null,
                  ),
                  cursorColor: _effectiveLessonType == LessonType.code
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getContentHint() {
    switch (_effectiveLessonType) {
      case LessonType.text:
        return 'Write your lesson content using Markdown formatting';
      case LessonType.video:
        return 'Add any supplementary notes or resources for the video';
      case LessonType.code:
        return 'Write code examples and explanations using Markdown with code blocks';
      case LessonType.quiz:
        return 'Add any instructions or context for the quiz';
    }
  }

  String _getContentPlaceholder() {
    switch (_effectiveLessonType) {
      case LessonType.text:
        return '''# Lesson Title

## Introduction
Start with an engaging introduction...

## Main Content
Explain the key concepts here...

### Example
Provide examples to illustrate...

## Summary
Wrap up with key takeaways...
''';
      case LessonType.video:
        return '''## Video Notes

Key points covered in this video:
- Point 1
- Point 2
- Point 3

## Additional Resources
- [Link 1](url)
- [Link 2](url)
''';
      case LessonType.code:
        return '''# Code Tutorial

## Concept
Explain the concept here...

## Example Code

```dart
void main() {
  print('Hello, World!');
}
```

## Explanation
Walk through the code step by step...
''';
      case LessonType.quiz:
        return '''## Quiz Instructions

Complete the following quiz to test your knowledge.

- Read each question carefully
- Select the best answer
- You can review your answers at the end
''';
    }
  }
}
