import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS standalone web app can paint behind the status bar', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('viewport-fit=cover'));
    expect(
      html,
      contains('<meta name="apple-mobile-web-app-capable" content="yes">'),
    );
    expect(
      html,
      contains(
        '<meta name="apple-mobile-web-app-status-bar-style" '
        'content="black-translucent">',
      ),
    );
  });
}
