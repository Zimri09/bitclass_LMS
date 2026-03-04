import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/models.dart';
import '../../data/repositories/discussion_repository.dart';
import 'discussion_event.dart';
import 'discussion_state.dart';

/// Bloc for managing discussion operations
class DiscussionBloc extends Bloc<DiscussionEvent, DiscussionState> {
  final DiscussionRepository discussionRepository;

  DiscussionBloc({required this.discussionRepository})
    : super(DiscussionInitial()) {
    on<LoadChannels>(_onLoadChannels);
    on<LoadThreads>(_onLoadThreads);
    on<LoadThreadDetail>(_onLoadThreadDetail);
    on<CreateThread>(_onCreateThread);
    on<CreateReply>(_onCreateReply);
    on<ToggleThreadLike>(_onToggleThreadLike);
    on<ToggleReplyLike>(_onToggleReplyLike);
    on<ToggleThreadResolved>(_onToggleThreadResolved);
    on<MarkAsAcceptedAnswer>(_onMarkAsAcceptedAnswer);
  }

  Future<void> _onLoadChannels(
    LoadChannels event,
    Emitter<DiscussionState> emit,
  ) async {
    emit(ChannelsLoading());
    try {
      final channels = await discussionRepository.getChannelsForCourse(
        event.courseId,
      );
      emit(ChannelsLoaded(channels: channels, courseId: event.courseId));
    } catch (e) {
      emit(DiscussionError(message: 'Failed to load channels: $e'));
    }
  }

  Future<void> _onLoadThreads(
    LoadThreads event,
    Emitter<DiscussionState> emit,
  ) async {
    emit(ThreadsLoading());
    try {
      final channel = await discussionRepository.getChannel(event.channelId);
      if (channel == null) {
        emit(const DiscussionError(message: 'Channel not found'));
        return;
      }

      final threads = await discussionRepository.getThreadsForChannel(
        event.channelId,
      );
      emit(ThreadsLoaded(channel: channel, threads: threads));
    } catch (e) {
      emit(DiscussionError(message: 'Failed to load threads: $e'));
    }
  }

  Future<void> _onLoadThreadDetail(
    LoadThreadDetail event,
    Emitter<DiscussionState> emit,
  ) async {
    emit(ThreadDetailLoading());
    try {
      final thread = await discussionRepository.getThread(event.threadId);
      if (thread == null) {
        emit(const DiscussionError(message: 'Thread not found'));
        return;
      }

      final replies = await discussionRepository.getRepliesForThread(
        event.threadId,
      );
      emit(ThreadDetailLoaded(thread: thread, replies: replies));
    } catch (e) {
      emit(DiscussionError(message: 'Failed to load thread: $e'));
    }
  }

  Future<void> _onCreateThread(
    CreateThread event,
    Emitter<DiscussionState> emit,
  ) async {
    try {
      final thread = ThreadModel(
        id: 'thread-${DateTime.now().millisecondsSinceEpoch}',
        channelId: event.channelId,
        courseId: event.courseId,
        title: event.title,
        content: event.content,
        authorId: event.authorId,
        authorName: event.authorName,
        createdAt: DateTime.now(),
      );

      final created = await discussionRepository.createThread(thread);
      emit(ThreadCreated(thread: created));
    } catch (e) {
      emit(DiscussionError(message: 'Failed to create thread: $e'));
    }
  }

  Future<void> _onCreateReply(
    CreateReply event,
    Emitter<DiscussionState> emit,
  ) async {
    final currentState = state;
    if (currentState is ThreadDetailLoaded) {
      emit(currentState.copyWith(isSubmittingReply: true));
    }

    try {
      final reply = ReplyModel(
        id: 'reply-${DateTime.now().millisecondsSinceEpoch}',
        threadId: event.threadId,
        channelId: event.channelId,
        courseId: event.courseId,
        content: event.content,
        authorId: event.authorId,
        authorName: event.authorName,
        createdAt: DateTime.now(),
      );

      final created = await discussionRepository.createReply(reply);
      emit(ReplyCreated(reply: created));

      // Reload thread detail
      add(LoadThreadDetail(threadId: event.threadId));
    } catch (e) {
      emit(DiscussionError(message: 'Failed to post reply: $e'));
    }
  }

  Future<void> _onToggleThreadLike(
    ToggleThreadLike event,
    Emitter<DiscussionState> emit,
  ) async {
    try {
      final updated = await discussionRepository.toggleThreadLike(
        event.threadId,
        event.userId,
      );

      final currentState = state;
      if (currentState is ThreadDetailLoaded &&
          currentState.thread.id == event.threadId) {
        emit(currentState.copyWith(thread: updated));
      }
    } catch (e) {
      emit(DiscussionError(message: 'Failed to update like: $e'));
    }
  }

  Future<void> _onToggleReplyLike(
    ToggleReplyLike event,
    Emitter<DiscussionState> emit,
  ) async {
    try {
      final updated = await discussionRepository.toggleReplyLike(
        event.replyId,
        event.threadId,
        event.userId,
      );

      final currentState = state;
      if (currentState is ThreadDetailLoaded) {
        final replies = currentState.replies.map((r) {
          return r.id == event.replyId ? updated : r;
        }).toList();
        emit(currentState.copyWith(replies: replies));
      }
    } catch (e) {
      emit(DiscussionError(message: 'Failed to update like: $e'));
    }
  }

  Future<void> _onToggleThreadResolved(
    ToggleThreadResolved event,
    Emitter<DiscussionState> emit,
  ) async {
    try {
      final updated = await discussionRepository.toggleThreadResolved(
        event.threadId,
      );

      final currentState = state;
      if (currentState is ThreadDetailLoaded &&
          currentState.thread.id == event.threadId) {
        emit(currentState.copyWith(thread: updated));
      }
    } catch (e) {
      emit(DiscussionError(message: 'Failed to update thread: $e'));
    }
  }

  Future<void> _onMarkAsAcceptedAnswer(
    MarkAsAcceptedAnswer event,
    Emitter<DiscussionState> emit,
  ) async {
    try {
      await discussionRepository.markAsAcceptedAnswer(
        event.replyId,
        event.threadId,
      );

      // Reload thread detail to get updated state
      add(LoadThreadDetail(threadId: event.threadId));
    } catch (e) {
      emit(DiscussionError(message: 'Failed to mark as answer: $e'));
    }
  }
}
