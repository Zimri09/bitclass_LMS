import 'package:equatable/equatable.dart';

import '../../data/models/models.dart';

/// Discussion Bloc States
abstract class DiscussionState extends Equatable {
  const DiscussionState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class DiscussionInitial extends DiscussionState {}

/// Loading channels
class ChannelsLoading extends DiscussionState {}

/// Channels loaded
class ChannelsLoaded extends DiscussionState {
  final List<ChannelModel> channels;
  final String courseId;

  const ChannelsLoaded({required this.channels, required this.courseId});

  @override
  List<Object?> get props => [channels, courseId];
}

/// Loading threads
class ThreadsLoading extends DiscussionState {}

/// Threads loaded
class ThreadsLoaded extends DiscussionState {
  final ChannelModel channel;
  final List<ThreadModel> threads;

  const ThreadsLoaded({required this.channel, required this.threads});

  @override
  List<Object?> get props => [channel, threads];
}

/// Loading thread detail
class ThreadDetailLoading extends DiscussionState {}

/// Thread detail loaded with replies
class ThreadDetailLoaded extends DiscussionState {
  final ThreadModel thread;
  final List<ReplyModel> replies;
  final bool isSubmittingReply;

  const ThreadDetailLoaded({
    required this.thread,
    required this.replies,
    this.isSubmittingReply = false,
  });

  @override
  List<Object?> get props => [thread, replies, isSubmittingReply];

  ThreadDetailLoaded copyWith({
    ThreadModel? thread,
    List<ReplyModel>? replies,
    bool? isSubmittingReply,
  }) {
    return ThreadDetailLoaded(
      thread: thread ?? this.thread,
      replies: replies ?? this.replies,
      isSubmittingReply: isSubmittingReply ?? this.isSubmittingReply,
    );
  }
}

/// Thread created successfully
class ThreadCreated extends DiscussionState {
  final ThreadModel thread;

  const ThreadCreated({required this.thread});

  @override
  List<Object?> get props => [thread];
}

/// Reply created successfully
class ReplyCreated extends DiscussionState {
  final ReplyModel reply;

  const ReplyCreated({required this.reply});

  @override
  List<Object?> get props => [reply];
}

/// Error state
class DiscussionError extends DiscussionState {
  final String message;

  const DiscussionError({required this.message});

  @override
  List<Object?> get props => [message];
}
