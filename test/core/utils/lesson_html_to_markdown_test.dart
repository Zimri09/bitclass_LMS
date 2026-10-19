import 'package:bitclass/core/utils/lesson_paste/html_to_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTML whitespace split across spans does not duplicate spaces', () {
    expect(
      lessonHtmlToMarkdown('<p><span>One </span> <span> two</span></p>'),
      'One two',
    );
  });
  test('inline clipboard boundaries retain their meaningful spaces', () {
    expect(lessonHtmlToMarkdown('<span> hello </span>'), ' hello ');
  });
  test('keeps spaces across inline elements and separates paragraphs', () {
    expect(
      lessonHtmlToMarkdown(
        '<p>Hello <b>bold </b>world&nbsp; again.</p><p>Next<br>line.</p>',
      ),
      'Hello **bold** world again.\n\nNext\nline.',
    );
  });
  test('converts Word styles and drops document metadata', () {
    expect(
      lessonHtmlToMarkdown(
        '''<style>p {color:red}</style><p class="MsoHeading2">Title</p>
<p><span style="font-weight:700">Bold</span> and <span style="font-style:italic">italic</span>.</p>''',
      ),
      '## Title\n\n**Bold** and *italic*.',
    );
  });
  test('Word list markers are not duplicated and levels are retained', () {
    expect(
      lessonHtmlToMarkdown(
        '''<p class="MsoListParagraph" style="mso-list:l0 level1 lfo1"><span style="mso-list:Ignore">1. </span>First</p><p class="MsoListParagraph" style="mso-list:l0 level2 lfo1"><span style="mso-list:Ignore">• </span>Child</p>''',
      ),
      '1. First\n    - Child',
    );
  });
  test('semantic lists preserve starting number and nested bullets', () {
    expect(
      lessonHtmlToMarkdown(
        '<ol start="3"><li>First<ul><li>Child</li></ul></li><li>Second</li></ol>',
      ),
      '3. First\n   \n   - Child\n4. Second',
    );
  });
  test('code whitespace and embedded fences are preserved', () {
    expect(
      lessonHtmlToMarkdown('<pre>  first\n\n\n```\n  last  </pre>'),
      '````\n  first\n\n\n```\n  last  \n````',
    );
  });
  test('literal Markdown in rich text is escaped', () {
    expect(
      lessonHtmlToMarkdown('<p>array[0] * value_name</p>'),
      r'array\[0\] \* value\_name',
    );
  });
  test(
    'adjacent blocks and empty Word paragraphs do not accumulate blanks',
    () {
      expect(
        lessonHtmlToMarkdown('<div><p>One</p><p>&nbsp;</p><p>Two</p></div>'),
        'One\n\nTwo',
      );
    },
  );
  test('unsafe links and scripts never become active Markdown', () {
    expect(
      lessonHtmlToMarkdown(
        '<p><a href="javascript:alert(1)">Text</a></p><script>bad()</script>',
      ),
      'Text',
    );
  });
}
