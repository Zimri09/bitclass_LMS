import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../data/repositories/discussion_repository.dart';
import '../bloc/discussion_bloc.dart';
import '../bloc/discussion_event.dart';
import '../bloc/discussion_state.dart';

/// Screen showing list of discussion channels for a course
class ChannelListScreen extends StatelessWidget {
  final String courseId;
  final bool embedded;

  const ChannelListScreen({
    super.key,
    required this.courseId,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DiscussionBloc(
        discussionRepository: context.read<DiscussionRepository>(),
      )..add(LoadChannels(courseId: courseId)),
      child: ChannelListView(courseId: courseId, embedded: embedded),
    );
  }
}

class ChannelListView extends StatefulWidget {
  final String courseId;
  final bool embedded;

  const ChannelListView({
    super.key,
    required this.courseId,
    this.embedded = false,
  });

  @override
  State<ChannelListView> createState() => _ChannelListViewState();
}

class _ChannelListViewState extends State<ChannelListView> {
  late final DiscussionRepository _discussionRepository;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _discussionRepository = context.read<DiscussionRepository>();
    _realtimeChannel = _discussionRepository.subscribeToCourseChannels(
      courseId: widget.courseId,
      onChanged: _reloadChannels,
    );
  }

  @override
  void dispose() {
    _discussionRepository.removeRealtimeChannel(_realtimeChannel);
    super.dispose();
  }

  void _reloadChannels() {
    if (mounted) {
      context.read<DiscussionBloc>().add(
        LoadChannels(courseId: widget.courseId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final discussionsBody = BlocBuilder<DiscussionBloc, DiscussionState>(
      builder: (context, state) {
        if (state is ChannelsLoading) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
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
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<DiscussionBloc>().add(
                      LoadChannels(courseId: widget.courseId),
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
            return Center(
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
                LoadChannels(courseId: widget.courseId),
              );
            },
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (announcements.isNotEmpty) ...[
                  _buildSectionHeader('Announcements'),
                  _buildWebChannelGrid(context, announcements),
                  const SizedBox(height: 24),
                ],
                if (regularChannels.isNotEmpty) ...[
                  _buildSectionHeader('Channels'),
                  _buildWebChannelGrid(context, regularChannels),
                ],
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );

    if (widget.embedded) return discussionsBody;

    return Scaffold(
      appBar: AppBar(title: const Text('Discussions')),
      body: discussionsBody,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildChannelCard(BuildContext context, ChannelModel channel) {
    if (kIsWeb) return _buildWebChannelCard(context, channel);

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
            Expanded(
              child: Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
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
                child: Text(
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
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
        onTap: () {
          context.push('/courses/${widget.courseId}/discussions/${channel.id}');
        },
      ),
    );
  }

  Widget _buildWebChannelGrid(
    BuildContext context,
    List<ChannelModel> channels,
  ) {
    if (!kIsWeb) {
      return Column(
        children: channels
            .map((channel) => _buildChannelCard(context, channel))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        const gap = 12.0;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: channels
              .map(
                (channel) => SizedBox(
                  width: tileWidth,
                  child: AspectRatio(
                    aspectRatio: 1.45,
                    child: _buildChannelCard(context, channel),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildWebChannelCard(BuildContext context, ChannelModel channel) {
    final color = channel.isAnnouncement
        ? AppColors.warning
        : AppColors.primary;

    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          context.push('/courses/${widget.courseId}/discussions/${channel.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getChannelIcon(channel.icon ?? 'forum'),
                      color: color,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  if (channel.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DEFAULT',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                channel.description ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.forum_outlined, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    '${channel.threadCount} conversations',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward, size: 16, color: color),
                ],
              ),
            ],
          ),
        ),
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
