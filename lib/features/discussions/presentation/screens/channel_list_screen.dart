import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../data/repositories/discussion_repository.dart';
import '../bloc/discussion_bloc.dart';
import '../bloc/discussion_event.dart';
import '../bloc/discussion_state.dart';

/// Screen showing list of discussion channels for a course
class ChannelListScreen extends StatelessWidget {
  final String courseId;

  const ChannelListScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DiscussionBloc(
        discussionRepository: context.read<DiscussionRepository>(),
      )..add(LoadChannels(courseId: courseId)),
      child: ChannelListView(courseId: courseId),
    );
  }
}

class ChannelListView extends StatelessWidget {
  final String courseId;

  const ChannelListView({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussions'),
        backgroundColor: AppColors.background,
      ),
      backgroundColor: AppColors.background,
      body: BlocBuilder<DiscussionBloc, DiscussionState>(
        builder: (context, state) {
          if (state is ChannelsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<DiscussionBloc>().add(
                        LoadChannels(courseId: courseId),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is ChannelsLoaded) {
            final channels = state.channels;
            if (channels.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      color: AppColors.textSecondary,
                      size: 64,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No discussion channels yet',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Separate announcements and regular channels
            final announcements = channels
                .where((c) => c.isAnnouncement)
                .toList();
            final regularChannels = channels
                .where((c) => !c.isAnnouncement)
                .toList();

            return RefreshIndicator(
              onRefresh: () async {
                context.read<DiscussionBloc>().add(
                  LoadChannels(courseId: courseId),
                );
              },
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (announcements.isNotEmpty) ...[
                    _buildSectionHeader('Announcements'),
                    ...announcements.map((c) => _buildChannelCard(context, c)),
                    const SizedBox(height: 24),
                  ],
                  if (regularChannels.isNotEmpty) ...[
                    _buildSectionHeader('Channels'),
                    ...regularChannels.map(
                      (c) => _buildChannelCard(context, c),
                    ),
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

  Widget _buildChannelCard(BuildContext context, ChannelModel channel) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: channel.isAnnouncement
                ? AppColors.warning.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getChannelIcon(channel.icon ?? 'forum'),
            color: channel.isAnnouncement
                ? AppColors.warning
                : AppColors.primary,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              channel.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (channel.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEFAULT',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          channel.description ?? '',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (channel.threadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${channel.threadCount}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
        onTap: () {
          context.push('/courses/$courseId/discussions/${channel.id}');
        },
      ),
    );
  }

  IconData _getChannelIcon(String icon) {
    switch (icon) {
      case 'campaign':
        return Icons.campaign;
      case 'help':
        return Icons.help_outline;
      case 'code':
        return Icons.code;
      case 'lightbulb':
        return Icons.lightbulb_outline;
      default:
        return Icons.forum;
    }
  }
}
