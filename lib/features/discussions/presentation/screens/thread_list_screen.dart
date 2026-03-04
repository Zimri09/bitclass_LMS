import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/discussion_repository.dart';
import '../bloc/discussion_bloc.dart';
import '../bloc/discussion_event.dart';
import '../bloc/discussion_state.dart';

/// Screen showing list of threads in a channel
class ThreadListScreen extends StatelessWidget {
  final String courseId;
  final String channelId;

  const ThreadListScreen({
    super.key,
    required this.courseId,
    required this.channelId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DiscussionBloc(
        discussionRepository: context.read<DiscussionRepository>(),
      )..add(LoadThreads(channelId: channelId)),
      child: ThreadListView(courseId: courseId, channelId: channelId),
    );
  }
}

class ThreadListView extends StatelessWidget {
  final String courseId;
  final String channelId;

  const ThreadListView({
    super.key,
    required this.courseId,
    required this.channelId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<DiscussionBloc, DiscussionState>(
          builder: (context, state) {
            if (state is ThreadsLoaded) {
              return Text(state.channel.name);
            }
            return const Text('Threads');
          },
        ),
        backgroundColor: AppColors.background,
      ),
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/courses/$courseId/discussions/$channelId/new');
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.background),
      ),
      body: BlocBuilder<DiscussionBloc, DiscussionState>(
        builder: (context, state) {
          if (state is ThreadsLoading) {
            return const ThreadListSkeleton();
          }

          if (state is DiscussionError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (state is ThreadsLoaded) {
            final threads = state.threads;

            if (threads.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.textSecondary,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No discussions yet',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start the conversation!',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Separate pinned and regular threads
            final pinnedThreads = threads.where((t) => t.isPinned).toList();
            final regularThreads = threads.where((t) => !t.isPinned).toList();

            return RefreshIndicator(
              onRefresh: () async {
                context.read<DiscussionBloc>().add(
                  LoadThreads(channelId: channelId),
                );
              },
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (pinnedThreads.isNotEmpty) ...[
                    _buildSectionHeader('Pinned'),
                    ...pinnedThreads.map((t) => _buildThreadCard(context, t)),
                    const SizedBox(height: 16),
                  ],
                  if (regularThreads.isNotEmpty) ...[
                    if (pinnedThreads.isNotEmpty)
                      _buildSectionHeader('Discussions'),
                    ...regularThreads.map((t) => _buildThreadCard(context, t)),
                  ],
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildThreadCard(BuildContext context, ThreadModel thread) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push(
            '/courses/$courseId/discussions/$channelId/threads/${thread.id}',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with badges
              Row(
                children: [
                  if (thread.isPinned) ...[
                    const Icon(
                      Icons.push_pin,
                      color: AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      thread.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (thread.isResolved || thread.isLocked) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (thread.isResolved) ...[
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
                            Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Resolved',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (thread.isLocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock,
                              color: AppColors.textSecondary,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Locked',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 8),

              // Content preview
              Text(
                thread.content,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Footer with author and stats
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      thread.authorName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${thread.authorName} • ${_formatDate(thread.createdAt)}',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Stats
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.thumb_up_outlined,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${thread.likeCount}',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.chat_bubble_outline,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${thread.replyCount}',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
}
