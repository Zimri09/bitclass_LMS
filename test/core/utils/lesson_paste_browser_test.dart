@TestOn('browser')
library;

import 'package:bitclass/core/utils/lesson_paste/paste.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('rich paste is handled once only while the lesson editor is active', () {
    var active = false;
    final inserted = <String>[];
    final remove = listenForLessonPaste(
      isActive: () => active,
      insert: inserted.add,
    );
    web.ClipboardEvent paste({bool rich = true}) {
      final data = web.DataTransfer();
      data.setData('text/plain', 'Hello world');
      if (rich) data.setData('text/html', '<p>Hello <b>world</b></p>');
      final event = web.ClipboardEvent(
        'paste',
        web.ClipboardEventInit(
          clipboardData: data,
          bubbles: true,
          cancelable: true,
        ),
      );
      web.document.dispatchEvent(event);
      return event;
    }

    expect(paste().defaultPrevented, isFalse);
    expect(inserted, isEmpty);
    active = true;
    expect(paste().defaultPrevented, isTrue);
    expect(inserted, ['Hello **world**']);
    expect(paste(rich: false).defaultPrevented, isFalse);
    expect(inserted.length, 1);
    remove();
    expect(paste().defaultPrevented, isFalse);
    expect(inserted.length, 1);
  });
}
