import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'html_to_markdown.dart';

void Function() listenForLessonPaste({
  required bool Function() isActive,
  required void Function(String) insert,
}) {
  final listener = ((web.ClipboardEvent event) {
    if (!isActive()) return;
    final source = event.clipboardData?.getData('text/html') ?? '';
    if (source.isEmpty) return; // Let Flutter paste plain Markdown unchanged.
    try {
      final markdown = lessonHtmlToMarkdown(source);
      if (markdown.isEmpty) return;
      event.preventDefault();
      event.stopImmediatePropagation();
      insert(markdown);
    } catch (_) {
      // Unsupported clipboard data must still be pasteable as plain text.
    }
  }).toJS;
  web.document.addEventListener('paste', listener, true.toJS);
  return () => web.document.removeEventListener('paste', listener, true.toJS);
}
