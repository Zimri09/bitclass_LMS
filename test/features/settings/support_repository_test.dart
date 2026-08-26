import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bitclass/features/settings/data/models/support_request.dart';
import 'package:bitclass/features/settings/data/repositories/support_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'submits an authenticated support request to the support table',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestReceived = Completer<void>();
      String? method;
      Uri? requestUri;
      Map<String, dynamic>? requestBody;

      final subscription = server.listen((request) async {
        method = request.method;
        requestUri = request.uri;
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response
          ..statusCode = HttpStatus.created
          ..headers.contentType = ContentType.json;
        await request.response.close();
        requestReceived.complete();
      });

      final client = SupabaseClient(
        'http://${server.address.address}:${server.port}',
        'test-anon-key',
      );
      client.auth.stopAutoRefresh();
      final repository = SupportRepository(supabase: client);

      addTearDown(() async {
        client.auth.dispose();
        await subscription.cancel();
        await server.close(force: true);
      });

      await repository.submitRequest(
        userId: '11111111-1111-1111-1111-111111111111',
        type: SupportRequestType.bug,
        category: 'High',
        subject: 'Quiz timer stopped',
        description: 'The timer stopped after the app resumed.',
        metadata: const {'platform': 'android'},
      );
      await requestReceived.future;

      expect(method, 'POST');
      expect(requestUri?.path, '/rest/v1/support_requests');
      expect(requestBody, {
        'user_id': '11111111-1111-1111-1111-111111111111',
        'request_type': 'bug',
        'category': 'High',
        'subject': 'Quiz timer stopped',
        'description': 'The timer stopped after the app resumed.',
        'metadata': {'platform': 'android'},
      });
    },
  );

  test('rejects an incomplete support request before sending', () async {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    final repository = SupportRepository(supabase: client);
    addTearDown(client.auth.dispose);

    await expectLater(
      repository.submitRequest(
        userId: 'user-1',
        type: SupportRequestType.feedback,
        category: 'General',
        subject: 'Ok',
        description: 'Too short',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('loads support requests with submitter details for an admin', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode([
            {
              'id': 'request-1',
              'user_id': 'user-1',
              'request_type': 'feedback',
              'category': 'General',
              'subject': 'Useful feature',
              'description': 'The offline files page works well.',
              'metadata': {'platform': 'android'},
              'status': 'open',
              'created_at': '2026-08-26T01:00:00Z',
              'updated_at': '2026-08-26T01:00:00Z',
              'profile': {
                'email': 'student@bisu.edu.ph',
                'first_name': 'Test',
                'last_name': 'Student',
                'role': 'student',
              },
            },
          ]),
        );
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'test-anon-key',
    );
    client.auth.stopAutoRefresh();
    final repository = SupportRepository(supabase: client);
    addTearDown(() async {
      client.auth.dispose();
      await subscription.cancel();
      await server.close(force: true);
    });

    final requests = await repository.getRequests();

    expect(requests, hasLength(1));
    expect(requests.single.subject, 'Useful feature');
    expect(requests.single.userDisplayName, 'Test Student');
    expect(requests.single.status, SupportRequestStatus.open);
  });

  test('updates only the selected request status', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? method;
    Uri? requestUri;
    Map<String, dynamic>? requestBody;
    final subscription = server.listen((request) async {
      method = request.method;
      requestUri = request.uri;
      requestBody =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'test-anon-key',
    );
    client.auth.stopAutoRefresh();
    final repository = SupportRepository(supabase: client);
    addTearDown(() async {
      client.auth.dispose();
      await subscription.cancel();
      await server.close(force: true);
    });

    await repository.updateStatus('request-1', SupportRequestStatus.resolved);

    expect(method, 'PATCH');
    expect(requestUri?.path, '/rest/v1/support_requests');
    expect(requestUri?.queryParameters['id'], 'eq.request-1');
    expect(requestBody, {'status': 'resolved'});
  });
}
