import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../models/models.dart';

/// Repository for discussion operations.
class DiscussionRepository {
  static const String _channelsTable = 'discussion_channels';
  static const String _threadsTable = 'threads';
  static const String _repliesTable = 'replies';
  static const String _threadLikesTable = 'thread_likes';

  final SupabaseClient? _supabase;

  // Demo data storage
  final Map<String, ChannelModel> _channels = {};
  final Map<String, List<ThreadModel>> _threadsByChannel = {};
  final Map<String, List<ReplyModel>> _repliesByThread = {};

  DiscussionRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client) {
    if (EnvironmentConfig.isDemoMode) {
      _initDemoData();
    }
  }

  Map<String, dynamic> _rowToChannelMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'courseId': row['course_id'],
      'name': row['title'],
      'description': row['description'],
      'icon': row['icon'],
      'isAnnouncement': row['is_announcement'],
      'isDefault': row['is_default'],
      'threadCount': row['thread_count'],
      'lastActivityAt': row['last_activity_at']?.toString(),
      'createdAt': row['created_at']?.toString(),
      'createdBy': row['created_by'],
    };
  }

  Map<String, dynamic> _rowToThreadMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'channelId': row['channel_id'],
      'courseId': row['course_id'],
      'title': row['title'],
      'content': row['content'],
      'authorId': row['author_id'],
      'authorName': row['author_name'],
      'authorAvatarUrl': row['author_avatar_url'],
      'isPinned': row['is_pinned'],
      'isLocked': row['is_locked'],
      'isResolved': row['is_resolved'],
      'replyCount': row['reply_count'],
      'likeCount': row['like_count'],
      'likedBy': row['liked_by'] ?? const [],
      'createdAt': row['created_at']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
      'lastReplyAt': row['last_reply_at']?.toString(),
    };
  }

  Map<String, dynamic> _rowToReplyMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'threadId': row['thread_id'],
      'channelId': row['channel_id'],
      'courseId': row['course_id'],
      'parentReplyId': row['parent_reply_id'],
      'content': row['content'],
      'authorId': row['author_id'],
      'authorName': row['author_name'],
      'authorAvatarUrl': row['author_avatar_url'],
      'isInstructorAnswer': row['is_instructor_answer'],
      'isAcceptedAnswer': row['is_accepted_answer'],
      'likeCount': row['like_count'],
      'likedBy': row['liked_by'] ?? const [],
      'createdAt': row['created_at']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
    };
  }

  ChannelModel _channelFromRow(Map<String, dynamic> row) =>
      ChannelModel.fromMap(_rowToChannelMap(row));
  ThreadModel _threadFromRow(Map<String, dynamic> row) =>
      ThreadModel.fromMap(_rowToThreadMap(row));
  ReplyModel _replyFromRow(Map<String, dynamic> row) =>
      ReplyModel.fromMap(_rowToReplyMap(row));

  void _initDemoData() {
    _channels['channel-general'] = ChannelModel(
      id: 'channel-general',
      courseId: 'course-1',
      name: 'General',
      description: 'General discussion about the course',
      icon: '💬',
      isDefault: true,
      threadCount: 3,
      lastActivityAt: DateTime.now().subtract(const Duration(hours: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      createdBy: 'instructor-1',
    );

    _threadsByChannel['channel-general'] = [
      ThreadModel(
        id: 'thread-1',
        channelId: 'channel-general',
        courseId: 'course-1',
        title: 'Welcome to the Flutter Development Course!',
        content: 'Hello world',
        authorId: 'instructor-1',
        authorName: 'Dr. Sarah Chen',
        isPinned: true,
        replyCount: 12,
        likeCount: 24,
        likedBy: ['demo_user', 'student-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 28)),
        lastReplyAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ];

    _repliesByThread['thread-1'] = [
      ReplyModel(
        id: 'reply-1-1',
        threadId: 'thread-1',
        channelId: 'channel-general',
        courseId: 'course-1',
        content: 'Hi everyone!',
        authorId: 'student-1',
        authorName: 'Alex Johnson',
        likeCount: 5,
        likedBy: ['instructor-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 27)),
      ),
    ];
  }

  Future<List<ChannelModel>> getChannelsForCourse(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _channels.values.where((c) => c.courseId == courseId).toList()
        ..sort((a, b) {
          if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
          if (a.isAnnouncement != b.isAnnouncement)
            return a.isAnnouncement ? -1 : 1;
          return a.name.compareTo(b.name);
        });
    }

    try {
      final rows = await _supabase!
          .from(_channelsTable)
          .select()
          .eq('course_id', courseId)
          .order('is_default', ascending: false)
          .order('is_announcement', ascending: false)
          .order('title', ascending: true);
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_channelFromRow)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching channels: $e', name: 'DiscussionRepository');
      }
      return [];
    }
  }

  Future<ChannelModel?> getChannel(String channelId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _channels[channelId];
    }

    try {
      final row = await _supabase!
          .from(_channelsTable)
          .select()
          .eq('id', channelId)
          .maybeSingle();
      if (row == null) return null;
      return _channelFromRow(row);
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching channel: $e', name: 'DiscussionRepository');
      }
      return null;
    }
  }

  Future<ChannelModel> createChannel(ChannelModel channel) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _channels[channel.id] = channel;
      return channel;
    }

    await _supabase!.from(_channelsTable).upsert({
      'id': channel.id,
      'course_id': channel.courseId,
      'title': channel.name,
      'description': channel.description,
      'icon': channel.icon,
      'is_announcement': channel.isAnnouncement,
      'is_default': channel.isDefault,
      'thread_count': channel.threadCount,
      'last_activity_at': channel.lastActivityAt?.toIso8601String(),
      'created_at': channel.createdAt.toIso8601String(),
      'created_by': channel.createdBy,
    });

    return channel;
  }

  Future<List<ThreadModel>> getThreadsForChannel(String channelId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final threads = _threadsByChannel[channelId] ?? [];
      return threads.toList()..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final aTime = a.lastReplyAt ?? a.createdAt;
        final bTime = b.lastReplyAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
    }

    try {
      final rows = await _supabase!
          .from(_threadsTable)
          .select()
          .eq('channel_id', channelId)
          .order('is_pinned', ascending: false)
          .order('last_reply_at', ascending: false);
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_threadFromRow)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching threads: $e', name: 'DiscussionRepository');
      }
      return [];
    }
  }

  Future<ThreadModel?> getThread(String threadId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      for (final threads in _threadsByChannel.values) {
        for (final thread in threads) {
          if (thread.id == threadId) return thread;
        }
      }
      return null;
    }

    try {
      final row = await _supabase!
          .from(_threadsTable)
          .select()
          .eq('id', threadId)
          .maybeSingle();
      if (row == null) return null;
      return _threadFromRow(row);
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching thread: $e', name: 'DiscussionRepository');
      }
      return null;
    }
  }

  Future<ThreadModel> createThread(ThreadModel thread) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 400));
      final threads = _threadsByChannel[thread.channelId] ?? [];
      threads.add(thread);
      _threadsByChannel[thread.channelId] = threads;
      final channel = _channels[thread.channelId];
      if (channel != null) {
        _channels[thread.channelId] = channel.copyWith(
          threadCount: channel.threadCount + 1,
          lastActivityAt: DateTime.now(),
        );
      }
      return thread;
    }

    await _supabase!.from(_threadsTable).upsert({
      'id': thread.id,
      'channel_id': thread.channelId,
      'course_id': thread.courseId,
      'title': thread.title,
      'content': thread.content,
      'author_id': thread.authorId,
      'author_name': thread.authorName,
      'author_avatar_url': thread.authorAvatarUrl,
      'is_pinned': thread.isPinned,
      'is_locked': thread.isLocked,
      'is_resolved': thread.isResolved,
      'reply_count': thread.replyCount,
      'like_count': thread.likeCount,
      'liked_by': thread.likedBy,
      'created_at': thread.createdAt.toIso8601String(),
      'updated_at': thread.updatedAt?.toIso8601String(),
      'last_reply_at': thread.lastReplyAt?.toIso8601String(),
    });

    await _supabase!
        .from(_channelsTable)
        .update({
          'thread_count': await getChannel(
            thread.channelId,
          ).then((channel) => (channel?.threadCount ?? 0) + 1),
          'last_activity_at': DateTime.now().toIso8601String(),
        })
        .eq('id', thread.channelId);

    return thread;
  }

  Future<ThreadModel> toggleThreadLike(String threadId, String userId) async {
    final thread = await getThread(threadId);
    if (thread == null) throw Exception('Thread not found');

    final likedBy = List<String>.from(thread.likedBy);
    if (likedBy.contains(userId)) {
      likedBy.remove(userId);
    } else {
      likedBy.add(userId);
    }

    final updated = thread.copyWith(
      likedBy: likedBy,
      likeCount: likedBy.length,
    );

    if (EnvironmentConfig.isDemoMode) {
      for (final channelId in _threadsByChannel.keys) {
        final threads = _threadsByChannel[channelId]!;
        final index = threads.indexWhere((t) => t.id == threadId);
        if (index >= 0) {
          threads[index] = updated;
          return updated;
        }
      }
      throw Exception('Thread not found');
    }

    await _supabase!
        .from(_threadsTable)
        .update({'liked_by': likedBy, 'like_count': likedBy.length})
        .eq('id', threadId);

    await _supabase!.from(_threadLikesTable).upsert({
      'thread_id': threadId,
      'user_id': userId,
    });

    return updated;
  }

  Future<ThreadModel> toggleThreadResolved(String threadId) async {
    final thread = await getThread(threadId);
    if (thread == null) throw Exception('Thread not found');
    final updated = thread.copyWith(isResolved: !thread.isResolved);

    if (EnvironmentConfig.isDemoMode) {
      for (final channelId in _threadsByChannel.keys) {
        final threads = _threadsByChannel[channelId]!;
        final index = threads.indexWhere((t) => t.id == threadId);
        if (index >= 0) {
          threads[index] = updated;
          return updated;
        }
      }
      throw Exception('Thread not found');
    }

    await _supabase!
        .from(_threadsTable)
        .update({'is_resolved': updated.isResolved})
        .eq('id', threadId);
    return updated;
  }

  Future<List<ReplyModel>> getRepliesForThread(String threadId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final replies = _repliesByThread[threadId] ?? [];
      return replies.toList()..sort((a, b) {
        if (a.isAcceptedAnswer != b.isAcceptedAnswer)
          return a.isAcceptedAnswer ? -1 : 1;
        if (a.isInstructorAnswer != b.isInstructorAnswer)
          return a.isInstructorAnswer ? -1 : 1;
        return a.createdAt.compareTo(b.createdAt);
      });
    }

    try {
      final rows = await _supabase!
          .from(_repliesTable)
          .select()
          .eq('thread_id', threadId)
          .order('created_at', ascending: true);
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_replyFromRow)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching replies: $e', name: 'DiscussionRepository');
      }
      return [];
    }
  }

  Future<ReplyModel> createReply(ReplyModel reply) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 400));
      final replies = _repliesByThread[reply.threadId] ?? [];
      replies.add(reply);
      _repliesByThread[reply.threadId] = replies;
      for (final channelId in _threadsByChannel.keys) {
        final threads = _threadsByChannel[channelId]!;
        final index = threads.indexWhere((t) => t.id == reply.threadId);
        if (index >= 0) {
          final thread = threads[index];
          threads[index] = thread.copyWith(
            replyCount: thread.replyCount + 1,
            lastReplyAt: DateTime.now(),
          );
          final channel = _channels[channelId];
          if (channel != null) {
            _channels[channelId] = channel.copyWith(
              lastActivityAt: DateTime.now(),
            );
          }
          break;
        }
      }
      return reply;
    }

    await _supabase!.from(_repliesTable).upsert({
      'id': reply.id,
      'thread_id': reply.threadId,
      'channel_id': reply.channelId,
      'course_id': reply.courseId,
      'parent_reply_id': reply.parentReplyId,
      'content': reply.content,
      'author_id': reply.authorId,
      'author_name': reply.authorName,
      'author_avatar_url': reply.authorAvatarUrl,
      'is_instructor_answer': reply.isInstructorAnswer,
      'is_accepted_answer': reply.isAcceptedAnswer,
      'like_count': reply.likeCount,
      'liked_by': reply.likedBy,
      'created_at': reply.createdAt.toIso8601String(),
      'updated_at': reply.updatedAt?.toIso8601String(),
    });

    await _supabase!
        .from(_threadsTable)
        .update({
          'reply_count': await getThread(
            reply.threadId,
          ).then((thread) => (thread?.replyCount ?? 0) + 1),
          'last_reply_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reply.threadId);

    return reply;
  }

  Future<ReplyModel> toggleReplyLike(
    String replyId,
    String threadId,
    String userId,
  ) async {
    final replies = await getRepliesForThread(threadId);
    final reply = replies.firstWhere(
      (r) => r.id == replyId,
      orElse: () => throw Exception('Reply not found'),
    );
    final likedBy = List<String>.from(reply.likedBy);
    if (likedBy.contains(userId)) {
      likedBy.remove(userId);
    } else {
      likedBy.add(userId);
    }
    final updated = reply.copyWith(likedBy: likedBy, likeCount: likedBy.length);

    if (EnvironmentConfig.isDemoMode) {
      final demoReplies = _repliesByThread[threadId];
      if (demoReplies != null) {
        final index = demoReplies.indexWhere((r) => r.id == replyId);
        if (index >= 0) {
          demoReplies[index] = updated;
          return updated;
        }
      }
      throw Exception('Reply not found');
    }

    await _supabase!
        .from(_repliesTable)
        .update({'liked_by': likedBy, 'like_count': likedBy.length})
        .eq('id', replyId);

    return updated;
  }

  Future<ReplyModel> markAsAcceptedAnswer(
    String replyId,
    String threadId,
  ) async {
    final replies = await getRepliesForThread(threadId);
    final target = replies.firstWhere(
      (r) => r.id == replyId,
      orElse: () => throw Exception('Reply not found'),
    );
    final updatedReplies = replies.map((reply) {
      if (reply.isAcceptedAnswer && reply.id != replyId) {
        return reply.copyWith(isAcceptedAnswer: false);
      }
      return reply;
    }).toList();
    final updated = target.copyWith(isAcceptedAnswer: true);

    if (EnvironmentConfig.isDemoMode) {
      final demoReplies = _repliesByThread[threadId];
      if (demoReplies != null) {
        for (var i = 0; i < demoReplies.length; i++) {
          if (demoReplies[i].isAcceptedAnswer && demoReplies[i].id != replyId) {
            demoReplies[i] = demoReplies[i].copyWith(isAcceptedAnswer: false);
          }
        }
        final index = demoReplies.indexWhere((r) => r.id == replyId);
        if (index >= 0) {
          demoReplies[index] = updated;
        }
      }
      await toggleThreadResolved(threadId);
      return updated;
    }

    for (final reply in updatedReplies.where(
      (reply) => reply.isAcceptedAnswer && reply.id != replyId,
    )) {
      await _supabase!
          .from(_repliesTable)
          .update({'is_accepted_answer': false})
          .eq('id', reply.id);
    }

    await _supabase!
        .from(_repliesTable)
        .update({'is_accepted_answer': true})
        .eq('id', replyId);
    await toggleThreadResolved(threadId);
    return updated;
  }
}
