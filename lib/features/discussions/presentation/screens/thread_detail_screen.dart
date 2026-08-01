import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/models.dart';
import '../../data/repositories/discussion_repository.dart';
import '../bloc/discussion_bloc.dart';
import '../bloc/discussion_event.dart';
import '../bloc/discussion_state.dart';
import '../widgets/reaction_control.dart';
import '../widgets/relative_timestamp.dart';

/// Screen showing thread details with replies
class ThreadDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DiscussionBloc(
        discussionRepository: context.read<DiscussionRepository>(),
      )..add(LoadThreadDetail(threadId: threadId)),
      child: _ThreadDetailPage(
        courseId: courseId,
        channelId: channelId,
        threadId: threadId,
      ),
    );
  }
}

class _ThreadDetailPage extends StatefulWidget {
  final String courseId;
  final String channelId;
  final String threadId;

  const _ThreadDetailPage({
    required this.courseId,
    required this.channelId,
    required this.threadId,
  });

  @override
  State<_ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends State<_ThreadDetailPage> {
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _editReplyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  final Set<String> _hiddenReplyIds = {};
  String? _editingReplyId;
  String? _handledCreatedReplyId;
  late final DiscussionRepository _discussionRepository;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _discussionRepository = context.read<DiscussionRepository>();
    _realtimeChannel = _discussionRepository.subscribeToThreadDetail(
      threadId: widget.threadId,
      onThreadChanged: _handleThreadRealtimeChange,
      onReplyChanged: _handleReplyRealtimeChange,
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    _editReplyController.dispose();
    _replyFocusNode.dispose();
    _discussionRepository.removeRealtimeChannel(_realtimeChannel);
    super.dispose();
  }

  void _reloadThread() {
    if (mounted) {
      context.read<DiscussionBloc>().add(
        RefreshThreadDetail(threadId: widget.threadId),
      );
    }
  }

  void _handleThreadRealtimeChange(PostgresChangePayload payload) {
    if (!mounted) return;
    if (payload.eventType == PostgresChangeEvent.update &&
        payload.newRecord.isNotEmpty) {
      context.read<DiscussionBloc>().add(
        ApplyThreadRealtimeUpdate(record: payload.newRecord),
      );
      return;
    }
    _reloadThread();
  }

  void _handleReplyRealtimeChange(PostgresChangePayload payload) {
    if (!mounted) return;
    if (payload.eventType == PostgresChangeEvent.update &&
        payload.newRecord.isNotEmpty) {
      context.read<DiscussionBloc>().add(
        ApplyReplyRealtimeUpdate(record: payload.newRecord),
      );
      return;
    }
    _reloadThread();
  }

  void _startEditingReply(ReplyModel reply) {
    setState(() {
      _editingReplyId = reply.id;
      _editReplyController.text = reply.content;
      _editReplyController.selection = TextSelection.collapsed(
        offset: _editReplyController.text.length,
      );
    });
  }

  void _cancelEditingReply() {
    setState(() {
      _editingReplyId = null;
      _editReplyController.clear();
    });
  }

  void _saveEditedReply(ReplyModel reply, String userId) {
    final content = _editReplyController.text.trim();
    if (reply.authorId != userId || content.isEmpty) return;

    context.read<DiscussionBloc>().add(
      EditReply(
        replyId: reply.id,
        threadId: reply.threadId,
        authorId: userId,
        content: content,
      ),
    );
    _cancelEditingReply();
  }

  /// Get the current authenticated user, or null
  UserModel? _currentUser(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user;
    return null;
  }

  Future<void> _deleteThread(ThreadModel thread, String userId) async {
    if (thread.authorId != userId) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete thread?'),
            content: const Text(
              'This will permanently delete the thread and all of its replies.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      await _discussionRepository.deleteThread(thread.id, userId);
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Thread deleted.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyErrorMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteReply(ReplyModel reply, String userId) async {
    if (reply.authorId != userId) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Unsend reply?'),
            content: const Text(
              'This reply will be permanently removed from the discussion.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Unsend'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _hiddenReplyIds.add(reply.id));
    try {
      await _discussionRepository.deleteReply(reply.id, reply.threadId, userId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reply unsent.'),
          backgroundColor: AppColors.success,
        ),
      );
      _reloadThread();
    } catch (error) {
      if (!mounted) return;
      setState(() => _hiddenReplyIds.remove(reply.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyErrorMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DiscussionBloc, DiscussionState>(
      listener: (context, state) {
        if (state is ThreadDetailLoaded &&
            state.createdReplyId != null &&
            state.createdReplyId != _handledCreatedReplyId) {
          _handledCreatedReplyId = state.createdReplyId;
          _replyController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reply posted!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is ThreadDetailLoaded && state.actionError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionError!),
              backgroundColor: AppColors.error,
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
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, DiscussionState state) {
    if (state is ThreadDetailLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (state is DiscussionError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              state.message,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (state is ThreadDetailLoaded) {
      final user = _currentUser(context);
      final visibleReplies = state.replies
          .where((reply) => !_hiddenReplyIds.contains(reply.id))
          .toList();
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildThreadPost(
                  context,
                  state.thread,
                  user,
                  visibleReplies.length,
                ),
                const SizedBox(height: 24),
                if (visibleReplies.isNotEmpty) ...[
                  _buildRepliesHeader(visibleReplies.length),
                  const SizedBox(height: 12),
                  ...visibleReplies.map(
                    (reply) =>
                        _buildReplyCard(context, reply, state.thread, user),
                  ),
                ],
              ],
            ),
          ),
          if (!state.thread.isLocked)
            _buildReplyInput(context, state.isSubmittingReply, user),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildThreadPost(
    BuildContext context,
    ThreadModel thread,
    UserModel? user,
    int visibleReplyCount,
  ) {
    final userId = user?.id ?? '';

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
                UserAvatar(radius: 20, imageUrl: thread.authorAvatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.authorName,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatFullDate(thread.createdAt),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (thread.authorId == userId)
                  PopupMenuButton<String>(
                    tooltip: 'Thread options',
                    icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteThread(thread, userId);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: AppColors.error),
                            SizedBox(width: 12),
                            Text('Delete thread'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              thread.title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // Content
            Text(
              thread.content,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),
            Divider(color: AppColors.surfaceLight),
            const SizedBox(height: 8),

            // Actions
            Row(
              children: [
                ReactionControl(
                  reactionCounts: thread.effectiveReactionCounts,
                  totalCount: thread.totalReactionCount,
                  selectedReaction: thread.reactionForUser(userId),
                  onReactionSelected: userId.isEmpty
                      ? null
                      : (reaction) {
                          context.read<DiscussionBloc>().add(
                            SetThreadReaction(
                              threadId: thread.id,
                              userId: userId,
                              reaction: reaction,
                            ),
                          );
                        },
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label:
                      '$visibleReplyCount ${visibleReplyCount == 1 ? 'reply' : 'replies'}',
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
          style: TextStyle(
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
    UserModel? user,
  ) {
    final userId = user?.id ?? '';
    final isInstructor = reply.isInstructorAnswer;
    final isEditing = _editingReplyId == reply.id;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                UserAvatar(
                  radius: 16,
                  imageUrl: reply.authorAvatarUrl,
                  fallbackColor: isInstructor
                      ? AppColors.warning.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.2),
                  fallbackIconColor: isInstructor
                      ? AppColors.warning
                      : AppColors.primary,
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
                            style: TextStyle(
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
                              child: Text(
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
                      RelativeTimestamp(
                        timestamp: reply.createdAt,
                        suffix: reply.editedAt == null ? null : 'Edited',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reply.authorId == userId)
                  PopupMenuButton<String>(
                    tooltip: 'Reply options',
                    icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _startEditingReply(reply);
                      } else if (value == 'delete') {
                        _deleteReply(reply, userId);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 12),
                            Text('Edit Reply'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.undo, color: AppColors.error),
                            SizedBox(width: 12),
                            Text('Unsend reply'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Content
            if (isEditing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _editReplyController,
                    autofocus: true,
                    minLines: 2,
                    maxLines: null,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Edit your reply',
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _cancelEditingReply,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _saveEditedReply(reply, userId),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              )
            else
              Text(
                reply.content,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                ReactionControl(
                  reactionCounts: reply.effectiveReactionCounts,
                  totalCount: reply.totalReactionCount,
                  selectedReaction: reply.reactionForUser(userId),
                  onReactionSelected: userId.isEmpty
                      ? null
                      : (reaction) {
                          context.read<DiscussionBloc>().add(
                            SetReplyReaction(
                              replyId: reply.id,
                              threadId: thread.id,
                              userId: userId,
                              reaction: reaction,
                            ),
                          );
                        },
                  compact: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyInput(
    BuildContext context,
    bool isSubmitting,
    UserModel? user,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
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
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Write a reply...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
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
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.background,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.send, color: AppColors.background),
                onPressed: isSubmitting
                    ? null
                    : () {
                        if (_replyController.text.trim().isEmpty) return;

                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'You must be logged in to reply',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        context.read<DiscussionBloc>().add(
                          CreateReply(
                            threadId: widget.threadId,
                            channelId: widget.channelId,
                            courseId: widget.courseId,
                            content: _replyController.text.trim(),
                            authorId: user.id,
                            authorName: user.displayNameOrEmail,
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

  String _formatFullDate(DateTime date) {
    final localDate = date.toLocal();
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
    return '${months[localDate.month - 1]} ${localDate.day}, ${localDate.year} at ${localDate.hour}:${localDate.minute.toString().padLeft(2, '0')}';
  }
}
