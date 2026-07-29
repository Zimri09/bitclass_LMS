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
    // ── Course 1: Introduction to Flutter ──────────────────────────────
    _channels['channel-c1-general'] = ChannelModel(
      id: 'channel-c1-general',
      courseId: 'course-1',
      name: 'General',
      description: 'General discussion about the Flutter course',
      icon: '💬',
      isDefault: true,
      threadCount: 3,
      lastActivityAt: DateTime.now().subtract(const Duration(hours: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      createdBy: 'demo-instructor-1',
    );

    _channels['channel-c1-help'] = ChannelModel(
      id: 'channel-c1-help',
      courseId: 'course-1',
      name: 'Q&A / Help',
      description: 'Ask questions and get help from peers and instructors',
      icon: 'help',
      threadCount: 1,
      lastActivityAt: DateTime.now().subtract(const Duration(hours: 6)),
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      createdBy: 'demo-instructor-1',
    );

    _threadsByChannel['channel-c1-general'] = [
      ThreadModel(
        id: 'thread-1',
        channelId: 'channel-c1-general',
        courseId: 'course-1',
        title: 'Welcome to the Flutter Development Course!',
        content:
            'Welcome everyone! 🎉\n\nI\'m John Doe, your instructor for this course. '
            'Feel free to use this channel to introduce yourself, share your learning goals, '
            'and connect with fellow students.\n\n'
            'Don\'t hesitate to ask questions — there are no silly questions here!',
        authorId: 'demo-instructor-1',
        authorName: 'John Doe',
        isPinned: true,
        replyCount: 3,
        likeCount: 8,
        likedBy: ['student-1', 'student-2'],
        createdAt: DateTime.now().subtract(const Duration(days: 28)),
        lastReplyAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      ThreadModel(
        id: 'thread-2',
        channelId: 'channel-c1-general',
        courseId: 'course-1',
        title: 'Hot Reload vs Hot Restart — what\'s the difference?',
        content:
            'I keep seeing both options in VS Code when running my Flutter app. '
            'Can someone explain when to use Hot Reload versus Hot Restart? '
            'They seem to do the same thing sometimes but other times Hot Reload doesn\'t pick up my changes.',
        authorId: 'student-1',
        authorName: 'Alice Johnson',
        replyCount: 2,
        likeCount: 5,
        likedBy: ['student-2', 'demo-instructor-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        lastReplyAt: DateTime.now().subtract(const Duration(days: 9)),
      ),
      ThreadModel(
        id: 'thread-3',
        channelId: 'channel-c1-general',
        courseId: 'course-1',
        title: 'Study group for Lesson 4?',
        content:
            'Hey everyone! Would anyone be interested in doing a study group session for Lesson 4 (State Management)? '
            'I think it would be helpful to work through the exercises together. '
            'We could do it over Discord or Google Meet this weekend.',
        authorId: 'student-2',
        authorName: 'Bob Williams',
        replyCount: 1,
        likeCount: 3,
        likedBy: ['student-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        lastReplyAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    _threadsByChannel['channel-c1-help'] = [
      ThreadModel(
        id: 'thread-4',
        channelId: 'channel-c1-help',
        courseId: 'course-1',
        title: 'Getting error: "RenderFlex overflowed" — how to fix?',
        content:
            'I\'m working on the Lesson 3 exercise and I keep getting this yellow/black striped pattern '
            'at the bottom of my Column. The error says:\n\n'
            '`A RenderFlex overflowed by 42 pixels on the bottom.`\n\n'
            'I tried wrapping things in a Container but it didn\'t help. Any ideas?',
        authorId: 'student-3',
        authorName: 'Charlie Davis',
        isResolved: true,
        replyCount: 2,
        likeCount: 6,
        likedBy: ['student-1', 'student-2'],
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        lastReplyAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
    ];

    // Replies for thread-1
    _repliesByThread['thread-1'] = [
      ReplyModel(
        id: 'reply-1-1',
        threadId: 'thread-1',
        channelId: 'channel-c1-general',
        courseId: 'course-1',
        content:
            'Hi everyone! I\'m Alice, a CS student. Really excited to learn Flutter — '
            'I\'ve been wanting to build a mobile app for a while now!',
        authorId: 'student-1',
        authorName: 'Alice Johnson',
        likeCount: 3,
        likedBy: ['demo-instructor-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 27)),
      ),
      ReplyModel(
        id: 'reply-1-2',
        threadId: 'thread-1',
        channelId: 'channel-c1-general',
        courseId: 'course-1',
        content:
            'Hey! Bob here. I come from a web development background so this is all new to me. '
            'Looking forward to learning with everyone!',
        authorId: 'student-2',
        authorName: 'Bob Williams',
        likeCount: 2,
        createdAt: DateTime.now().subtract(const Duration(days: 26)),
      ),
      ReplyModel(
        id: 'reply-1-3',
        threadId: 'thread-1',
        channelId: 'channel-c1-general',
        courseId: 'course-1',
        content:
            'Great to see so many enthusiastic students! Remember, you can always reach out '
            'in the Q&A channel if you get stuck on any lesson. Happy coding! 🚀',
        authorId: 'demo-instructor-1',
        authorName: 'John Doe',
        isInstructorAnswer: true,
        likeCount: 4,
        likedBy: ['student-1', 'student-2'],
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
    ];

    // Replies for thread-2
    _repliesByThread['thread-2'] = [
      ReplyModel(
        id: 'reply-2-1',
        threadId: 'thread-2',
        channelId: 'channel-c1-general',
        courseId: 'course-1',
        content:
            'Great question! **Hot Reload** preserves the state of your app and only updates '
            'the widget tree. **Hot Restart** completely restarts the app, losing all state.\n\n'
            'Use Hot Reload for UI tweaks, and Hot Restart when you change things like '
            'initialization logic or static fields.',
        authorId: 'demo-instructor-1',
        authorName: 'John Doe',
        isInstructorAnswer: true,
        likeCount: 7,
        likedBy: ['student-1', 'student-2', 'student-3'],
        createdAt: DateTime.now().subtract(const Duration(days: 9, hours: 12)),
      ),
      ReplyModel(
        id: 'reply-2-2',
        threadId: 'thread-2',
        channelId: 'channel-c1-general',
        courseId: 'course-1',
        content:
            'Thanks for the explanation! That makes sense now. I was changing a const '
            'value and wondering why Hot Reload didn\'t update it.',
        authorId: 'student-1',
        authorName: 'Alice Johnson',
        likeCount: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 9)),
      ),
    ];

    // Replies for thread-3
    _repliesByThread['thread-3'] = [
      ReplyModel(
        id: 'reply-3-1',
        threadId: 'thread-3',
        channelId: 'channel-c1-general',
        courseId: 'course-1',
        content: 'I\'m in! Saturday afternoon works for me. Let\'s do it on Discord?',
        authorId: 'student-1',
        authorName: 'Alice Johnson',
        likeCount: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    // Replies for thread-4 (resolved Q&A)
    _repliesByThread['thread-4'] = [
      ReplyModel(
        id: 'reply-4-1',
        threadId: 'thread-4',
        channelId: 'channel-c1-help',
        courseId: 'course-1',
        content:
            'Wrap your Column in a `SingleChildScrollView` to make it scrollable, or use '
            '`Expanded` / `Flexible` widgets to constrain the children. The overflow happens '
            'when the content is taller than the available space.',
        authorId: 'demo-instructor-1',
        authorName: 'John Doe',
        isInstructorAnswer: true,
        isAcceptedAnswer: true,
        likeCount: 5,
        likedBy: ['student-3', 'student-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 6)),
      ),
      ReplyModel(
        id: 'reply-4-2',
        threadId: 'thread-4',
        channelId: 'channel-c1-help',
        courseId: 'course-1',
        content: 'The SingleChildScrollView worked perfectly! Thank you so much! 🙏',
        authorId: 'student-3',
        authorName: 'Charlie Davis',
        likeCount: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
    ];

    // ── Course 2: Advanced Dart Programming ────────────────────────────
    _channels['channel-c2-general'] = ChannelModel(
      id: 'channel-c2-general',
      courseId: 'course-2',
      name: 'General',
      description: 'General discussion about Dart programming',
      icon: '💬',
      isDefault: true,
      threadCount: 1,
      lastActivityAt: DateTime.now().subtract(const Duration(days: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      createdBy: 'demo-instructor-1',
    );

    _threadsByChannel['channel-c2-general'] = [
      ThreadModel(
        id: 'thread-5',
        channelId: 'channel-c2-general',
        courseId: 'course-2',
        title: 'Tips for understanding Dart generics?',
        content:
            'I\'m having a hard time wrapping my head around generics in Dart. '
            'The syntax like `List<T>` and `Map<K, V>` makes sense for collections, '
            'but writing my own generic classes feels confusing.\n\n'
            'Any tips or resources that helped you understand this concept?',
        authorId: 'student-1',
        authorName: 'Alice Johnson',
        replyCount: 1,
        likeCount: 4,
        likedBy: ['student-2'],
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        lastReplyAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    _repliesByThread['thread-5'] = [
      ReplyModel(
        id: 'reply-5-1',
        threadId: 'thread-5',
        channelId: 'channel-c2-general',
        courseId: 'course-2',
        content:
            'Think of generics as "placeholders for types". When you write `class Box<T>`, '
            'you\'re saying "Box can hold any type, and we\'ll decide which type when we create it."\n\n'
            'Start simple: create a `Pair<A, B>` class that holds two values of different types. '
            'That exercise really helped me!',
        authorId: 'demo-instructor-1',
        authorName: 'John Doe',
        isInstructorAnswer: true,
        likeCount: 3,
        likedBy: ['student-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    // ── Course 3: Data Structures & Algorithms ─────────────────────────
    _channels['channel-c3-general'] = ChannelModel(
      id: 'channel-c3-general',
      courseId: 'course-3',
      name: 'General',
      description: 'Discussion about data structures and algorithms',
      icon: '💬',
      isDefault: true,
      threadCount: 1,
      lastActivityAt: DateTime.now().subtract(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      createdBy: 'demo-instructor-2',
    );

    _channels['channel-c3-code'] = ChannelModel(
      id: 'channel-c3-code',
      courseId: 'course-3',
      name: 'Code Reviews',
      description: 'Share your solutions and get feedback',
      icon: 'code',
      threadCount: 0,
      lastActivityAt: null,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      createdBy: 'demo-instructor-2',
    );

    _threadsByChannel['channel-c3-general'] = [
      ThreadModel(
        id: 'thread-6',
        channelId: 'channel-c3-general',
        courseId: 'course-3',
        title: 'When should I use a HashMap vs a TreeMap?',
        content:
            'Both seem to do the same thing (store key-value pairs), but the course mentions '
            'they have different time complexities. When would you choose one over the other '
            'in a real project?',
        authorId: 'student-2',
        authorName: 'Bob Williams',
        replyCount: 1,
        likeCount: 3,
        likedBy: ['student-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
        lastReplyAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];

    _repliesByThread['thread-6'] = [
      ReplyModel(
        id: 'reply-6-1',
        threadId: 'thread-6',
        channelId: 'channel-c3-general',
        courseId: 'course-3',
        content:
            'HashMap gives O(1) average lookup/insert, TreeMap gives O(log n) but keeps keys sorted.\n\n'
            '• Use HashMap/Map when you just need fast lookups.\n'
            '• Use a sorted structure (like SplayTreeMap in Dart) when you need keys in order.\n\n'
            'In practice, HashMap (which is what Dart\'s `Map` uses by default) covers 95% of use cases.',
        authorId: 'demo-instructor-2',
        authorName: 'Jane Smith',
        isInstructorAnswer: true,
        likeCount: 4,
        likedBy: ['student-2', 'student-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];

    _threadsByChannel['channel-c3-code'] = [];
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

    await _supabase!.from(_threadsTable).insert({
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

    await _supabase!.from(_repliesTable).insert({
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
