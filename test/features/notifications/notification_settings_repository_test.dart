import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bitclass/features/notifications/data/models/models.dart';
import 'package:bitclass/features/notifications/data/repositories/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('settings upsert targets the unique user_id column', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestReceived = Completer<void>();
    String? method;
    Uri? requestUri;
    Map<String, dynamic>? requestBody;

    final serverSubscription = server.listen((request) async {
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
    final repository = NotificationRepository(supabase: client);

    addTearDown(() async {
      repository.dispose();
      client.auth.dispose();
      await serverSubscription.cancel();
      await server.close(force: true);
    });

    await repository.updateSettings(
      NotificationSettings.defaults('11111111-1111-1111-1111-111111111111'),
    );
    await requestReceived.future;

    expect(method, 'POST');
    expect(requestUri?.path, '/rest/v1/notification_settings');
    expect(requestUri?.queryParameters['on_conflict'], 'user_id');
    expect(
      requestBody?['user_id'],
      '11111111-1111-1111-1111-111111111111',
    );
  });
}
