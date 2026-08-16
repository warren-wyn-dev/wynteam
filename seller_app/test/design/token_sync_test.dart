// Drift detector for the design-token mirror described in
// .wyn/docs/design/ds-001-color-system.md, Section 7 ("วิธีกัน drift").
//
// app/lib/core/design/*.dart is the CANONICAL SOURCE (per the header
// comment in every one of those files). seller_app/lib/core/design/*.dart
// mirrors those 4 files verbatim -- this test reads both sides with
// `dart:io` and fails loudly, naming the exact file, if they ever diverge.
//
// `wyn_zoky_theme.dart` is intentionally NOT checked here -- it is a
// seller_app-only file (the ZOKY sub-theme), not a mirror of anything in
// app/.
//
// Uses a relative path from `seller_app/` up to the sibling `app/`
// directory (`.wyn/company/DECISIONS.md`, 2026-08-15: no Melos/monorepo
// tooling, `seller_app/` and `app/` are plain sibling folders at repo
// root) -- `flutter test` runs with the package root as the working
// directory, so `../app/...` resolves correctly.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('design token mirror stays in sync with app/', () {
    const mirroredFiles = [
      'wyn_colors.dart',
      'wyn_typography.dart',
      'wyn_spacing.dart',
      'wyn_theme.dart',
    ];

    for (final fileName in mirroredFiles) {
      test('$fileName matches app/lib/core/design/$fileName byte-for-byte', () {
        final canonical = File('../app/lib/core/design/$fileName');
        final mirror = File('lib/core/design/$fileName');

        expect(
          canonical.existsSync(),
          isTrue,
          reason:
              'Canonical source app/lib/core/design/$fileName is missing -- '
              'cannot verify token sync.',
        );
        expect(
          mirror.existsSync(),
          isTrue,
          reason:
              'Mirror seller_app/lib/core/design/$fileName is missing -- '
              'copy it from app/lib/core/design/$fileName.',
        );

        final canonicalContent = canonical.readAsStringSync();
        final mirrorContent = mirror.readAsStringSync();

        expect(
          mirrorContent,
          equals(canonicalContent),
          reason:
              'Design token drift detected: seller_app/lib/core/design/'
              '$fileName no longer matches app/lib/core/design/$fileName. '
              'app/lib/core/design/ is the canonical source (see its '
              'header comment) -- copy it over the mirror in seller_app/, '
              'do not edit the mirror directly.',
        );
      });
    }
  });
}
