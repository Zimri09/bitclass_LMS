import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../data/repositories/discussion_repository.dart';
import '../bloc/discussion_bloc.dart';
import '../bloc/discussion_event.dart';
import '../bloc/discussion_state.dart';

/// Screen showing thread details with replies
class ThreadDetailScreen extends StatefulWidget {
  final String courseId;
  final String channelId;
  final String threadId;

  const ThreadDetailScreen({
    super.key,
    required this.courseId,
    required this.channelId,
    required this.threadId,
  });

  @override
  State<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DiscussionBloc(
        discussionRepository: context.read<DiscussionRepository>(),
      )..add(LoadThreadDetail(threadId: widget.threadId)),
      child: BlocConsumer<DiscussionBloc, DiscussionState>(
        listener: (context, state) {
          if (state is ReplyCreated) {
            _replyController.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reply posted!'),
                backgroundColor: AppColors.success,
              ),
            );
          } else if (state is DiscussionError) {
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
              title: Text(
                state is ThreadDetailLoaded ? state.thread.title : 'Thread',
              ),
              backgroundColor: AppColors.background,
              actions: [
                if (state is ThreadDetailLoaded) ...[
                  IconButton(
                    icon: Icon(
                      state.thread.isResolved
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: state.thread.isResolved
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                    onPressed: () {
                      context.read<DiscussionBloc>().add(
                        ToggleThreadResolved(threadId: widget.threadId),
                      );
                    },
                    tooltip: state.thread.isResolved
                        ? 'Mark as unresolved'
                        : 'Mark as resolved',
                  ),
                ],
              ],
            ),
            backgroundColor: AppColors.background,
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, DiscussionState state) {
    if (state is ThreadDetailLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state is DiscussionError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              state.message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (state is ThreadDetailLoaded) {
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildThreadPost(context, state.thread),
                const SizedBox(height: 24),
                if (state.replies.isNotEmpty) ...[
                  _buildRepliesHeader(state.replies.length),
                  const SizedBox(height: 12),
                  ...state.replies.map(
                    (reply) => _buildReplyCard(context, reply, state.thread),
                  ),
                ],
              ],
            ),
          ),
          if (!state.thread.isLocked)
            _buildReplyInput(context, state.isSubmittingReply),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildThreadPost(BuildContext context, ThreadModel thread) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badges
            if (thread.isResolved || thread.isPinned || thread.isLocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (thread.isPinned)
                      _buildBadge(
                        icon: Icons.push_pin,
                        text: 'Pinned',
                        color: AppColors.warning,
                      ),
                    if (thread.isResolved)
                      _buildBadge(
                        icon: Icons.check_circle,
                        text: 'Resolved',
                        color: AppColors.success,
                      ),
                    if (thread.isLocked)
                      _buildBadge(
                        icon: Icons.lock,
                        text: 'Locked',
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              ),

            // Author info
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Text(
                    thread.authorName[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.authorName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatFullDate(thread.createdAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              thread.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // Content
            Text(
              thread.content,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: AppColors.surfaceLight),
            const SizedBox(height: 8),

            // Actions
            Row(
              children: [
                _buildActionButton(
                  icon: thread.likedBy.contains('demo-user')
                      ? Icons.thumb_up
                      : Icons.thumb_up_outlined,
                  label: '${thread.likeCount}',
                  color: thread.likedBy.contains('demo-user')
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  onTap: () {
                    context.read<DiscussionBloc>().add(
                      ToggleThreadLike(
                        threadId: thread.id,
                        userId: 'demo-user',
                      ),
                    );
                  },
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: '${thread.replyCount} replies',
                  color: AppColors.textSecondary,
                  onTap: () {
                    _replyFocusNode.requestFocus();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildRepliesHeader(int count) {
    return Row(
      children: [
        Text(
          '$count ${count == 1 ? 'Reply' : 'Replies'}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildReplyCard(
    BuildContext context,
    ReplyModel reply,
    ThreadModel thread,
  ) {
    final isAccepted = reply.isAcceptedAnswer;
    final isInstructor = reply.isInstructorAnswer;

    return Card(
      color: isAccepted
          ? AppColors.success.withValues(alpha: 0.1)
          : AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isAccepted
            ? const BorderSide(color: AppColors.success, width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isInstructor
                      ? AppColors.warning.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.2),
                  child: Text(
                    reply.authorName[0].toUpperCase(),
                    style: TextStyle(
                      color: isInstructor
                          ? AppColors.warning
                          : AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            reply.authorName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (isInstructor) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'INSTRUCTOR',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _formatDate(reply.createdAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAccepted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, color: AppColors.success, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Accepted',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Content
            Text(
              reply.content,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                InkWell(
                  onTap: () {
                    context.read<DiscussionBloc>().add(
                      ToggleReplyLike(
                        replyId: reply.id,
                        threadId: thread.id,
                        userId: 'demo-user',
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          reply.likedBy.contains('demo-user')
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          color: reply.likedBy.contains('demo-user')
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${reply.likeCount}',
                          style: TextStyle(
                            color: reply.likedBy.contains('demo-user')
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (!isAccepted &&
                    !thread.isLocked &&
                    thread.authorId == 'demo-user')
                  TextButton.icon(
                    onPressed: () {
                      context.read<DiscussionBloc>().add(
                        MarkAsAcceptedAnswer(
                          replyId: reply.id,
                          threadId: thread.id,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Accept'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.success,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyInput(BuildContext context, bool isSubmitting) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceLight)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                focusNode: _replyFocusNode,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Write a reply...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                icon: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.background,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: AppColors.background),
                onPressed: isSubmitting
                    ? null
                    : () {
                        if (_replyController.text.trim().isEmpty) return;
                        context.read<DiscussionBloc>().add(
                          CreateReply(
                            threadId: widget.threadId,
                            channelId: widget.channelId,
                            courseId: widget.courseId,
                            content: _replyController.text.trim(),
                            authorId: 'demo-user',
                            authorName: 'Demo User',
                          ),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
