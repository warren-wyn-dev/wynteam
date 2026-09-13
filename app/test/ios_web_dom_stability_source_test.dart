import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Web falls back to Flutter text instead of DOM platform views', () {
    final source = File('lib/core/typography/browser_system_text_web.dart')
        .readAsStringSync();

    expect(source, contains("r'iPhone|iPad|iPod'"));
    expect(
      source,
      contains('bool get usesBrowserSystemTextDom => !_isIosWeb;'),
    );
    expect(source, contains('if (!usesBrowserSystemTextDom)'));
    expect(source, contains("'CupertinoSystemText'"));
    expect(source, contains("'CupertinoSystemDisplay'"));
    expect(source, contains('_iosSystemFontStyle(context, style)'));
    expect(
      source,
      isNot(contains('const bool usesBrowserSystemTextDom = true;')),
    );
  });

  test('iOS Web does not create DOM platform views for emoji', () {
    final source = File('lib/core/typography/native_emoji_web.dart')
        .readAsStringSync();

    expect(source, contains('bool get _isIosWeb'));
    expect(source, contains('!_isIosWeb && _appleBrowserPattern.hasMatch'));
  });
}
