import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

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
    on<RefreshThreadDetail>(_onRefreshThreadDetail);
    on<ApplyThreadRealtimeUpdate>(_onApplyThreadRealtimeUpdate);
    on<ApplyReplyRealtimeUpdate>(_onApplyReplyRealtimeUpdate);
    on<CreateThread>(_onCreateThread);
    on<CreateReply>(_onCreateReply);
    on<EditReply>(_onEditReply);
    on<SetThreadReaction>(_onSetThreadReaction);
    on<SetReplyReaction>(_onSetReplyReaction);
    on<ToggleThreadResolved>(_onToggleThreadResolved);
  }

  void _onApplyThreadRealtimeUpdate(
    ApplyThreadRealtimeUpdate event,
    Emitter<DiscussionState> emit,
  ) {
    final currentState = state;
    if (currentState is! ThreadDetailLoaded) return;
    if (event.record['id'] != currentState.thread.id) return;

    emit(
      currentState.copyWith(
        thread: discussionRepository.mergeThreadRealtimeRecord(
          currentState.thread,
          event.record,
        ),
        clearActionError: true,
      ),
    );
  }

  void _onApplyReplyRealtimeUpdate(
    ApplyReplyRealtimeUpdate event,
    Emitter<DiscussionState> emit,
  ) {
    final currentState = state;
    if (currentState is! ThreadDetailLoaded) return;
    final replyId = event.record['id'];
    final index = currentState.replies.indexWhere(
      (reply) => reply.id == replyId,
    );
    if (index < 0) return;

    final replies = List<ReplyModel>.of(currentState.replies);
    replies[index] = discussionRepository.mergeReplyRealtimeRecord(
      replies[index],
      event.record,
    );
    emit(currentState.copyWith(replies: replies, clearActionError: true));
  }

  Future<void> _onRefreshThreadDetail(
    RefreshThreadDetail event,
    Emitter<DiscussionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ThreadDetailLoaded) return;

    try {
      final thread = await discussionRepository.getThread(event.threadId);
      if (thread == null) return;
      final replies = await discussionRepository.getRepliesForThread(
        event.threadId,
      );
      emit(
        currentState.copyWith(
          thread: thread,
          replies: replies,
          clearActionError: true,
        ),
      );
    } catch (_) {
      // Realtime refresh failures should not replace usable discussion content.
    }
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
        id: const Uuid().v4(),
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
        id: const Uuid().v4(),
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

  Future<void> _onSetThreadReaction(
    SetThreadReaction event,
    Emitter<DiscussionState> emit,
  ) async {
    final previousState = state;
    if (previousState is ThreadDetailLoaded &&
        previousState.thread.id == event.threadId) {
      final remove =
          previousState.thread.reactionForUser(event.userId) == event.reaction;
      emit(
        previousState.copyWith(
          thread: previousState.thread.toggleReaction(
            event.reaction,
            userId: event.userId,
          ),
          clearActionError: true,
        ),
      );

      try {
        await discussionRepository.setThreadReaction(
          event.threadId,
          event.userId,
          event.reaction,
          remove: remove,
        );
      } catch (e) {
        emit(
          previousState.copyWith(
            actionError: 'Failed to update reaction: $e',
            actionRevision: previousState.actionRevision + 1,
          ),
        );
      }
    }
  }

  Future<void> _onSetReplyReaction(
    SetReplyReaction event,
    Emitter<DiscussionState> emit,
  ) async {
    final previousState = state;
    if (previousState is ThreadDetailLoaded) {
      final target = previousState.replies
          .where((reply) => reply.id == event.replyId)
          .firstOrNull;
      if (target == null) return;
      final remove = target.reactionForUser(event.userId) == event.reaction;
      final replies = previousState.replies.map((reply) {
        return reply.id == event.replyId
            ? reply.toggleReaction(event.reaction, userId: event.userId)
            : reply;
      }).toList();
      emit(previousState.copyWith(replies: replies, clearActionError: true));

      try {
        await discussionRepository.setReplyReaction(
          event.replyId,
          event.threadId,
          event.userId,
          event.reaction,
          remove: remove,
        );
      } catch (e) {
        emit(
          previousState.copyWith(
            actionError: 'Failed to update reaction: $e',
            actionRevision: previousState.actionRevision + 1,
          ),
        );
      }
    }
  }

  Future<void> _onEditReply(
    EditReply event,
    Emitter<DiscussionState> emit,
  ) async {
    final previousState = state;
    if (previousState is! ThreadDetailLoaded) return;

    final target = previousState.replies
        .where((reply) => reply.id == event.replyId)
        .firstOrNull;
    if (target == null || target.authorId != event.authorId) return;

    final editedAt = DateTime.now().toUtc();
    final optimisticReplies = previousState.replies.map((reply) {
      return reply.id == event.replyId
          ? reply.copyWith(
              content: event.content,
              editedAt: editedAt,
              updatedAt: editedAt,
            )
          : reply;
    }).toList();
    emit(
      previousState.copyWith(
        replies: optimisticReplies,
        clearActionError: true,
      ),
    );

    try {
      await discussionRepository.editReply(
        replyId: event.replyId,
        threadId: event.threadId,
        authorId: event.authorId,
        content: event.content,
        editedAt: editedAt,
      );
    } catch (e) {
      emit(
        previousState.copyWith(
          actionError: 'Failed to edit reply: $e',
          actionRevision: previousState.actionRevision + 1,
        ),
      );
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
}
