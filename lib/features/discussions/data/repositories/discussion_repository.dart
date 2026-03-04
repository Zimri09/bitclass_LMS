import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/models.dart';

/// Repository for discussion operations
class DiscussionRepository {
  final FirebaseFirestore? _firestore;

  // Demo data storage
  final Map<String, ChannelModel> _channels = {};
  final Map<String, List<ThreadModel>> _threadsByChannel = {};
  final Map<String, List<ReplyModel>> _repliesByThread = {};

  DiscussionRepository({FirebaseFirestore? firestore})
    : _firestore = EnvironmentConfig.isDemoMode
          ? null
          : (firestore ?? FirebaseFirestore.instance) {
    if (EnvironmentConfig.isDemoMode) {
      _initDemoData();
    }
  }

  void _initDemoData() {
    // Flutter Course Channels
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

    _channels['channel-help'] = ChannelModel(
      id: 'channel-help',
      courseId: 'course-1',
      name: 'Help & Questions',
      description: 'Ask questions and get help from instructors and peers',
      icon: '❓',
      threadCount: 5,
      lastActivityAt: DateTime.now().subtract(const Duration(hours: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      createdBy: 'instructor-1',
    );

    _channels['channel-announcements'] = ChannelModel(
      id: 'channel-announcements',
      courseId: 'course-1',
      name: 'Announcements',
      description: 'Important course announcements',
      icon: '📢',
      isAnnouncement: true,
      threadCount: 2,
      lastActivityAt: DateTime.now().subtract(const Duration(days: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      createdBy: 'instructor-1',
    );

    _channels['channel-showcase'] = ChannelModel(
      id: 'channel-showcase',
      courseId: 'course-1',
      name: 'Project Showcase',
      description: 'Share your projects and get feedback',
      icon: '🚀',
      threadCount: 2,
      lastActivityAt: DateTime.now().subtract(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      createdBy: 'instructor-1',
    );

    // Threads for General channel
    _threadsByChannel['channel-general'] = [
      ThreadModel(
        id: 'thread-1',
        channelId: 'channel-general',
        courseId: 'course-1',
        title: 'Welcome to the Flutter Development Course!',
        content: '''
# Welcome Everyone! 👋

I'm excited to have you all here in the Flutter Development course. 

## What to Expect
- Weekly lessons covering Flutter fundamentals
- Hands-on assignments with code editor
- Quizzes to test your knowledge
- This discussion forum for collaboration

Feel free to introduce yourself below! Tell us:
1. Your name
2. Your programming background
3. What you hope to build with Flutter

Let's learn together! 🚀
''',
        authorId: 'instructor-1',
        authorName: 'Dr. Sarah Chen',
        isPinned: true,
        replyCount: 12,
        likeCount: 24,
        likedBy: ['demo_user', 'student-1', 'student-2'],
        createdAt: DateTime.now().subtract(const Duration(days: 28)),
        lastReplyAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      ThreadModel(
        id: 'thread-2',
        channelId: 'channel-general',
        courseId: 'course-1',
        title: 'Study group for weekends?',
        content: '''
Hey everyone! 

I was thinking of starting a study group that meets on weekends via video call. We could work through the exercises together and help each other out.

Anyone interested? Drop a comment below with your availability!
''',
        authorId: 'student-1',
        authorName: 'Alex Johnson',
        replyCount: 8,
        likeCount: 15,
        likedBy: ['demo_user', 'student-2'],
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
        lastReplyAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      ThreadModel(
        id: 'thread-3',
        channelId: 'channel-general',
        courseId: 'course-1',
        title: 'Resources for learning Dart',
        content: '''
I found some great resources for learning Dart alongside this course:

## Official Resources
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Dart Codelabs](https://dart.dev/codelabs)

## YouTube Channels
- The Flutter Way
- Code With Andrea

## Interactive
- DartPad - great for quick experiments

What other resources have you all found helpful?
''',
        authorId: 'student-2',
        authorName: 'Maria Garcia',
        replyCount: 5,
        likeCount: 18,
        likedBy: ['demo_user', 'instructor-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        lastReplyAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];

    // Threads for Help channel
    _threadsByChannel['channel-help'] = [
      ThreadModel(
        id: 'thread-help-1',
        channelId: 'channel-help',
        courseId: 'course-1',
        title: 'setState not updating my UI - help!',
        content: '''
I'm stuck on a problem. I have a counter in my app but when I call setState, the UI doesn't update.

Here's my code:

```dart
class CounterPage extends StatefulWidget {
  @override
  _CounterPageState createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int counter = 0;
  
  void increment() {
    counter++; // Missing setState!
  }
  
  @override
  Widget build(BuildContext context) {
    return Text('\$counter');
  }
}
```

What am I doing wrong?
''',
        authorId: 'student-3',
        authorName: 'James Wilson',
        isResolved: true,
        replyCount: 4,
        likeCount: 3,
        likedBy: [],
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        lastReplyAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      ThreadModel(
        id: 'thread-help-2',
        channelId: 'channel-help',
        courseId: 'course-1',
        title: 'How to pass data between screens?',
        content: '''
I'm trying to pass a user object from my list screen to a detail screen. What's the best way to do this in Flutter?

I've seen people mention:
- Constructor parameters
- Provider
- InheritedWidget

Which should I use for a simple case?
''',
        authorId: 'demo_user',
        authorName: 'Demo Student',
        replyCount: 6,
        likeCount: 8,
        likedBy: ['student-1', 'student-2'],
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        lastReplyAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];

    // Threads for Announcements
    _threadsByChannel['channel-announcements'] = [
      ThreadModel(
        id: 'thread-announce-1',
        channelId: 'channel-announcements',
        courseId: 'course-1',
        title: '📅 Assignment 2 Due Date Extended',
        content:
            '''
# Assignment Extension

Due to the volume of questions about the Todo List assignment, I'm extending the deadline by **3 days**.

**New Due Date:** ${DateTime.now().add(const Duration(days: 10)).toString().split(' ')[0]}

Please use the extra time to:
- Review the starter code carefully
- Check the Help channel for common issues
- Test your app thoroughly

Good luck! 🍀
''',
        authorId: 'instructor-1',
        authorName: 'Dr. Sarah Chen',
        isPinned: true,
        replyCount: 2,
        likeCount: 32,
        likedBy: ['demo_user', 'student-1', 'student-2', 'student-3'],
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        lastReplyAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
    ];

    // Replies for welcome thread
    _repliesByThread['thread-1'] = [
      ReplyModel(
        id: 'reply-1-1',
        threadId: 'thread-1',
        channelId: 'channel-general',
        courseId: 'course-1',
        content: '''
Hi everyone! I'm Alex, a web developer looking to expand into mobile development. Really excited to learn Flutter!

I've been coding in JavaScript for 3 years and recently started learning Dart. Hope to build a fitness tracking app by the end of this course! 💪
''',
        authorId: 'student-1',
        authorName: 'Alex Johnson',
        likeCount: 5,
        likedBy: ['instructor-1', 'demo_user'],
        createdAt: DateTime.now().subtract(const Duration(days: 27)),
      ),
      ReplyModel(
        id: 'reply-1-2',
        threadId: 'thread-1',
        channelId: 'channel-general',
        courseId: 'course-1',
        content: '''
Welcome Alex! Great goal. A fitness app is definitely achievable with what we'll cover. 

Feel free to share your progress in the Project Showcase channel as you build it!
''',
        authorId: 'instructor-1',
        authorName: 'Dr. Sarah Chen',
        isInstructorAnswer: true,
        likeCount: 3,
        likedBy: ['student-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 27)),
      ),
      ReplyModel(
        id: 'reply-1-3',
        threadId: 'thread-1',
        channelId: 'channel-general',
        courseId: 'course-1',
        content: '''
Hey! I'm Maria, computer science student. Some Python and Java experience from school.

I want to build a recipe app for my mom's restaurant. She needs a way to share daily specials with customers! 🍕
''',
        authorId: 'student-2',
        authorName: 'Maria Garcia',
        likeCount: 8,
        likedBy: ['instructor-1', 'student-1', 'demo_user'],
        createdAt: DateTime.now().subtract(const Duration(days: 26)),
      ),
    ];

    // Replies for setState help thread
    _repliesByThread['thread-help-1'] = [
      ReplyModel(
        id: 'reply-help-1-1',
        threadId: 'thread-help-1',
        channelId: 'channel-help',
        courseId: 'course-1',
        content: '''
I see the issue! You're incrementing `counter` but not wrapping it in `setState()`. 

Change your increment method to:

```dart
void increment() {
  setState(() {
    counter++;
  });
}
```

`setState` tells Flutter that the internal state has changed and it needs to rebuild the widget.
''',
        authorId: 'instructor-1',
        authorName: 'Dr. Sarah Chen',
        isInstructorAnswer: true,
        isAcceptedAnswer: true,
        likeCount: 12,
        likedBy: ['student-3', 'demo_user', 'student-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      ReplyModel(
        id: 'reply-help-1-2',
        threadId: 'thread-help-1',
        channelId: 'channel-help',
        courseId: 'course-1',
        content: '''
That worked! Thank you so much Dr. Chen! 🙏

I was confused because in JavaScript, just changing a variable updates the DOM automatically with reactive frameworks. Good to know Flutter works differently.
''',
        authorId: 'student-3',
        authorName: 'James Wilson',
        likeCount: 2,
        likedBy: [],
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];

    // Replies for data passing thread
    _repliesByThread['thread-help-2'] = [
      ReplyModel(
        id: 'reply-help-2-1',
        threadId: 'thread-help-2',
        channelId: 'channel-help',
        courseId: 'course-1',
        content: '''
For simple cases, constructor parameters are the cleanest approach:

```dart
// Navigate with data
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => DetailScreen(user: selectedUser),
  ),
);

// DetailScreen
class DetailScreen extends StatelessWidget {
  final User user;
  const DetailScreen({required this.user});
  
  @override
  Widget build(BuildContext context) {
    return Text(user.name);
  }
}
```

Provider is better when you need to share data across many widgets or the widget tree is deep.
''',
        authorId: 'student-1',
        authorName: 'Alex Johnson',
        likeCount: 6,
        likedBy: ['demo_user', 'student-2'],
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      ReplyModel(
        id: 'reply-help-2-2',
        threadId: 'thread-help-2',
        channelId: 'channel-help',
        courseId: 'course-1',
        content: '''
Alex is right! For simple navigation, constructor parameters are perfect.

This course uses GoRouter, which also supports passing data:

```dart
context.push('/detail', extra: user);
```

Then retrieve it with `GoRouterState.of(context).extra as User`.

We'll cover more advanced state management with BLoC later in the course! 📚
''',
        authorId: 'instructor-1',
        authorName: 'Dr. Sarah Chen',
        isInstructorAnswer: true,
        likeCount: 10,
        likedBy: ['demo_user', 'student-1', 'student-2'],
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    // ── Course 2: Advanced Dart – channels & threads ─────────────────────
    _channels['channel-dart-general'] = ChannelModel(
      id: 'channel-dart-general',
      courseId: 'course-2',
      name: 'General',
      description: 'General discussion about Advanced Dart',
      icon: '💬',
      isDefault: true,
      threadCount: 2,
      lastActivityAt: DateTime.now().subtract(const Duration(hours: 6)),
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      createdBy: 'demo-instructor-1',
    );

    _channels['channel-dart-help'] = ChannelModel(
      id: 'channel-dart-help',
      courseId: 'course-2',
      name: 'Help & Questions',
      description: 'Ask about Dart async, generics, collections and more',
      icon: '❓',
      threadCount: 1,
      lastActivityAt: DateTime.now().subtract(const Duration(hours: 3)),
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      createdBy: 'demo-instructor-1',
    );

    _threadsByChannel['channel-dart-general'] = [
      ThreadModel(
        id: 'thread-dart-1',
        channelId: 'channel-dart-general',
        courseId: 'course-2',
        title: 'Welcome to Advanced Dart!',
        content:
            'Welcome everyone! This course dives deep into Dart — async programming, generics, isolates and more. Share tips and ask questions here.',
        authorId: 'demo-instructor-1',
        authorName: 'John Doe',
        isPinned: true,
        replyCount: 3,
        likeCount: 9,
        likedBy: ['demo-user-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 24)),
        lastReplyAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      ThreadModel(
        id: 'thread-dart-2',
        channelId: 'channel-dart-general',
        courseId: 'course-2',
        title: 'Streams vs Futures — when to use which?',
        content:
            'I understand Futures return a single value, but when should I actually reach for a Stream instead? Any real-world examples?',
        authorId: 'student-1',
        authorName: 'Alice Johnson',
        replyCount: 4,
        likeCount: 11,
        likedBy: ['demo-user-1', 'student-2'],
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        lastReplyAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    _threadsByChannel['channel-dart-help'] = [
      ThreadModel(
        id: 'thread-dart-help-1',
        channelId: 'channel-dart-help',
        courseId: 'course-2',
        title: 'Generic constraint "extends" not working',
        content: '''
I'm trying to constrain a generic type but get a compile error:

```dart
class Repository<T extends Model> { ... }
```

Error says "Model is not a type". Am I missing an import?
''',
        authorId: 'student-2',
        authorName: 'Bob Williams',
        isResolved: true,
        replyCount: 2,
        likeCount: 4,
        likedBy: [],
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        lastReplyAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
    ];

    // ── Course 3: DS&A – channels & threads ──────────────────────────────
    _channels['channel-dsa-general'] = ChannelModel(
      id: 'channel-dsa-general',
      courseId: 'course-3',
      name: 'General',
      description: 'Data Structures & Algorithms discussion',
      icon: '💬',
      isDefault: true,
      threadCount: 1,
      lastActivityAt: DateTime.now().subtract(const Duration(hours: 10)),
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      createdBy: 'demo-instructor-2',
    );

    _channels['channel-dsa-interview'] = ChannelModel(
      id: 'channel-dsa-interview',
      courseId: 'course-3',
      name: 'Interview Prep',
      description: 'Share interview questions and practice together',
      icon: '🎯',
      threadCount: 1,
      lastActivityAt: DateTime.now().subtract(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 55)),
      createdBy: 'demo-instructor-2',
    );

    _threadsByChannel['channel-dsa-general'] = [
      ThreadModel(
        id: 'thread-dsa-1',
        channelId: 'channel-dsa-general',
        courseId: 'course-3',
        title: 'Welcome — course roadmap inside',
        content:
            'Welcome to DS&A! We will cover arrays, linked lists, trees, graphs, sorting and searching. Exercises after each lesson. Good luck!',
        authorId: 'demo-instructor-2',
        authorName: 'Jane Smith',
        isPinned: true,
        replyCount: 2,
        likeCount: 14,
        likedBy: ['demo-user-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 58)),
        lastReplyAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];

    _threadsByChannel['channel-dsa-interview'] = [
      ThreadModel(
        id: 'thread-dsa-interview-1',
        channelId: 'channel-dsa-interview',
        courseId: 'course-3',
        title: 'LeetCode Two-Sum — multiple approaches',
        content: '''
I solved Two-Sum three ways:
1. **Brute force** O(n²)
2. **Hash map** O(n) — the one from our lesson
3. **Two pointers** O(n log n) on sorted arrays

Which approach do interviewers prefer? I'd love to hear your experience.
''',
        authorId: 'student-3',
        authorName: 'Charlie Davis',
        replyCount: 5,
        likeCount: 20,
        likedBy: ['demo-user-1', 'student-1'],
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        lastReplyAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  // ============================================
  // Channel Operations
  // ============================================

  /// Get all channels for a course
  Future<List<ChannelModel>> getChannelsForCourse(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _channels.values.where((c) => c.courseId == courseId).toList()
        ..sort((a, b) {
          // Default channels first, then by name
          if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
          if (a.isAnnouncement != b.isAnnouncement) {
            return a.isAnnouncement ? -1 : 1;
          }
          return a.name.compareTo(b.name);
        });
    }

    try {
      final snapshot = await _firestore!
          .collection(FirestorePaths.channels)
          .where('courseId', isEqualTo: courseId)
          .get();

      var channels = snapshot.docs
          .map((doc) => ChannelModel.fromMap(doc.data()))
          .toList();

      channels.sort((a, b) {
        if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
        if (a.isAnnouncement != b.isAnnouncement) {
          return a.isAnnouncement ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });

      return channels;
    } catch (e) {
      if (kDebugMode)
        log('Error fetching channels: $e', name: 'DiscussionRepository');
      return [];
    }
  }

  /// Get a single channel
  Future<ChannelModel?> getChannel(String channelId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _channels[channelId];
    }

    try {
      final doc = await _firestore!
          .collection(FirestorePaths.channels)
          .doc(channelId)
          .get();

      if (!doc.exists) return null;
      return ChannelModel.fromMap(doc.data()!);
    } catch (e) {
      if (kDebugMode)
        log('Error fetching channel: $e', name: 'DiscussionRepository');
      return null;
    }
  }

  /// Create a new channel
  Future<ChannelModel> createChannel(ChannelModel channel) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _channels[channel.id] = channel;
      return channel;
    }

    await _firestore!
        .collection(FirestorePaths.channels)
        .doc(channel.id)
        .set(channel.toMap());

    return channel;
  }

  // ============================================
  // Thread Operations
  // ============================================

  /// Get threads for a channel
  Future<List<ThreadModel>> getThreadsForChannel(String channelId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final threads = _threadsByChannel[channelId] ?? [];
      return threads.toList()..sort((a, b) {
        // Pinned first, then by last activity
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final aTime = a.lastReplyAt ?? a.createdAt;
        final bTime = b.lastReplyAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
    }

    try {
      final snapshot = await _firestore!
          .collection(FirestorePaths.threads)
          .where('channelId', isEqualTo: channelId)
          .get();

      var threads = snapshot.docs
          .map((doc) => ThreadModel.fromMap(doc.data()))
          .toList();

      threads.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final aTime = a.lastReplyAt ?? a.createdAt;
        final bTime = b.lastReplyAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return threads;
    } catch (e) {
      if (kDebugMode)
        log('Error fetching threads: $e', name: 'DiscussionRepository');
      return [];
    }
  }

  /// Get a single thread
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
      final doc = await _firestore!
          .collection(FirestorePaths.threads)
          .doc(threadId)
          .get();

      if (!doc.exists) return null;
      return ThreadModel.fromMap(doc.data()!);
    } catch (e) {
      if (kDebugMode)
        log('Error fetching thread: $e', name: 'DiscussionRepository');
      return null;
    }
  }

  /// Create a new thread
  Future<ThreadModel> createThread(ThreadModel thread) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 400));

      final threads = _threadsByChannel[thread.channelId] ?? [];
      threads.add(thread);
      _threadsByChannel[thread.channelId] = threads;

      // Update channel thread count
      final channel = _channels[thread.channelId];
      if (channel != null) {
        _channels[thread.channelId] = channel.copyWith(
          threadCount: channel.threadCount + 1,
          lastActivityAt: DateTime.now(),
        );
      }

      return thread;
    }

    await _firestore!
        .collection(FirestorePaths.threads)
        .doc(thread.id)
        .set(thread.toMap());

    // Update channel thread count
    await _firestore
        .collection(FirestorePaths.channels)
        .doc(thread.channelId)
        .update({
          'threadCount': FieldValue.increment(1),
          'lastActivityAt': DateTime.now().toIso8601String(),
        });

    return thread;
  }

  /// Toggle like on a thread
  Future<ThreadModel> toggleThreadLike(String threadId, String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));

      for (final channelId in _threadsByChannel.keys) {
        final threads = _threadsByChannel[channelId]!;
        final index = threads.indexWhere((t) => t.id == threadId);
        if (index >= 0) {
          final thread = threads[index];
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
          threads[index] = updated;
          return updated;
        }
      }
      throw Exception('Thread not found');
    }

    final doc = await _firestore!
        .collection(FirestorePaths.threads)
        .doc(threadId)
        .get();

    if (!doc.exists) throw Exception('Thread not found');

    final thread = ThreadModel.fromMap(doc.data()!);
    final likedBy = List<String>.from(thread.likedBy);

    if (likedBy.contains(userId)) {
      likedBy.remove(userId);
    } else {
      likedBy.add(userId);
    }

    await _firestore.collection(FirestorePaths.threads).doc(threadId).update({
      'likedBy': likedBy,
      'likeCount': likedBy.length,
    });

    return thread.copyWith(likedBy: likedBy, likeCount: likedBy.length);
  }

  /// Toggle resolved status on a thread
  Future<ThreadModel> toggleThreadResolved(String threadId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));

      for (final channelId in _threadsByChannel.keys) {
        final threads = _threadsByChannel[channelId]!;
        final index = threads.indexWhere((t) => t.id == threadId);
        if (index >= 0) {
          final thread = threads[index];
          final updated = thread.copyWith(isResolved: !thread.isResolved);
          threads[index] = updated;
          return updated;
        }
      }
      throw Exception('Thread not found');
    }

    final doc = await _firestore!
        .collection(FirestorePaths.threads)
        .doc(threadId)
        .get();

    if (!doc.exists) throw Exception('Thread not found');

    final thread = ThreadModel.fromMap(doc.data()!);
    final newResolved = !thread.isResolved;

    await _firestore.collection(FirestorePaths.threads).doc(threadId).update({
      'isResolved': newResolved,
    });

    return thread.copyWith(isResolved: newResolved);
  }

  // ============================================
  // Reply Operations
  // ============================================

  /// Get replies for a thread
  Future<List<ReplyModel>> getRepliesForThread(String threadId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final replies = _repliesByThread[threadId] ?? [];
      return replies.toList()..sort((a, b) {
        // Accepted answers first, then instructor answers, then by date
        if (a.isAcceptedAnswer != b.isAcceptedAnswer) {
          return a.isAcceptedAnswer ? -1 : 1;
        }
        if (a.isInstructorAnswer != b.isInstructorAnswer) {
          return a.isInstructorAnswer ? -1 : 1;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
    }

    try {
      final snapshot = await _firestore!
          .collection(FirestorePaths.replies)
          .where('threadId', isEqualTo: threadId)
          .get();

      var replies = snapshot.docs
          .map((doc) => ReplyModel.fromMap(doc.data()))
          .toList();

      replies.sort((a, b) {
        if (a.isAcceptedAnswer != b.isAcceptedAnswer) {
          return a.isAcceptedAnswer ? -1 : 1;
        }
        if (a.isInstructorAnswer != b.isInstructorAnswer) {
          return a.isInstructorAnswer ? -1 : 1;
        }
        return a.createdAt.compareTo(b.createdAt);
      });

      return replies;
    } catch (e) {
      if (kDebugMode)
        log('Error fetching replies: $e', name: 'DiscussionRepository');
      return [];
    }
  }

  /// Create a reply
  Future<ReplyModel> createReply(ReplyModel reply) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 400));

      final replies = _repliesByThread[reply.threadId] ?? [];
      replies.add(reply);
      _repliesByThread[reply.threadId] = replies;

      // Update thread reply count and last reply time
      for (final channelId in _threadsByChannel.keys) {
        final threads = _threadsByChannel[channelId]!;
        final index = threads.indexWhere((t) => t.id == reply.threadId);
        if (index >= 0) {
          final thread = threads[index];
          threads[index] = thread.copyWith(
            replyCount: thread.replyCount + 1,
            lastReplyAt: DateTime.now(),
          );

          // Update channel last activity
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

    await _firestore!
        .collection(FirestorePaths.replies)
        .doc(reply.id)
        .set(reply.toMap());

    // Update thread reply count
    await _firestore
        .collection(FirestorePaths.threads)
        .doc(reply.threadId)
        .update({
          'replyCount': FieldValue.increment(1),
          'lastReplyAt': DateTime.now().toIso8601String(),
        });

    return reply;
  }

  /// Toggle like on a reply
  Future<ReplyModel> toggleReplyLike(
    String replyId,
    String threadId,
    String userId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));

      final replies = _repliesByThread[threadId];
      if (replies == null) throw Exception('Thread not found');

      final index = replies.indexWhere((r) => r.id == replyId);
      if (index < 0) throw Exception('Reply not found');

      final reply = replies[index];
      final likedBy = List<String>.from(reply.likedBy);

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
      } else {
        likedBy.add(userId);
      }

      final updated = reply.copyWith(
        likedBy: likedBy,
        likeCount: likedBy.length,
      );
      replies[index] = updated;
      return updated;
    }

    final doc = await _firestore!
        .collection(FirestorePaths.replies)
        .doc(replyId)
        .get();

    if (!doc.exists) throw Exception('Reply not found');

    final reply = ReplyModel.fromMap(doc.data()!);
    final likedBy = List<String>.from(reply.likedBy);

    if (likedBy.contains(userId)) {
      likedBy.remove(userId);
    } else {
      likedBy.add(userId);
    }

    await _firestore.collection(FirestorePaths.replies).doc(replyId).update({
      'likedBy': likedBy,
      'likeCount': likedBy.length,
    });

    return reply.copyWith(likedBy: likedBy, likeCount: likedBy.length);
  }

  /// Mark reply as accepted answer
  Future<ReplyModel> markAsAcceptedAnswer(
    String replyId,
    String threadId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));

      final replies = _repliesByThread[threadId];
      if (replies == null) throw Exception('Thread not found');

      // Remove accepted from other replies
      for (int i = 0; i < replies.length; i++) {
        if (replies[i].isAcceptedAnswer) {
          replies[i] = replies[i].copyWith(isAcceptedAnswer: false);
        }
      }

      final index = replies.indexWhere((r) => r.id == replyId);
      if (index < 0) throw Exception('Reply not found');

      final updated = replies[index].copyWith(isAcceptedAnswer: true);
      replies[index] = updated;

      // Mark thread as resolved
      await toggleThreadResolved(threadId);

      return updated;
    }

    // Remove accepted from other replies in Firestore
    final repliesSnapshot = await _firestore!
        .collection(FirestorePaths.replies)
        .where('threadId', isEqualTo: threadId)
        .where('isAcceptedAnswer', isEqualTo: true)
        .get();

    for (final doc in repliesSnapshot.docs) {
      await doc.reference.update({'isAcceptedAnswer': false});
    }

    // Mark the selected reply as accepted
    await _firestore.collection(FirestorePaths.replies).doc(replyId).update({
      'isAcceptedAnswer': true,
    });

    final doc = await _firestore
        .collection(FirestorePaths.replies)
        .doc(replyId)
        .get();

    final reply = ReplyModel.fromMap(doc.data()!);

    // Mark thread as resolved
    await toggleThreadResolved(threadId);

    return reply;
  }
}
