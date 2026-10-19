import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:bitclass/core/utils/upload_file.dart';

import 'package:bitclass/features/files/data/models/upload_progress.dart';
import 'package:bitclass/features/files/data/repositories/file_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final scope in ['course']) {
    for (final extension in ['txt', 'docx']) {
      test(
        '$scope uploads a small $extension with exact bytes and canonical MIME',
        () async {
          final document = Archive()
            ..addFile(
              ArchiveFile.string(
                '[Content_Types].xml',
                '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>',
              ),
            )
            ..addFile(
              ArchiveFile.string(
                '_rels/.rels',
                '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
              ),
            )
            ..addFile(
              ArchiveFile.string(
                'word/document.xml',
                '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Small document</w:t></w:r></w:p></w:body></w:document>',
              ),
            );
          final bytes = extension == 'txt'
              ? Uint8List.fromList(utf8.encode('Hello'))
              : Uint8List.fromList(ZipEncoder().encode(document));
          expect(bytes.length, lessThan(1024 * 1024));
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          String? uploadBody;
          Map<String, dynamic>? record;
          final subscription = server.listen((request) async {
            final body = await request.fold<List<int>>(
              [],
              (all, chunk) => all..addAll(chunk),
            );
            if (request.uri.path.startsWith('/storage/v1/object/')) {
              uploadBody = latin1.decode(body);
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({'Key': 'uploaded'}));
            } else {
              record = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
              request.response.statusCode = 201;
            }
            await request.response.close();
          });
          final client = SupabaseClient(
            'http://${server.address.address}:${server.port}',
            'test-key',
          );
          client.auth.stopAutoRefresh();
          final files = FileRepository(supabase: client);
          addTearDown(() async {
            files.dispose();
            client.auth.dispose();
            await subscription.cancel();
            await server.close(force: true);
          });
          final name = 'small.$extension';

          final progress = await files
              .uploadFileWithData(
                courseId: 'course',
                fileName: name,
                mimeType: 'application/octet-stream',
                fileData: bytes,
                description: '',
                uploaderId: 'user',
                uploaderName: 'Teacher',
              )
              .toList();
          expect(progress.last.status, UploadStatus.completed);
          expect(record!['size_bytes'], bytes.length);
          expect(record!['mime_type'], uploadMimeType(name));

          expect(uploadBody, contains('content-type: ${uploadMimeType(name)}'));
          expect(uploadBody, contains(latin1.decode(bytes)));
        },
      );
    }
  }
}
