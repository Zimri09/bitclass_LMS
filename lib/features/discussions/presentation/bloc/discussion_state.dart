import 'package:equatable/equatable.dart';

import '../../../../core/errors/app_error.dart';
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
  final String? _actionError;
  String? get actionError =>
      _actionError == null ? null : userFriendlyErrorMessage(_actionError);
  final int actionRevision;
  final String? createdReplyId;

  const ThreadDetailLoaded({
    required this.thread,
    required this.replies,
    this.isSubmittingReply = false,
    String? actionError,
    this.actionRevision = 0,
    this.createdReplyId,
  }) : _actionError = actionError;

  @override
  List<Object?> get props => [
    thread,
    replies,
    isSubmittingReply,
    _actionError,
    actionRevision,
    createdReplyId,
  ];

  ThreadDetailLoaded copyWith({
    ThreadModel? thread,
    List<ReplyModel>? replies,
    bool? isSubmittingReply,
    String? actionError,
    bool clearActionError = false,
    int? actionRevision,
    String? createdReplyId,
    bool clearCreatedReplyId = false,
  }) {
    return ThreadDetailLoaded(
      thread: thread ?? this.thread,
      replies: replies ?? this.replies,
      isSubmittingReply: isSubmittingReply ?? this.isSubmittingReply,
      actionError: clearActionError ? null : actionError ?? _actionError,
      actionRevision: actionRevision ?? this.actionRevision,
      createdReplyId: clearCreatedReplyId
          ? null
          : createdReplyId ?? this.createdReplyId,
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

/// Error state
class DiscussionError extends DiscussionState {
  final String _message;
  String get message => userFriendlyErrorMessage(_message);

  const DiscussionError({required String message}) : _message = message;

  @override
  List<Object?> get props => [_message];
}
