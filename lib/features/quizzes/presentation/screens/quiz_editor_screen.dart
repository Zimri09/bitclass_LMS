import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_time_formatters.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/question_model.dart';
import '../../data/models/quiz_generation_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/quiz_repository.dart';

enum _QuestionCreationMode { manual, file }

enum _QuizExitAction { keepEditing, discard, saveDraft }

typedef QuizSourcePicker = Future<QuizSourceDocument?> Function();

@immutable
class QuizSourceDocument {
  final String name;
  final Uint8List bytes;

  const QuizSourceDocument({required this.name, required this.bytes});
}

String _fileExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// Screen for creating and editing quizzes
class QuizEditorScreen extends StatefulWidget {
  final String courseId;
  final String? quizId; // null = create new, otherwise edit
  final QuizSourcePicker? sourcePicker;

  const QuizEditorScreen({
    super.key,
    required this.courseId,
    this.quizId,
    this.sourcePicker,
  });

  @override
  State<QuizEditorScreen> createState() => _QuizEditorScreenState();
}

class _QuizEditorScreenState extends State<QuizEditorScreen> {
  static const int _defaultTimeLimitMinutes = 15;
  static const int _defaultPassingScore = 50;
  static const int _defaultMaxAttempts = 1;

  static const int _maxPdfBytes = 8 * 1024 * 1024;
  static const int _maxTextBytes = 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _generationInstructionsController = TextEditingController();
  late final String _workingQuizId;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPickingSource = false;
  bool _isGenerating = false;
  bool _hasGeneratedQuestions = false;
  bool _allowPop = false;
  bool _isExitDialogOpen = false;
  QuizModel? _quiz;
  List<QuestionModel> _questions = [];
  QuizSourceDocument? _sourceDocument;
  int _generationRequestId = 0;
  _QuestionCreationMode _creationMode = _QuestionCreationMode.manual;
  QuizGenerationQuestionType _generationType = QuizGenerationQuestionType.mixed;
  QuizGenerationDifficulty _generationDifficulty =
      QuizGenerationDifficulty.mixed;
  int _generationQuestionCount = 10;
  int _multipleChoicePoints = QuizGenerationPoints.defaults.multipleChoice;
  int _trueFalsePoints = QuizGenerationPoints.defaults.trueFalse;
  int _shortAnswerPoints = QuizGenerationPoints.defaults.shortAnswer;

  // Quiz settings
  int _timeLimitMinutes = _defaultTimeLimitMinutes;
  int _passingScore = _defaultPassingScore;
  bool _shuffleQuestions = false;
  bool _shuffleAnswers = true;
  bool _allowRetakes = true;
  int _maxAttempts = _defaultMaxAttempts;
  bool _isPublished = false;
  DateTime _dueDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 7)),
  );
  TimeOfDay _dueTime = const TimeOfDay(hour: 23, minute: 59);

  DateTime get _dueDateTime => DateTime(
    _dueDate.year,
    _dueDate.month,
    _dueDate.day,
    _dueTime.hour,
    _dueTime.minute,
  );

  @override
  void initState() {
    super.initState();
    _workingQuizId = widget.quizId ?? const Uuid().v4();
    if (widget.quizId != null) {
      _loadQuiz();
    }
  }

  @override
  void dispose() {
    _generationRequestId++;
    _titleController.dispose();
    _descriptionController.dispose();
    _generationInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<QuizRepository>();
      final quiz = await repo.getQuiz(widget.quizId!);
      if (quiz != null) {
        final questions = await repo.getQuestions(widget.quizId!);
        setState(() {
          _quiz = quiz;
          _questions = questions;
          _titleController.text = quiz.title;
          _descriptionController.text = quiz.description ?? '';
          _timeLimitMinutes = quiz.timeLimitMinutes;
          _passingScore = quiz.passingScore;
          _shuffleQuestions = quiz.shuffleQuestions;
          _shuffleAnswers = quiz.shuffleAnswers;
          _allowRetakes = quiz.allowRetakes;
          _maxAttempts = quiz.maxAttempts;
          _isPublished = quiz.isPublished;
          if (quiz.dueDate != null) {
            _dueDate = DateUtils.dateOnly(quiz.dueDate!.toLocal());
            _dueTime = TimeOfDay.fromDateTime(quiz.dueDate!.toLocal());
          }
        });
      }
    } catch (e) {
      _showError('Failed to load quiz: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _saveQuiz({bool asDraft = false}) async {
    if (_isSaving) return false;
    if (!asDraft) {
      if (!_formKey.currentState!.validate()) return false;
      if (!_dueDateTime.isAfter(DateTime.now())) {
        _showError('Choose a future due date and time.');
        return false;
      }
      final questionError = _questionValidationError();
      if (questionError != null) {
        _showError(questionError);
        return false;
      }
    }

    setState(() => _isSaving = true);
    try {
      final repo = context.read<QuizRepository>();
      final now = DateTime.now();
      final quizId = _workingQuizId;

      final enteredTitle = _titleController.text.trim();
      final quiz = QuizModel(
        id: quizId,
        courseId: widget.courseId,
        title: asDraft && enteredTitle.isEmpty
            ? 'Untitled Quiz Draft'
            : enteredTitle,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        timeLimitMinutes: _timeLimitMinutes,
        passingScore: _passingScore,
        totalPoints: _questions.fold(0, (sum, q) => sum + q.points),
        questionCount: _questions.length,
        shuffleQuestions: _shuffleQuestions,
        shuffleAnswers: _shuffleAnswers,
        showCorrectAnswers: false,
        allowRetakes: _allowRetakes,
        maxAttempts: _maxAttempts,
        isPublished: asDraft ? false : _isPublished,
        dueDate: _dueDateTime,
        createdAt: _quiz?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.quizId == null) {
        await repo.createQuiz(quiz);
      } else {
        await repo.updateQuiz(quiz);
      }

      // Save questions
      for (final question in _questions) {
        await repo.saveQuestion(question.copyWith(quizId: quizId));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              asDraft
                  ? 'Quiz saved as draft.'
                  : widget.quizId == null
                  ? 'Quiz created successfully!'
                  : 'Quiz updated successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _leaveEditor();
      }
      return true;
    } catch (e) {
      if (mounted) {
        _showError(
          asDraft ? 'Failed to save draft: $e' : 'Failed to save quiz: $e',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _leaveEditor() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _selectDueDate() async {
    final earliestDate = DateUtils.dateOnly(DateTime.now());
    final initialDate = _dueDate.isBefore(earliestDate)
        ? earliestDate
        : _dueDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: earliestDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected == null || !mounted) return;
    setState(() => _dueDate = selected);
  }

  Future<void> _selectDueTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _dueTime,
    );
    if (selected == null || !mounted) return;
    setState(() => _dueTime = selected);
  }

  Future<void> _handleExitRequest() async {
    if (_isExitDialogOpen || _isSaving) return;
    _isExitDialogOpen = true;
    final action = await showDialog<_QuizExitAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        title: const Text('Leave quiz editor?'),
        content: Text(
          _isGenerating
              ? 'Question generation is still running. Leaving or saving now '
                    'will stop it. Any other unsaved quiz changes can still be '
                    'saved as a draft.'
              : 'Your created or generated questions have not been saved yet. '
                    'If you leave now, they will be lost. You can save the quiz '
                    'as a draft and finish it later.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _QuizExitAction.keepEditing),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _QuizExitAction.discard),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _QuizExitAction.saveDraft),
            child: const Text('Save as Draft'),
          ),
        ],
      ),
    );
    _isExitDialogOpen = false;
    if (!mounted) return;

    switch (action) {
      case _QuizExitAction.discard:
        _cancelGeneration(showMessage: false);
        _leaveEditor();
        return;
      case _QuizExitAction.saveDraft:
        _cancelGeneration(showMessage: false);
        await _saveQuiz(asDraft: true);
        return;
      case _QuizExitAction.keepEditing:
      case null:
        return;
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

  String? _questionValidationError() {
    if (_questions.isEmpty) return 'Add at least one question to the quiz.';

    for (var index = 0; index < _questions.length; index++) {
      final question = _questions[index];
      final label = 'Question ${index + 1}';
      if (question.questionText.trim().isEmpty) {
        return '$label needs question text.';
      }
      if (question.points < 1 || question.points > 100) {
        return '$label must be worth between 1 and 100 points.';
      }
      if (question.type == QuestionType.shortAnswer &&
          !question.correctAnswers.any((answer) => answer.trim().isNotEmpty)) {
        return '$label needs at least one accepted answer.';
      }
      if (!_isChoiceQuestion(question.type)) continue;

      if (question.options.length < 2 ||
          question.options.any((option) => option.text.trim().isEmpty)) {
        return '$label needs at least two completed answer choices.';
      }
      final normalizedOptions = question.options
          .map((option) => option.text.trim().toLowerCase())
          .toSet();
      if (normalizedOptions.length != question.options.length) {
        return '$label contains duplicate answer choices.';
      }
      final correctCount = question.options
          .where((option) => option.isCorrect)
          .length;
      if (question.type == QuestionType.multipleSelect) {
        if (correctCount < 1) return '$label needs a correct answer.';
      } else if (correctCount != 1) {
        return '$label must have exactly one correct answer.';
      }
      if (question.type == QuestionType.trueFalse &&
          (question.options.length != 2 ||
              !normalizedOptions.contains('true') ||
              !normalizedOptions.contains('false'))) {
        return '$label must contain only True and False choices.';
      }
    }
    return null;
  }

  bool _isChoiceQuestion(QuestionType type) {
    return type == QuestionType.multipleChoice ||
        type == QuestionType.multipleSelect ||
        type == QuestionType.trueFalse;
  }

  Future<void> _pickSourceFile() async {
    if (_isPickingSource || _isGenerating) return;
    setState(() => _isPickingSource = true);

    try {
      QuizSourceDocument? source;
      if (widget.sourcePicker != null) {
        source = await widget.sourcePicker!();
      } else {
        final file = await fp.FilePicker.pickFile(
          type: fp.FileType.custom,
          allowedExtensions: const ['pdf', 'txt'],
        );
        if (file == null) return;

        final extension = _fileExtension(file.name);
        final maxBytes = extension == 'pdf' ? _maxPdfBytes : _maxTextBytes;
        if (extension != 'pdf' && extension != 'txt') {
          _showError('Only PDF and TXT files are supported right now.');
          return;
        }
        final fileSize = await file.length();
        if (fileSize <= 0 || fileSize > maxBytes) {
          _showError(
            extension == 'pdf'
                ? 'Select a PDF that is no larger than 8 MB.'
                : 'Select a TXT file that is no larger than 1 MB.',
          );
          return;
        }
        source = QuizSourceDocument(
          name: file.name,
          bytes: await file.readAsBytes(),
        );
      }
      if (source == null) return;

      final extension = _fileExtension(source.name);
      final maxBytes = extension == 'pdf' ? _maxPdfBytes : _maxTextBytes;
      if (extension != 'pdf' && extension != 'txt') {
        _showError('Only PDF and TXT files are supported right now.');
        return;
      }
      final fileSize = source.bytes.length;
      if (fileSize <= 0 || fileSize > maxBytes) {
        _showError(
          extension == 'pdf'
              ? 'Select a PDF that is no larger than 8 MB.'
              : 'Select a TXT file that is no larger than 1 MB.',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _sourceDocument = source;
      });
    } catch (error) {
      if (mounted) _showError('Failed to select file: $error');
    } finally {
      if (mounted) setState(() => _isPickingSource = false);
    }
  }

  Future<void> _generateQuestions() async {
    final source = _sourceDocument;
    if (source == null) {
      _showError('Select a PDF or TXT file first.');
      return;
    }
    if (_isGenerating) return;

    final requestId = ++_generationRequestId;
    setState(() => _isGenerating = true);
    try {
      final extension = _fileExtension(source.name);
      final generated = await context
          .read<QuizRepository>()
          .generateQuestionsFromFile(
            courseId: widget.courseId,
            fileName: source.name,
            mimeType: extension == 'pdf' ? 'application/pdf' : 'text/plain',
            bytes: source.bytes,
            questionCount: _generationQuestionCount,
            questionType: _generationType,
            difficulty: _generationDifficulty,
            points: QuizGenerationPoints(
              multipleChoice: _multipleChoicePoints,
              trueFalse: _trueFalsePoints,
              shortAnswer: _shortAnswerPoints,
            ),
            instructions: _generationInstructionsController.text,
          );
      if (!mounted || requestId != _generationRequestId) return;

      setState(() {
        final startingOrder = _questions.length;
        _questions.addAll([
          for (var index = 0; index < generated.length; index++)
            generated[index].copyWith(order: startingOrder + index),
        ]);
        _hasGeneratedQuestions = true;
        _isPublished = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${generated.length} draft questions generated. Review them before publishing.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (mounted && requestId == _generationRequestId) {
        _showError('Question generation failed: $error');
      }
    } finally {
      if (mounted && requestId == _generationRequestId) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _cancelGeneration({bool showMessage = true}) {
    if (!_isGenerating) return;
    _generationRequestId++;
    setState(() => _isGenerating = false);
    if (showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question generation cancelled.')),
      );
    }
  }

  void _addQuestion() {
    final questionId = const Uuid().v4();
    setState(() {
      _questions.add(
        QuestionModel(
          id: questionId,
          quizId: widget.quizId ?? '',
          type: QuestionType.multipleChoice,
          questionText: '',
          options: [
            AnswerOptionModel(id: const Uuid().v4(), text: '', isCorrect: true),
            AnswerOptionModel(
              id: const Uuid().v4(),
              text: '',
              isCorrect: false,
            ),
            AnswerOptionModel(
              id: const Uuid().v4(),
              text: '',
              isCorrect: false,
            ),
            AnswerOptionModel(
              id: const Uuid().v4(),
              text: '',
              isCorrect: false,
            ),
          ],
          correctAnswers: [],
          points: 1,
          order: _questions.length,
        ),
      );
    });
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  void _updateQuestion(int index, QuestionModel question) {
    setState(() => _questions[index] = question);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isInstructor =
        authState is AuthAuthenticated && authState.user.isStaff;
    if (!isInstructor) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz Editor')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only instructors can create or edit quizzes.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleExitRequest();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.quizId == null ? 'Create Quiz' : 'Edit Quiz',
            style: AppTextStyles.h4,
          ),
          actions: [
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: FilledButton(
                  onPressed: _isSaving || _isGenerating
                      ? null
                      : () => _saveQuiz(),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Quiz'),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quiz Details Card
                      _buildQuizDetailsCard(),
                      const SizedBox(height: 24),

                      // Quiz Settings Card
                      _buildQuizSettingsCard(),
                      const SizedBox(height: 24),

                      // Question creation tools
                      _buildQuestionCreationCard(),
                      const SizedBox(height: 24),

                      // Questions Section
                      _buildQuestionsSection(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildQuizDetailsCard() {
    final padding = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quiz Details', style: AppTextStyles.h4),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Quiz Title',
              hintText: 'Enter quiz title',
            ),
            validator: (value) =>
                value?.trim().isEmpty == true ? 'Title is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Enter quiz description',
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildQuizSettingsCard() {
    final padding = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quiz Settings', style: AppTextStyles.h4),
          const SizedBox(height: 16),

          ListTile(
            key: const ValueKey('quiz-due-date'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Due date'),
            subtitle: Text(formatDueDateTime(_dueDateTime)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectDueDate,
          ),
          ListTile(
            key: const ValueKey('quiz-due-time'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Due time'),
            subtitle: Text(_dueTime.format(context)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectDueTime,
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'A due date and time are required. Students cannot start or submit after this deadline.',
            ),
          ),

          // Time limit
          Row(
            children: [
              Expanded(
                child: Text(
                  'Time Limit (minutes)',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: _timeLimitMinutes.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: '0 = No limit'),
                  onChanged: (value) {
                    _timeLimitMinutes =
                        int.tryParse(value) ?? _defaultTimeLimitMinutes;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Passing score
          Row(
            children: [
              Expanded(
                child: Text(
                  'Passing Score (%)',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: _passingScore.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (value) {
                    _passingScore =
                        int.tryParse(value) ?? _defaultPassingScore;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Max attempts
          Row(
            children: [
              Expanded(
                child: Text('Max Attempts', style: AppTextStyles.bodyMedium),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: _maxAttempts.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: '0 = Unlimited'),
                  onChanged: (value) {
                    _maxAttempts =
                        int.tryParse(value) ?? _defaultMaxAttempts;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Toggle switches
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: const Text('Shuffle Questions'),
              subtitle: const Text('Randomize question order for each attempt'),
              value: _shuffleQuestions,
              onChanged: (value) => setState(() => _shuffleQuestions = value),
              activeThumbColor: AppColors.primary,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: const Text('Shuffle Answers'),
              subtitle: const Text(
                'Randomize answer options for each question',
              ),
              value: _shuffleAnswers,
              onChanged: (value) => setState(() => _shuffleAnswers = value),
              activeThumbColor: AppColors.primary,
            ),
          ),
          const Material(
            color: Colors.transparent,
            child: ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Student result privacy'),
              subtitle: Text(
                'Students only see Correct or Incorrect. Answer keys remain available to instructors.',
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: const Text('Allow Retakes'),
              subtitle: const Text('Allow students to retake the quiz'),
              value: _allowRetakes,
              onChanged: (value) => setState(() => _allowRetakes = value),
              activeThumbColor: AppColors.primary,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: const Text('Published'),
              subtitle: const Text('Make quiz visible to students'),
              value: _isPublished,
              onChanged: (value) => setState(() => _isPublished = value),
              activeThumbColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCreationCard() {
    final padding = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    final colors = AppColors.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Questions', style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text(
            'Add questions yourself or create an editable draft from course material.',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<_QuestionCreationMode>(
            segments: const [
              ButtonSegment(
                value: _QuestionCreationMode.manual,
                icon: Icon(Icons.edit_outlined),
                label: Text('Create Manually'),
              ),
              ButtonSegment(
                value: _QuestionCreationMode.file,
                icon: Icon(Icons.auto_awesome),
                label: Text('Generate from File'),
              ),
            ],
            selected: {_creationMode},
            onSelectionChanged: _isGenerating
                ? null
                : (selection) {
                    setState(() => _creationMode = selection.single);
                  },
          ),
          const SizedBox(height: 18),
          if (_creationMode == _QuestionCreationMode.manual)
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: colors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use Add Question below to build the quiz one question at a time.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _sourceDocument == null
                        ? Icons.upload_file_outlined
                        : Icons.description_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sourceDocument == null
                        ? Text(
                            'Choose a PDF (up to 8 MB) or TXT file (up to 1 MB).',
                            style: AppTextStyles.bodySmall,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sourceDocument!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatBytes(_sourceDocument!.bytes.length),
                                style: AppTextStyles.caption.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (_sourceDocument != null)
                    IconButton(
                      tooltip: 'Remove file',
                      onPressed: _isGenerating
                          ? null
                          : () {
                              setState(() {
                                _sourceDocument = null;
                              });
                            },
                      icon: const Icon(Icons.close),
                    )
                  else
                    OutlinedButton(
                      onPressed: _isPickingSource ? null : _pickSourceFile,
                      child: Text(_isPickingSource ? 'Opening...' : 'Choose'),
                    ),
                ],
              ),
            ),
            if (_sourceDocument != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _isGenerating ? null : _pickSourceFile,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Replace file'),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<int>(
                    initialValue: _generationQuestionCount,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Number of questions',
                    ),
                    items: const [5, 10, 15, 20, 25, 30]
                        .map(
                          (count) => DropdownMenuItem(
                            value: count,
                            child: Text('$count questions'),
                          ),
                        )
                        .toList(),
                    onChanged: _isGenerating
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _generationQuestionCount = value);
                            }
                          },
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<QuizGenerationQuestionType>(
                    key: const ValueKey('generation-question-type'),
                    initialValue: _generationType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Question type',
                    ),
                    items: QuizGenerationQuestionType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: _isGenerating
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _generationType = value);
                            }
                          },
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<QuizGenerationDifficulty>(
                    initialValue: _generationDifficulty,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Difficulty'),
                    items: QuizGenerationDifficulty.values
                        .map(
                          (difficulty) => DropdownMenuItem(
                            value: difficulty,
                            child: Text(difficulty.label),
                          ),
                        )
                        .toList(),
                    onChanged: _isGenerating
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _generationDifficulty = value);
                            }
                          },
                  ),
                ),
                if (_generationType == QuizGenerationQuestionType.mixed ||
                    _generationType ==
                        QuizGenerationQuestionType.multipleChoice)
                  _buildGenerationPointsField(
                    type: QuestionType.multipleChoice,
                    label: 'Multiple choice points',
                    value: _multipleChoicePoints,
                    onChanged: (value) => _multipleChoicePoints = value,
                  ),
                if (_generationType == QuizGenerationQuestionType.mixed ||
                    _generationType == QuizGenerationQuestionType.trueFalse)
                  _buildGenerationPointsField(
                    type: QuestionType.trueFalse,
                    label: 'True/False points',
                    value: _trueFalsePoints,
                    onChanged: (value) => _trueFalsePoints = value,
                  ),
                if (_generationType == QuizGenerationQuestionType.mixed ||
                    _generationType == QuizGenerationQuestionType.shortAnswer)
                  _buildGenerationPointsField(
                    type: QuestionType.shortAnswer,
                    label: 'Short answer points',
                    value: _shortAnswerPoints,
                    onChanged: (value) => _shortAnswerPoints = value,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _generationInstructionsController,
              enabled: !_isGenerating,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Topic or instructions (Optional)',
                hintText: 'Example: Focus on chapters 2 and 3',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: const ValueKey('quiz-generation-action'),
                onPressed: _isGenerating
                    ? _cancelGeneration
                    : _sourceDocument == null
                    ? null
                    : _generateQuestions,
                style: _isGenerating
                    ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                    : null,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isGenerating
                      ? 'Cancel Generation'
                      : 'Generate Draft Questions',
                ),
              ),
            ),
            if (_isGenerating) ...[
              const SizedBox(height: 8),
              Text(
                'Generating questions can take up to 90 seconds. You can '
                'cancel at any time.',
                style: AppTextStyles.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  size: 18,
                  color: colors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI-generated questions are added as an unpublished draft. Review every question and answer before saving or publishing.',
                    style: AppTextStyles.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_hasGeneratedQuestions) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Review required: generated questions remain editable below and the quiz has been set to Draft.',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenerationPointsField({
    required QuestionType type,
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<int>(
        key: ValueKey('generation-${type.name}-points'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: List.generate(10, (index) => index + 1)
            .map(
              (points) => DropdownMenuItem(
                value: points,
                child: Text('$points point${points == 1 ? '' : 's'}'),
              ),
            )
            .toList(),
        onChanged: _isGenerating
            ? null
            : (newValue) {
                if (newValue != null) {
                  setState(() => onChanged(newValue));
                }
              },
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kilobytes = bytes / 1024;
    if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
    return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
  }

  Widget _buildQuestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionsHeader(),
        const SizedBox(height: 16),

        if (_questions.isEmpty)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.quiz_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No questions yet',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click "Add Question" to create your first question',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _questions.length,
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = _questions.removeAt(oldIndex);
                _questions.insert(newIndex, item);
                // Update order values
                for (int i = 0; i < _questions.length; i++) {
                  _questions[i] = _questions[i].copyWith(order: i);
                }
              });
            },
            itemBuilder: (context, index) {
              return _QuestionEditor(
                key: ValueKey(_questions[index].id),
                question: _questions[index],
                index: index,
                onUpdate: (q) => _updateQuestion(index, q),
                onRemove: () => _removeQuestion(index),
              );
            },
          ),
      ],
    );
  }

  Widget _buildQuestionsHeader() {
    final title = Text(
      'Questions (${_questions.length})',
      style: AppTextStyles.h4,
    );
    final addButton = ElevatedButton.icon(
      onPressed: _addQuestion,
      icon: const Icon(Icons.add),
      label: const Text('Add Question'),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: addButton),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [title, addButton],
        );
      },
    );
  }
}

/// Widget for editing a single question
class _QuestionEditor extends StatefulWidget {
  final QuestionModel question;
  final int index;
  final ValueChanged<QuestionModel> onUpdate;
  final VoidCallback onRemove;

  const _QuestionEditor({
    super.key,
    required this.question,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late TextEditingController _questionTextController;
  late TextEditingController _explanationController;
  late TextEditingController _pointsController;
  late TextEditingController _acceptedAnswersController;
  late List<TextEditingController> _optionControllers;
  final ScrollController _mobileEditorScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _questionTextController = TextEditingController(
      text: widget.question.questionText,
    );
    _explanationController = TextEditingController(
      text: widget.question.explanation ?? '',
    );
    _pointsController = TextEditingController(
      text: widget.question.points.toString(),
    );
    _acceptedAnswersController = TextEditingController(
      text: widget.question.type == QuestionType.shortAnswer
          ? widget.question.correctAnswers.join('\n')
          : '',
    );
    _optionControllers = widget.question.options
        .map((o) => TextEditingController(text: o.text))
        .toList();
  }

  @override
  void dispose() {
    _mobileEditorScrollController.dispose();
    _questionTextController.dispose();
    _explanationController.dispose();
    _pointsController.dispose();
    _acceptedAnswersController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateQuestion() {
    final options = <AnswerOptionModel>[];
    for (int i = 0; i < _optionControllers.length; i++) {
      final originalOption = i < widget.question.options.length
          ? widget.question.options[i]
          : AnswerOptionModel(
              id: const Uuid().v4(),
              text: '',
              isCorrect: false,
            );
      options.add(
        AnswerOptionModel(
          id: originalOption.id,
          text: _optionControllers[i].text,
          isCorrect: originalOption.isCorrect,
        ),
      );
    }

    final correctAnswers = widget.question.type == QuestionType.shortAnswer
        ? _acceptedAnswersController.text
              .split('\n')
              .map((answer) => answer.trim())
              .where((answer) => answer.isNotEmpty)
              .toList(growable: false)
        : _isChoiceQuestion(widget.question.type)
        ? options
              .where((option) => option.isCorrect)
              .map((option) => option.id)
              .toList(growable: false)
        : widget.question.correctAnswers;

    widget.onUpdate(
      widget.question.copyWith(
        questionText: _questionTextController.text,
        explanation: _explanationController.text.isEmpty
            ? null
            : _explanationController.text,
        points: int.tryParse(_pointsController.text) ?? 1,
        options: options,
        correctAnswers: correctAnswers,
      ),
    );
  }

  void _toggleCorrectAnswer(int optionIndex) {
    final options = List<AnswerOptionModel>.from(widget.question.options);

    if (widget.question.type == QuestionType.multipleChoice) {
      // Single correct answer - uncheck others
      for (int i = 0; i < options.length; i++) {
        options[i] = AnswerOptionModel(
          id: options[i].id,
          text: options[i].text,
          isCorrect: i == optionIndex,
        );
      }
    } else {
      // Multiple correct answers - toggle
      options[optionIndex] = AnswerOptionModel(
        id: options[optionIndex].id,
        text: options[optionIndex].text,
        isCorrect: !options[optionIndex].isCorrect,
      );
    }

    widget.onUpdate(
      widget.question.copyWith(
        options: options,
        correctAnswers: options
            .where((o) => o.isCorrect)
            .map((o) => o.id)
            .toList(),
      ),
    );
  }

  void _addOption() {
    final newOption = AnswerOptionModel(
      id: const Uuid().v4(),
      text: '',
      isCorrect: false,
    );
    _optionControllers.add(TextEditingController());
    widget.onUpdate(
      widget.question.copyWith(
        options: [...widget.question.options, newOption],
      ),
    );
  }

  void _removeOption(int index) {
    if (widget.question.options.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum 2 options required')),
      );
      return;
    }
    _optionControllers[index].dispose();
    _optionControllers.removeAt(index);
    final options = List<AnswerOptionModel>.from(widget.question.options);
    options.removeAt(index);
    widget.onUpdate(widget.question.copyWith(options: options));
  }

  void _changeQuestionType(QuestionType? type) {
    if (type == null) return;
    final answerKindChanged =
        (type == QuestionType.shortAnswer) !=
        (widget.question.type == QuestionType.shortAnswer);
    if (answerKindChanged && type == QuestionType.shortAnswer) {
      _acceptedAnswersController.clear();
    }
    widget.onUpdate(
      widget.question.copyWith(
        type: type,
        options: type == QuestionType.shortAnswer
            ? const []
            : widget.question.options,
        correctAnswers: answerKindChanged
            ? const []
            : widget.question.correctAnswers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editorFields = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionSettings(),
          const SizedBox(height: 16),

          // Question text
          TextFormField(
            controller: _questionTextController,
            decoration: const InputDecoration(
              labelText: 'Question Text',
              hintText: 'Enter your question here...',
            ),
            maxLines: 3,
            onChanged: (_) => _updateQuestion(),
          ),
          const SizedBox(height: 16),

          // Answer options (for choice questions)
          if (_isChoiceQuestion(widget.question.type)) ...[
            Text(
              'Answer Options',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildOptionEditors(),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _addOption,
              icon: Icon(Icons.add),
              label: const Text('Add Option'),
            ),
          ],

          if (widget.question.type == QuestionType.shortAnswer) ...[
            TextFormField(
              key: ValueKey('${widget.question.id}-accepted-answers'),
              controller: _acceptedAnswersController,
              decoration: const InputDecoration(
                labelText: 'Accepted Answers',
                hintText: 'Enter one accepted answer per line',
                helperText: 'Matching ignores capitalization.',
              ),
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => _updateQuestion(),
            ),
            const SizedBox(height: 16),
          ],

          // Explanation
          const SizedBox(height: 16),
          TextFormField(
            controller: _explanationController,
            decoration: const InputDecoration(
              labelText: 'Explanation (Optional)',
              hintText: 'Explain the correct answer...',
            ),
            maxLines: 2,
            onChanged: (_) => _updateQuestion(),
          ),
        ],
      ),
    );
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom;
    final isMobile = mediaQuery.size.width < 600;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: ExpansionTile(
          key: PageStorageKey(widget.question.id),
          maintainState: true,
          initiallyExpanded: widget.question.questionText.isEmpty,
          leading: ReorderableDragStartListener(
            index: widget.index,
            child: Icon(Icons.drag_handle, color: AppColors.textSecondary),
          ),
          title: Text(
            widget.question.questionText.isEmpty
                ? 'Question ${widget.index + 1}'
                : widget.question.questionText,
            style: AppTextStyles.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${_getQuestionTypeName(widget.question.type)} - ${widget.question.points} pts',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: widget.onRemove,
          ),
          children: [
            if (isMobile)
              SizedBox(
                key: ValueKey('${widget.question.id}-scrollable-editor'),
                height: (availableHeight * 0.62).clamp(320.0, 560.0),
                child: Scrollbar(
                  controller: _mobileEditorScrollController,
                  thumbVisibility: true,
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: _mobileEditorScrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: editorFields,
                  ),
                ),
              )
            else
              editorFields,
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionSettings() {
    final questionTypeField = DropdownButtonFormField<QuestionType>(
      key: ValueKey('${widget.question.id}-type'),
      initialValue: widget.question.type,
      decoration: const InputDecoration(labelText: 'Question Type'),
      isExpanded: true,
      items: QuestionType.values.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(
            _getQuestionTypeName(type),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _changeQuestionType,
    );
    final pointsField = TextFormField(
      key: ValueKey('${widget.question.id}-points'),
      controller: _pointsController,
      decoration: const InputDecoration(labelText: 'Points'),
      keyboardType: TextInputType.number,
      onChanged: (_) => _updateQuestion(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            children: [
              questionTypeField,
              const SizedBox(height: 16),
              pointsField,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: questionTypeField),
            const SizedBox(width: 16),
            Expanded(child: pointsField),
          ],
        );
      },
    );
  }

  Widget _buildOptionEditors() {
    // Ensure controllers match options
    while (_optionControllers.length < widget.question.options.length) {
      _optionControllers.add(TextEditingController());
    }

    final editors = List.generate(widget.question.options.length, (index) {
      final option = widget.question.options[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            // Correct answer indicator
            if (widget.question.type == QuestionType.multipleChoice)
              Radio<int>(value: index, activeColor: AppColors.success)
            else
              Checkbox(
                value: option.isCorrect,
                onChanged: (_) => _toggleCorrectAnswer(index),
                activeColor: AppColors.success,
              ),
            // Option text
            Expanded(
              child: TextFormField(
                controller: _optionControllers[index],
                decoration: InputDecoration(
                  hintText: 'Option ${index + 1}',
                  border: OutlineInputBorder(),
                  suffixIcon: option.isCorrect
                      ? Icon(Icons.check_circle, color: AppColors.success)
                      : null,
                ),
                onChanged: (_) => _updateQuestion(),
              ),
            ),
            // Remove option button
            IconButton(
              icon: Icon(Icons.close, size: 20),
              onPressed: () => _removeOption(index),
              color: AppColors.textSecondary,
            ),
          ],
        ),
      );
    });

    if (widget.question.type == QuestionType.multipleChoice) {
      final selectedIndex = widget.question.options.indexWhere(
        (option) => option.isCorrect,
      );
      return RadioGroup<int>(
        groupValue: selectedIndex < 0 ? null : selectedIndex,
        onChanged: (index) {
          if (index != null) {
            _toggleCorrectAnswer(index);
          }
        },
        child: Column(children: editors),
      );
    }

    return Column(children: editors);
  }

  bool _isChoiceQuestion(QuestionType type) {
    return type == QuestionType.multipleChoice ||
        type == QuestionType.multipleSelect ||
        type == QuestionType.trueFalse;
  }

  String _getQuestionTypeName(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.multipleSelect:
        return 'Multiple Select';
      case QuestionType.trueFalse:
        return 'True/False';
      case QuestionType.shortAnswer:
        return 'Short Answer';
      case QuestionType.coding:
        return 'Coding';
    }
  }
}
