import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The WYNOS Interaction Feedback System, as a check rather than a
/// paragraph -- same posture (and same reasoning) as
/// `design_system_guard_test.dart`.
///
/// That file exists because "don't re-inline the token" was written down
/// once, in a doc, and then ten widgets did it anyway and two of them
/// drifted. The interaction system has exactly the same failure mode: a
/// new feature reaches for `HapticFeedback.mediumImpact()` because it
/// buzzes a bit harder, and now Like means one thing on the feed and
/// another on the profile, with nowhere left to put a device check or a
/// repeat guard.
///
/// Deliberately narrow. It bans one import outside one directory. It
/// does not police which WynFeedback method a feature picks -- that is a
/// design judgement, and this file is not the place to argue it.
void main() {
  final libDir = Directory('lib');

  /// The one directory allowed to talk to the platform's haptics.
  bool isInteractionSystem(String path) =>
      path.replaceAll(r'\', '/').contains('lib/core/interaction/');

  test('HapticFeedback is only ever called from lib/core/interaction/', () {
    final offenders = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (isInteractionSystem(entity.path)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Comments talk *about* these calls (this system's own files
        // explain what they map to); they are not uses of them.
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('//')) continue;
        if (lines[i].contains(RegExp(r'\bHapticFeedback\.'))) {
          offenders.add('  ${entity.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Call WynFeedback (lib/core/interaction/wyn_feedback.dart) '
          'instead -- it is what carries the device check, the '
          'repeat-suppression and the light/medium/selection rules.\n'
          'Found:\n${offenders.join('\n')}',
    );
  });
}
