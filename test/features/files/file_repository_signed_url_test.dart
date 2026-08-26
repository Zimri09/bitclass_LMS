import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bitclass/features/files/data/models/file_model.dart';
import 'package:bitclass/features/files/data/repositories/file_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('private course material requests a short-lived signed URL', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestReceived = Completer<HttpRequest>();
    final subscription = server.listen((request) async {
      requestReceived.complete(request);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'signedURL':
                '/storage/v1/object/sign/course_materials/course-1/file.pdf'
                '?token=test-token',
          }),
        );
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'test-anon-key',
    );
    client.auth.stopAutoRefresh();
    final repository = FileRepository(supabase: client);

    addTearDown(() async {
      repository.dispose();
      client.auth.dispose();
      await subscription.cancel();
      await server.close(force: true);
    });

    final url = await repository.getAccessibleUrl(
      CourseFile(
        id: 'file-1',
        courseId: 'course-1',
        uploaderId: 'instructor-1',
        uploaderName: 'Instructor',
        name: 'file.pdf',
        url: '',
        storageBucket: 'course_materials',
        storagePath: 'course-1/file.pdf',
        type: FileType.document,
        mimeType: 'application/pdf',
        sizeBytes: 42,
        createdAt: DateTime.utc(2026, 8, 25),
      ),
    );
    final request = await requestReceived.future;

    expect(request.method, 'POST');
    expect(
      request.uri.path,
      '/storage/v1/object/sign/course_materials/course-1/file.pdf',
    );
    expect(url, contains('token=test-token'));
  });
}
