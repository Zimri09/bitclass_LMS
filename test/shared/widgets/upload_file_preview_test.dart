import 'dart:convert';
import 'package:bitclass/core/utils/upload_file.dart';
import 'package:bitclass/shared/widgets/upload_file_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'images show thumbnails while document icons follow MIME, not names',
    (tester) async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aZ1cAAAAASUVORK5CYII=',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PendingUploadTile(
                  file: UploadFileData(
                    name: 'misleading.pdf',
                    mimeType: 'image/png',
                    bytes: png,
                  ),
                ),
                const UploadFilePreview(mimeType: 'application/pdf'),
                UploadFilePreview(mimeType: uploadMimeType('file.docx')),
                const UploadFilePreview(mimeType: 'text/plain'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      expect(find.byIcon(Icons.article_outlined), findsOneWidget);
      expect(find.byIcon(Icons.text_snippet_outlined), findsOneWidget);
      expect(find.text('PNG · ${png.length} B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
