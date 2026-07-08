import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/discussion_repository.dart';
import '../bloc/discussion_bloc.dart';
import '../bloc/discussion_event.dart';
import '../bloc/discussion_state.dart';

/// Screen for creating a new thread
class CreateThreadScreen extends StatefulWidget {
  final String courseId;
  final String channelId;

  const CreateThreadScreen({
    super.key,
    required this.courseId,
    required this.channelId,
  });

  @override
  State<CreateThreadScreen> createState() => _CreateThreadScreenState();
}

class _CreateThreadScreenState extends State<CreateThreadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DiscussionBloc(
        discussionRepository: context.read<DiscussionRepository>(),
      ),
      child: BlocConsumer<DiscussionBloc, DiscussionState>(
        listener: (context, state) {
          if (state is ThreadCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Thread created successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop();
          } else if (state is DiscussionError) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('New Discussion'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () => _submit(context),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Post',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Title field
                  Text(
                    'Title',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'What\'s your question or topic?',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 1,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      if (value.trim().length < 5) {
                        return 'Title must be at least 5 characters';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),

                  const SizedBox(height: 24),

                  // Content field
                  Text(
                    'Details',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _contentController,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Provide details about your question or topic...\n\nTip: Be specific and include any relevant code or error messages.',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 10,
                    minLines: 5,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please provide some details';
                      }
                      if (value.trim().length < 20) {
                        return 'Please provide more details (at least 20 characters)';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Tips card
                  Card(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Tips for a great discussion',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTipItem('Use a clear, specific title'),
                          _buildTipItem('Explain what you\'ve already tried'),
                          _buildTipItem('Include relevant code snippets'),
                          _buildTipItem('Check if a similar question exists'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    context.read<DiscussionBloc>().add(
      CreateThread(
        channelId: widget.channelId,
        courseId: widget.courseId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        authorId: 'demo-user',
        authorName: 'Demo User',
      ),
    );
  }
}
