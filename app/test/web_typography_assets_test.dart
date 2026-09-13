import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web typography is bundled locally with its OFL notice', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: WYNWebNotoThai'));
    expect(
      pubspec,
      contains(
        'assets/fonts/NotoSansThai/NotoSansThai[wdth,wght].ttf',
      ),
    );
    expect(pubspec, contains('assets/fonts/NotoSansThai/OFL.txt'));

    final font = File(
      'assets/fonts/NotoSansThai/NotoSansThai[wdth,wght].ttf',
    );
    expect(font.existsSync(), isTrue);
    expect(font.lengthSync(), greaterThan(100000));

    final license = File('assets/fonts/NotoSansThai/OFL.txt');
    expect(license.existsSync(), isTrue);
    expect(
      license.readAsStringSync(),
      contains('SIL OPEN FONT LICENSE Version 1.1'),
    );
  });

  test('web typography has no runtime external font download', () {
    final files = <File>[
      File('lib/main.dart'),
      File('lib/core/design/wyn_theme.dart'),
      File('lib/core/typography/browser_system_text.dart'),
      File('lib/core/typography/browser_system_text_stub.dart'),
    ];
    final text = files.map((file) => file.readAsStringSync()).join('\n');

    expect(text, isNot(contains('fonts.googleapis.com')));
    expect(text, isNot(contains('fonts.gstatic.com')));
    expect(text, isNot(contains('raw.githubusercontent.com/google/fonts')));
    expect(text, isNot(contains('NetworkAssetBundle')));
  });
}
