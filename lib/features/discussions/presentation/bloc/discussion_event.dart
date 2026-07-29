import 'package:equatable/equatable.dart';

import '../../data/models/reaction_type.dart';

/// Discussion Bloc Events
abstract class DiscussionEvent extends Equatable {
  const DiscussionEvent();

  @override
  List<Object?> get props => [];
}

/// Load channels for a course
class LoadChannels extends DiscussionEvent {
  final String courseId;

  const LoadChannels({required this.courseId});

  @override
  List<Object?> get props => [courseId];
}

/// Load threads for a channel
class LoadThreads extends DiscussionEvent {
  final String channelId;

  const LoadThreads({required this.channelId});

  @override
  List<Object?> get props => [channelId];
}

/// Load thread detail with replies
class LoadThreadDetail extends DiscussionEvent {
  final String threadId;

  const LoadThreadDetail({required this.threadId});

  @override
  List<Object?> get props => [threadId];
}

/// Refresh thread data without replacing the visible page with a loader.
class RefreshThreadDetail extends DiscussionEvent {
  final String threadId;

  const RefreshThreadDetail({required this.threadId});

  @override
  List<Object?> get props => [threadId];
}

/// Merge a Realtime thread update into the currently visible thread.
class ApplyThreadRealtimeUpdate extends DiscussionEvent {
  final Map<String, dynamic> record;

  const ApplyThreadRealtimeUpdate({required this.record});

  @override
  List<Object?> get props => [record];
}

/// Merge a Realtime reply update into only the affected visible reply.
class ApplyReplyRealtimeUpdate extends DiscussionEvent {
  final Map<String, dynamic> record;

  const ApplyReplyRealtimeUpdate({required this.record});

  @override
  List<Object?> get props => [record];
}

/// Create a new thread
class CreateThread extends DiscussionEvent {
  final String channelId;
  final String courseId;
  final String title;
  final String content;
  final String authorId;
  final String authorName;

  const CreateThread({
    required this.channelId,
    required this.courseId,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
  });

  @override
  List<Object?> get props => [
    channelId,
    courseId,
    title,
    content,
    authorId,
    authorName,
  ];
}

/// Create a reply to a thread
class CreateReply extends DiscussionEvent {
  final String threadId;
  final String channelId;
  final String courseId;
  final String content;
  final String authorId;
  final String authorName;

  const CreateReply({
    required this.threadId,
    required this.channelId,
    required this.courseId,
    required this.content,
    required this.authorId,
    required this.authorName,
  });

  @override
  List<Object?> get props => [
    threadId,
    channelId,
    courseId,
    content,
    authorId,
    authorName,
  ];
}

/// Edit a reply owned by the current user.
class EditReply extends DiscussionEvent {
  final String replyId;
  final String threadId;
  final String authorId;
  final String content;

  const EditReply({
    required this.replyId,
    required this.threadId,
    required this.authorId,
    required this.content,
  });

  @override
  List<Object?> get props => [replyId, threadId, authorId, content];
}

/// Add, change, or remove the current user's thread reaction.
class SetThreadReaction extends DiscussionEvent {
  final String threadId;
  final String userId;
  final ReactionType reaction;

  const SetThreadReaction({
    required this.threadId,
    required this.userId,
    required this.reaction,
  });

  @override
  List<Object?> get props => [threadId, userId, reaction];
}

/// Add, change, or remove the current user's reply reaction.
class SetReplyReaction extends DiscussionEvent {
  final String replyId;
  final String threadId;
  final String userId;
  final ReactionType reaction;

  const SetReplyReaction({
    required this.replyId,
    required this.threadId,
    required this.userId,
    required this.reaction,
  });

  @override
  List<Object?> get props => [replyId, threadId, userId, reaction];
}

/// Mark thread as resolved
class ToggleThreadResolved extends DiscussionEvent {
  final String threadId;

  const ToggleThreadResolved({required this.threadId});

  @override
  List<Object?> get props => [threadId];
}
