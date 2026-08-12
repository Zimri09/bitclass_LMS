import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/quiz_repository.dart';

class QuizDeleteButton extends StatefulWidget {
  final QuizModel quiz;
  final VoidCallback onDeleted;

  const QuizDeleteButton({
    super.key,
    required this.quiz,
    required this.onDeleted,
  });

  @override
  State<QuizDeleteButton> createState() => _QuizDeleteButtonState();
}

class _QuizDeleteButtonState extends State<QuizDeleteButton> {
  bool _isDeleting = false;

  Future<void> _confirmDelete() async {
    if (_isDeleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.delete_forever_outlined, color: AppColors.error),
        title: const Text('Delete quiz?'),
        content: Text(
          'Permanently delete "${widget.quiz.title}"? All questions, student '
          'answers, and attempts for this quiz will also be deleted. This '
          'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            key: ValueKey('confirm-delete-quiz-${widget.quiz.id}'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Quiz'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await context.read<QuizRepository>().deleteQuiz(widget.quiz.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz deleted successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onDeleted();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFriendlyErrorMessage('Failed to delete quiz: $error'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: ValueKey('delete-quiz-${widget.quiz.id}'),
      tooltip: 'Delete quiz',
      onPressed: _isDeleting ? null : _confirmDelete,
      color: AppColors.error,
      icon: _isDeleting
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.delete_outline),
    );
  }
}
