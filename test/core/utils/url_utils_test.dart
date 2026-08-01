import 'package:bitclass/core/utils/url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeWebUrl', () {
    test('adds HTTPS when the scheme is omitted', () {
      expect(
        normalizeWebUrl('Example.com/lesson').toString(),
        'https://example.com/lesson',
      );
    });

    test('keeps valid HTTP and HTTPS links', () {
      expect(normalizeWebUrl('http://example.com').scheme, 'http');
      expect(normalizeWebUrl('https://example.com').scheme, 'https');
    });

    test('rejects empty, unsafe, and malformed links', () {
      expect(() => normalizeWebUrl(''), throwsFormatException);
      expect(() => normalizeWebUrl('javascript:alert(1)'), throwsFormatException);
      expect(() => normalizeWebUrl('mailto:user@example.com'), throwsFormatException);
      expect(() => normalizeWebUrl('not a link'), throwsFormatException);
    });
  });

  test('optional validation permits an empty value', () {
    expect(validateWebUrl('', required: false), isNull);
  });
}
