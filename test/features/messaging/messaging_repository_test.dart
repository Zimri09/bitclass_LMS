import 'dart:convert';
import 'dart:io';

import 'package:bitclass/features/messaging/data/repositories/messaging_repository.dart';
import 'package:bitclass/features/messaging/data/models/message_reaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'database visibility is reapplied on a fresh repository for each user',
    () async {
      final row = <String, dynamic>{
        'id': 'message',
        'course_id': 'course',
        'sender_id': 'sender',
        'recipient_id': 'recipient',
        'body': 'Original message',
        'created_at': '2026-01-01T00:00:00Z',
        'hidden_for_sender': false,
        'is_unsent': false,
      };
      final calls = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final listener = server.listen((request) async {
        final path = request.uri.path;
        calls.add(path);
        Object? response;
        if (path.contains('/rpc/')) {
          final body = jsonDecode(await utf8.decoder.bind(request).join());
          if (path.endsWith('set_private_message_reaction')) {
            expect(body['target_message_id'], 'message');
            row['sender_reaction'] = body['new_reaction'];
          } else if (path.endsWith('hide_private_message')) {
            expect(body, {'target_message_id': 'message'});
            row['hidden_for_sender'] = true;
          } else if (path.endsWith('hide_received_private_message')) {
            expect(body, {'target_message_id': 'message'});
            row['hidden_for_recipient'] = true;
          } else if (path.endsWith('unsend_private_message')) {
            row['is_unsent'] = true;
            row['body'] = 'Message unsent';
            response = [row];
          }
        } else if (path.endsWith('hidden_private_conversations')) {
          response = [];
        } else {
          expect(request.uri.queryParameters['is_unsent'], 'eq.false');
          if (request.uri.queryParameters['select'] == 'id') {
            expect(request.uri.queryParameters['read_at'], 'is.null');
            expect(
              request.uri.queryParameters['hidden_for_recipient'],
              'eq.false',
            );
          }
          response =
              row['is_unsent'] == true ||
                  (request.uri.queryParameters['hidden_for_recipient'] ==
                          'eq.false' &&
                      row['hidden_for_recipient'] == true)
              ? []
              : [row];
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
      final clients = <SupabaseClient>[];
      _Repository repository(String userId) {
        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          'test-key',
        );
        client.auth.stopAutoRefresh();
        clients.add(client);
        return _Repository(client, userId);
      }

      addTearDown(() async {
        for (final client in clients) {
          client.auth.dispose();
        }
        await listener.cancel();
        await server.close(force: true);
      });

      final sender = repository('sender');
      for (final reaction in [
        MessageReaction.haha,
        MessageReaction.heart,
        null,
      ]) {
        await sender.setReaction(messageId: 'message', reaction: reaction);
        final reopened = await repository(
          'recipient',
        ).getConversation(courseId: 'course', participantId: 'sender');
        expect(reopened.single.senderReaction, reaction);
        expect(reopened.single.recipientReaction, isNull);
        expect(reopened.single.body, 'Original message');
      }
      row['sender_reaction'] = 'heart';
      await repository('recipient').hideMessage('message');
      await repository('recipient').hideMessage('message'); // Idempotent.
      expect(
        await repository(
          'recipient',
        ).getConversation(courseId: 'course', participantId: 'sender'),
        isEmpty,
      );
      expect(
        await repository(
          'recipient',
        ).getUnreadCount(courseId: 'course', participantId: 'sender'),
        0,
      );
      final senderView = await repository(
        'sender',
      ).getConversation(courseId: 'course', participantId: 'recipient');
      expect(senderView.single.body, 'Original message');
      expect(senderView.single.senderReaction, MessageReaction.heart);
      expect(senderView.single.isUnsent, isFalse);
      row['hidden_for_recipient'] = false; // Independent sender-hide scenario.
      await sender.unsendMessageForYou('message');
      expect(
        await repository(
          'sender',
        ).getConversation(courseId: 'course', participantId: 'recipient'),
        isEmpty,
      );
      final received = await repository(
        'recipient',
      ).getConversation(courseId: 'course', participantId: 'sender');
      expect(received.single.body, 'Original message');
      await sender.unsendMessage('message');
      for (final user in ['sender', 'recipient']) {
        final fresh = repository(user);
        expect(
          await fresh.getConversation(
            courseId: 'course',
            participantId: user == 'sender' ? 'recipient' : 'sender',
          ),
          isEmpty,
        );
      }
      expect(
        await repository(
          'recipient',
        ).getUnreadCount(courseId: 'course', participantId: 'sender'),
        0,
      );
      expect(calls, contains('/rest/v1/rpc/hide_private_message'));
      expect(calls, contains('/rest/v1/rpc/unsend_private_message'));
    },
  );
}

class _Repository extends MessagingRepository {
  _Repository(SupabaseClient client, this.userId) : super(supabase: client);
  final String userId;
  @override
  String get currentUserId => userId;
}
