import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/question_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/quiz_repository.dart';

/// Screen for creating and editing quizzes
class QuizEditorScreen extends StatefulWidget {
  final String courseId;
  final String? quizId; // null = create new, otherwise edit

  const QuizEditorScreen({super.key, required this.courseId, this.quizId});

  @override
  State<QuizEditorScreen> createState() => _QuizEditorScreenState();
}

class _QuizEditorScreenState extends State<QuizEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  QuizModel? _quiz;
  List<QuestionModel> _questions = [];

  // Quiz settings
  int _timeLimitMinutes = 0;
  int _passingScore = 70;
  bool _shuffleQuestions = false;
  bool _shuffleAnswers = true;
  bool _showCorrectAnswers = true;
  bool _allowRetakes = true;
  int _maxAttempts = 0;
  bool _isPublished = false;

  @override
  void initState() {
    super.initState();
    if (widget.quizId != null) {
      _loadQuiz();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
          _showCorrectAnswers = quiz.showCorrectAnswers;
          _allowRetakes = quiz.allowRetakes;
          _maxAttempts = quiz.maxAttempts;
          _isPublished = quiz.isPublished;
        });
      }
    } catch (e) {
      _showError('Failed to load quiz: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final repo = context.read<QuizRepository>();
      final now = DateTime.now();
      final quizId = widget.quizId ?? const Uuid().v4();

      final quiz = QuizModel(
        id: quizId,
        courseId: widget.courseId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        timeLimitMinutes: _timeLimitMinutes,
        passingScore: _passingScore,
        totalPoints: _questions.fold(0, (sum, q) => sum + q.points),
        questionCount: _questions.length,
        shuffleQuestions: _shuffleQuestions,
        shuffleAnswers: _shuffleAnswers,
        showCorrectAnswers: _showCorrectAnswers,
        allowRetakes: _allowRetakes,
        maxAttempts: _maxAttempts,
        isPublished: _isPublished,
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
              widget.quizId == null
                  ? 'Quiz created successfully!'
                  : 'Quiz updated successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      _showError('Failed to save quiz: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.quizId == null ? 'Create Quiz' : 'Edit Quiz',
          style: AppTextStyles.h4,
        ),
        backgroundColor: AppColors.surface,
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton(
                onPressed: _isSaving ? null : _saveQuiz,
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

                    // Questions Section
                    _buildQuestionsSection(),
                  ],
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
                    _timeLimitMinutes = int.tryParse(value) ?? 0;
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
                    _passingScore = int.tryParse(value) ?? 70;
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
                    _maxAttempts = int.tryParse(value) ?? 0;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Toggle switches
          SwitchListTile(
            title: const Text('Shuffle Questions'),
            subtitle: const Text('Randomize question order for each attempt'),
            value: _shuffleQuestions,
            onChanged: (value) => setState(() => _shuffleQuestions = value),
            activeThumbColor: AppColors.primary,
          ),
          SwitchListTile(
            title: const Text('Shuffle Answers'),
            subtitle: const Text('Randomize answer options for each question'),
            value: _shuffleAnswers,
            onChanged: (value) => setState(() => _shuffleAnswers = value),
            activeThumbColor: AppColors.primary,
          ),
          SwitchListTile(
            title: const Text('Show Correct Answers'),
            subtitle: const Text('Display correct answers after submission'),
            value: _showCorrectAnswers,
            onChanged: (value) => setState(() => _showCorrectAnswers = value),
            activeThumbColor: AppColors.primary,
          ),
          SwitchListTile(
            title: const Text('Allow Retakes'),
            subtitle: const Text('Allow students to retake the quiz'),
            value: _allowRetakes,
            onChanged: (value) => setState(() => _allowRetakes = value),
            activeThumbColor: AppColors.primary,
          ),
          SwitchListTile(
            title: const Text('Published'),
            subtitle: const Text('Make quiz visible to students'),
            value: _isPublished,
            onChanged: (value) => setState(() => _isPublished = value),
            activeThumbColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Questions (${_questions.length})', style: AppTextStyles.h4),
            ElevatedButton.icon(
              onPressed: _addQuestion,
              icon: const Icon(Icons.add),
              label: const Text('Add Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
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
            itemCount: _questions.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
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
  late List<TextEditingController> _optionControllers;

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
    _optionControllers = widget.question.options
        .map((o) => TextEditingController(text: o.text))
        .toList();
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    _explanationController.dispose();
    _pointsController.dispose();
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

    widget.onUpdate(
      widget.question.copyWith(
        questionText: _questionTextController.text,
        explanation: _explanationController.text.isEmpty
            ? null
            : _explanationController.text,
        points: int.tryParse(_pointsController.text) ?? 1,
        options: options,
        correctAnswers: options
            .where((o) => o.isCorrect)
            .map((o) => o.id)
            .toList(),
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
    widget.onUpdate(widget.question.copyWith(type: type));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        key: PageStorageKey(widget.question.id),
        initiallyExpanded: widget.question.questionText.isEmpty,
        leading: ReorderableDragStartListener(
          index: widget.index,
          child: const Icon(Icons.drag_handle, color: AppColors.textSecondary),
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
          '${_getQuestionTypeName(widget.question.type)} • ${widget.question.points} pts',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: widget.onRemove,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question type and points
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<QuestionType>(
                        initialValue: widget.question.type,
                        decoration: const InputDecoration(
                          labelText: 'Question Type',
                        ),
                        items: QuestionType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getQuestionTypeName(type)),
                          );
                        }).toList(),
                        onChanged: _changeQuestionType,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _pointsController,
                        decoration: const InputDecoration(labelText: 'Points'),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateQuestion(),
                      ),
                    ),
                  ],
                ),
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
                  ..._buildOptionEditors(),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Option'),
                  ),
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
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOptionEditors() {
    // Ensure controllers match options
    while (_optionControllers.length < widget.question.options.length) {
      _optionControllers.add(TextEditingController());
    }

    return List.generate(widget.question.options.length, (index) {
      final option = widget.question.options[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            // Correct answer indicator
            if (widget.question.type == QuestionType.multipleChoice)
              Radio<bool>(
                value: true,
                groupValue: option.isCorrect,
                onChanged: (_) => _toggleCorrectAnswer(index),
                activeColor: AppColors.success,
              )
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
                  border: const OutlineInputBorder(),
                  suffixIcon: option.isCorrect
                      ? const Icon(Icons.check_circle, color: AppColors.success)
                      : null,
                ),
                onChanged: (_) => _updateQuestion(),
              ),
            ),
            // Remove option button
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => _removeOption(index),
              color: AppColors.textSecondary,
            ),
          ],
        ),
      );
    });
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
