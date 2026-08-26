import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bitclass/features/files/data/models/upload_progress.dart';
import 'package:bitclass/features/files/data/repositories/file_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('private upload saves storage metadata without a public URL', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestsReceived = Completer<void>();
    Map<String, dynamic>? metadata;
    var requestCount = 0;

    final subscription = server.listen((request) async {
      final path = request.uri.path;
      if (path.startsWith('/storage/v1/object/course_materials/')) {
        await request.drain<void>();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({'Key': path.substring('/storage/v1/object/'.length)}),
          );
      } else if (path == '/rest/v1/files') {
        metadata =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response
          ..statusCode = HttpStatus.created
          ..headers.contentType = ContentType.json;
      } else {
        await request.drain<void>();
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();

      requestCount++;
      if (requestCount == 2 && !requestsReceived.isCompleted) {
        requestsReceived.complete();
      }
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

    final progress = await repository
        .uploadFileWithData(
          courseId: '11111111-1111-1111-1111-111111111111',
          lessonId: '22222222-2222-2222-2222-222222222222',
          fileName: 'Topic_2_Threads_OS_Handout.docx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          fileData: Uint8List.fromList(utf8.encode('test document')),
          description: 'Operating systems handout',
          uploaderId: '33333333-3333-3333-3333-333333333333',
          uploaderName: 'Instructor',
        )
        .toList();
    await requestsReceived.future.timeout(const Duration(seconds: 5));

    expect(progress.last.status, UploadStatus.completed);
    expect(metadata, isNotNull);
    expect(metadata!['resource_kind'], 'file');
    expect(metadata!['bucket'], 'course_materials');
    expect(metadata!['storage_path'], isNotEmpty);
    expect(metadata, isNot(contains('public_url')));
  });
}
