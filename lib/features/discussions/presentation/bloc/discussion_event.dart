import 'package:equatable/equatable.dart';

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

/// Toggle like on a thread
class ToggleThreadLike extends DiscussionEvent {
  final String threadId;
  final String userId;

  const ToggleThreadLike({required this.threadId, required this.userId});

  @override
  List<Object?> get props => [threadId, userId];
}

/// Toggle like on a reply
class ToggleReplyLike extends DiscussionEvent {
  final String replyId;
  final String threadId;
  final String userId;

  const ToggleReplyLike({
    required this.replyId,
    required this.threadId,
    required this.userId,
  });

  @override
  List<Object?> get props => [replyId, threadId, userId];
}

/// Mark thread as resolved
class ToggleThreadResolved extends DiscussionEvent {
  final String threadId;

  const ToggleThreadResolved({required this.threadId});

  @override
  List<Object?> get props => [threadId];
}

/// Mark reply as accepted answer
class MarkAsAcceptedAnswer extends DiscussionEvent {
  final String replyId;
  final String threadId;

  const MarkAsAcceptedAnswer({required this.replyId, required this.threadId});

  @override
  List<Object?> get props => [replyId, threadId];
}
