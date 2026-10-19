import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// Converts only newly pasted HTML. Stored Markdown and plain-text pastes never
/// pass through this converter, so code indentation and authored spacing survive.
String lessonHtmlToMarkdown(String source) {
  final fragment = html.parseFragment(source);
  final converted = _Converter().nodes(fragment.nodes);
  // Strip generated block separators, not meaningful inline edge spaces.
  final hasBlocks =
      fragment.querySelector('p,div,pre,ul,ol,h1,h2,h3,h4,h5,h6,blockquote') !=
      null;
  return hasBlocks ? converted.trim() : converted;
}

class _Converter {
  String nodes(List<Node> nodes) {
    var result = '';
    for (final child in nodes) {
      var value = node(child);
      if (result.endsWith(' ') &&
          value.startsWith(' ') &&
          !(child is Element && ['code', 'pre'].contains(child.localName))) {
        value = value.substring(1);
      }
      if (result.endsWith('\n') && value.trim().isEmpty) continue;
      if (result.endsWith('\n') && value.startsWith('\n')) {
        // Join adjacent block separators without accumulating blank paragraphs.
        final trailing = RegExp(r'\n+$').firstMatch(result)![0]!.length;
        final leading = RegExp(r'^\n+').firstMatch(value)![0]!.length;
        result = result.substring(0, result.length - trailing);
        value = value.substring(leading);
        result += '\n' * (trailing > leading ? trailing : leading).clamp(1, 2);
      }
      result += value;
    }
    return result;
  }

  String mark(String text, String marker) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;
    final start = text.indexOf(trimmed);
    return '${text.substring(0, start)}$marker$trimmed$marker${text.substring(start + trimmed.length)}';
  }

  String node(Node n) {
    if (n is Text) {
      // Collapse HTML layout whitespace, without trimming inline boundaries.
      return n.data
          .replaceAll(RegExp(r'[\s\u00a0]+'), ' ')
          .replaceAllMapped(RegExp(r'[\\`*_\[\]<>#]'), (m) => '\\${m[0]}');
    }
    if (n is! Element) return '';
    final tag = n.localName;
    final style = n.attributes['style'] ?? '';
    if (['script', 'style', 'head', 'meta', 'link', 'xml'].contains(tag) ||
        RegExp(
          r'mso-list\s*:\s*ignore|display\s*:\s*none',
          caseSensitive: false,
        ).hasMatch(style)) {
      return '';
    }
    if (tag == 'pre') {
      final text = n.text.replaceAll('\r\n', '\n');
      final runs = RegExp(r'`+').allMatches(text).map((m) => m[0]!.length);
      final length = runs.fold<int>(2, (a, b) => a > b ? a : b) + 1;
      final fence = '`' * length;
      return '\n\n$fence\n$text${text.endsWith('\n') ? '' : '\n'}$fence\n\n';
    }
    if (tag == 'code') {
      final text = n.text;
      final length =
          RegExp(r'`+')
              .allMatches(text)
              .fold<int>(0, (a, m) => a > m[0]!.length ? a : m[0]!.length) +
          1;
      final fence = '`' * length;
      return '$fence $text $fence';
    }
    if (tag == 'br') return '\n';
    if (tag == 'hr') return '\n\n---\n\n';
    if (tag == 'ul' || tag == 'ol') return list(n);
    var text = nodes(n.nodes);
    if (tag == 'b' ||
        tag == 'strong' ||
        RegExp(
          r'font-weight\s*:\s*(bold|[7-9]00)',
          caseSensitive: false,
        ).hasMatch(style)) {
      text = mark(text, '**');
    }
    if (tag == 'i' ||
        tag == 'em' ||
        RegExp(
          r'font-style\s*:\s*italic',
          caseSensitive: false,
        ).hasMatch(style)) {
      text = mark(text, '*');
    }
    if (tag == 'a') {
      final href = n.attributes['href'] ?? '';
      if (RegExp(
        r'^(https?://|mailto:)',
        caseSensitive: false,
      ).hasMatch(href)) {
        text =
            '[${text.trim()}](<${href.replaceAll('>', '%3E').replaceAll('<', '%3C')}>)';
      }
    }
    if (tag == 'img') return n.attributes['alt'] ?? '';
    final heading = RegExp(r'^h([1-6])$').firstMatch(tag ?? '');
    final wordHeading = RegExp(r'^MsoHeading([1-6])$').firstMatch(n.className);
    if (heading != null || wordHeading != null) {
      final level = int.parse((heading ?? wordHeading)![1]!);
      return '\n\n${'#' * level} ${text.trim()}\n\n';
    }
    if (tag == 'blockquote') {
      return '\n\n${text.trim().split('\n').map((l) => '> $l').join('\n')}\n\n';
    }
    if (tag == 'p' &&
        (style.contains('mso-list:') ||
            n.className.contains('MsoListParagraph'))) {
      final level =
          int.tryParse(RegExp(r'level(\d+)').firstMatch(style)?[1] ?? '') ?? 1;
      // Word uses ordinary paragraphs with a hidden marker span for lists.
      final markerText = n.text.trimLeft();
      final number = RegExp(r'^(\d+)[.)]\s*').firstMatch(markerText);
      final marker = number == null ? '-' : '${number[1]}.';
      text = text.trim().replaceFirst(RegExp(r'^(?:\d+[.)]|[•·▪○])\s+'), '');
      return '\n${'    ' * (level - 1).clamp(0, 8)}$marker $text\n';
    }
    if (['p', 'div', 'section', 'article', 'header', 'tr'].contains(tag)) {
      if (text.trim().isEmpty) return '';
      // Block boundaries are added structurally; never normalize code contents.
      return '\n\n${text.trim()}\n\n';
    }
    if (tag == 'td' || tag == 'th') return '$text ';
    return text;
  }

  String list(Element element) {
    var index = int.tryParse(element.attributes['start'] ?? '') ?? 1;
    final items = <String>[];
    for (final li in element.children.where((e) => e.localName == 'li')) {
      final marker = element.localName == 'ol' ? '${index++}.' : '-';
      final content = nodes(li.nodes).trim();
      final lines = content.split('\n');
      final indent = ' ' * (marker.length + 1);
      items.add(
        '$marker ${lines.first}${lines.skip(1).map((l) => '\n$indent$l').join()}',
      );
    }
    return '\n\n${items.join('\n')}\n\n';
  }
}
