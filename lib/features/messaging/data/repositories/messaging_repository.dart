import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../models/message_model.dart';

class MessagingRepository {
  static const _messagesTable = 'private_messages';
  final SupabaseClient? _supabase;
  final List<MessageModel> _demoMessages = [];

  MessagingRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client);

  String? get currentUserId => EnvironmentConfig.isDemoMode
      ? 'demo-user-1'
      : _supabase?.auth.currentUser?.id;

  MessageModel _messageFromRpcResult(dynamic result) {
    if (result is List && result.isNotEmpty) {
      return MessageModel.fromMap(
        Map<String, dynamic>.from(result.first as Map),
      );
    }
    if (result is Map) {
      return MessageModel.fromMap(Map<String, dynamic>.from(result));
    }
    throw StateError('The messaging server returned no updated message.');
  }

  List<MessageModel> _sortChronologically(Iterable<MessageModel> messages) {
    return messages.toList()..sort((a, b) {
      final timestampOrder = a.createdAt.toUtc().compareTo(b.createdAt.toUtc());
      return timestampOrder != 0 ? timestampOrder : a.id.compareTo(b.id);
    });
  }

  Future<List<MessageModel>> getConversation({
    required String courseId,
    required String participantId,
  }) async {
    final userId = currentUserId;
    if (userId == null) return const [];
    if (EnvironmentConfig.isDemoMode) {
      return _sortChronologically(
        _demoMessages
            .where(
              (message) =>
                  message.courseId == courseId &&
                  ((message.senderId == userId &&
                          message.recipientId == participantId) ||
                      (message.senderId == participantId &&
                          message.recipientId == userId)),
            )
            .toList(),
      );
    }

    final rows = await _supabase!
        .from(_messagesTable)
        .select()
        .eq('course_id', courseId)
        .or(
          'and(sender_id.eq.$userId,recipient_id.eq.$participantId),'
          'and(sender_id.eq.$participantId,recipient_id.eq.$userId)',
        )
        .order('created_at', ascending: true);
    return _sortChronologically(
      (rows as List<dynamic>).cast<Map<String, dynamic>>().map(
        MessageModel.fromMap,
      ),
    );
  }

  Future<MessageModel> sendMessage({
    required String courseId,
    required String recipientId,
    required String body,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('You must be signed in to message.');
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) throw ArgumentError('Message cannot be empty.');

    if (EnvironmentConfig.isDemoMode) {
      final message = MessageModel(
        id: 'demo-message-${DateTime.now().microsecondsSinceEpoch}',
        courseId: courseId,
        senderId: userId,
        recipientId: recipientId,
        body: trimmedBody,
        createdAt: DateTime.now(),
      );
      _demoMessages.add(message);
      return message;
    }

    final row = await _supabase!
        .from(_messagesTable)
        .insert({
          'course_id': courseId,
          'sender_id': userId,
          'recipient_id': recipientId,
          'body': trimmedBody,
        })
        .select()
        .single();
    return MessageModel.fromMap(row);
  }

  Future<bool> canModifyMessage(String messageId) async {
    if (EnvironmentConfig.isDemoMode) {
      final message = _demoMessages.firstWhere(
        (item) => item.id == messageId,
        orElse: () => throw StateError('Message not found.'),
      );
      return message.senderId == currentUserId &&
          DateTime.now().toUtc().difference(message.createdAt.toUtc()) <=
              const Duration(minutes: 15);
    }
    final result = await _supabase!.rpc(
      'can_modify_private_message',
      params: {'target_message_id': messageId},
    );
    return result == true;
  }

  Future<MessageModel> editMessage({
    required String messageId,
    required String body,
  }) async {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) throw ArgumentError('Message cannot be empty.');
    if (EnvironmentConfig.isDemoMode) {
      final index = _demoMessages.indexWhere((item) => item.id == messageId);
      if (index < 0 || !await canModifyMessage(messageId)) {
        throw StateError('This message can no longer be edited.');
      }
      final message = _demoMessages[index];
      final updated = MessageModel(
        id: message.id,
        courseId: message.courseId,
        senderId: message.senderId,
        recipientId: message.recipientId,
        body: trimmedBody,
        createdAt: message.createdAt,
        readAt: message.readAt,
        editedAt: DateTime.now(),
      );
      _demoMessages[index] = updated;
      return updated;
    }
    final row = await _supabase!.rpc(
      'edit_private_message',
      params: {'target_message_id': messageId, 'new_body': trimmedBody},
    );
    return _messageFromRpcResult(row);
  }

  Future<MessageModel> unsendMessage(String messageId) async {
    if (EnvironmentConfig.isDemoMode) {
      final index = _demoMessages.indexWhere((item) => item.id == messageId);
      if (index < 0 || !await canModifyMessage(messageId)) {
        throw StateError('This message can no longer be unsent.');
      }
      final message = _demoMessages[index];
      final updated = MessageModel(
        id: message.id,
        courseId: message.courseId,
        senderId: message.senderId,
        recipientId: message.recipientId,
        body: 'Message unsent',
        createdAt: message.createdAt,
        readAt: message.readAt,
        editedAt: message.editedAt,
        isUnsent: true,
      );
      _demoMessages[index] = updated;
      return updated;
    }
    final row = await _supabase!.rpc(
      'unsend_private_message',
      params: {'target_message_id': messageId},
    );
    return _messageFromRpcResult(row);
  }

  Future<void> markConversationRead({
    required String courseId,
    required String participantId,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;
    if (EnvironmentConfig.isDemoMode) {
      for (var index = 0; index < _demoMessages.length; index++) {
        final message = _demoMessages[index];
        if (message.courseId == courseId &&
            message.senderId == participantId &&
            message.recipientId == userId &&
            message.readAt == null) {
          _demoMessages[index] = MessageModel(
            id: message.id,
            courseId: message.courseId,
            senderId: message.senderId,
            recipientId: message.recipientId,
            body: message.body,
            createdAt: message.createdAt,
            readAt: DateTime.now(),
          );
        }
      }
      return;
    }
    await _supabase!
        .from(_messagesTable)
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('course_id', courseId)
        .eq('sender_id', participantId)
        .eq('recipient_id', userId)
        .isFilter('read_at', null);
  }

  Future<int> getUnreadCount({
    required String courseId,
    required String participantId,
  }) async {
    final userId = currentUserId;
    if (userId == null) return 0;
    if (EnvironmentConfig.isDemoMode) {
      return _demoMessages
          .where(
            (message) =>
                message.courseId == courseId &&
                message.senderId == participantId &&
                message.recipientId == userId &&
                message.readAt == null,
          )
          .length;
    }
    final rows = await _supabase!
        .from(_messagesTable)
        .select('id')
        .eq('course_id', courseId)
        .eq('sender_id', participantId)
        .eq('recipient_id', userId)
        .isFilter('read_at', null);
    return (rows as List<dynamic>).length;
  }

  RealtimeChannel? subscribeToConversation({
    required String courseId,
    required VoidCallback onChanged,
  }) {
    if (EnvironmentConfig.isDemoMode) return null;
    return _supabase!
        .channel(
          'private-messages-$courseId-${DateTime.now().microsecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _messagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'course_id',
            value: courseId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> removeRealtimeChannel(RealtimeChannel? channel) async {
    if (channel != null && !EnvironmentConfig.isDemoMode) {
      await _supabase!.removeChannel(channel);
    }
  }

  void logError(Object error) {
    if (kDebugMode) log('Messaging error: $error', name: 'MessagingRepository');
  }
}
