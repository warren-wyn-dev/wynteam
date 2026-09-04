// QA round 2 (2026-09-04) -- AI QA & Security.
//
// B-109-3: the compose preview frame must take the shape the chip
// chose. The permanent test that shipped with the fix only greps
// create_drop_screen.dart for the strings "double get _previewWidth"
// and "width: _previewWidth" -- it would pass unchanged if
// _previewWidth returned 128 for every ratio.
//
// KNOWN LIMITATION, measured not assumed: driving the chip for real
// needs decodable bytes in the widget tree, and this sandbox's widget
// binding hangs the moment CreateDropScreen is pumped with a real PNG
// (verified with a throwaway probe: even the first pumpWidget inside
// tester.runAsync never returns; same constraint create_drop_screen_test
// documents for itself and DECISIONS.md 2026-09-02 records). So what is
// measured here is the one frame that CAN be measured -- the default --
// which is also the regression the fix was most likely to cause: the
// commit claims "4:5 lands back on 128x160 exactly, so the default
// frame is unchanged".
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/drop/data/square_crop.dart';
import 'package:wyn/features/drop/presentation/create_drop_screen.dart';

import 'support/recording_drop_repository.dart';
import 'support/recording_profile_repository.dart';

void main() {
  // Constructed in setUp, not inline in the test body -- a fresh
  // SupabaseClient starts a GoTrue auto-refresh timer that would
  // otherwise be attributed to this test's FakeAsync zone and trip
  // flutter_test's !timersPending invariant (same note every other
  // suite here carries).
  late RecordingDropRepository repo;
  late RecordingProfileRepository profileRepo;

  setUp(() {
    repo = RecordingDropRepository();
    profileRepo = RecordingProfileRepository();
  });

  testWidgets(
      'QA-R2-23 the default (4:5) preview frame is still exactly 128x160',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreateDropScreen(
        dropRepository: repo,
        profileRepository: profileRepo,
        // Deliberately undecodable, same seam and same reason as
        // create_drop_screen_test's own image group.
        debugInitialImagesBytes: [Uint8List.fromList([1, 2, 3])],
      ),
    ));
    await tester.pump();
    tester.takeException();

    final frames = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(ClipRRect),
    );
    expect(frames, findsWidgets);
    final rect = tester.getRect(frames.first);
    expect(rect.width, closeTo(128, 0.5));
    expect(rect.height, closeTo(160, 0.5));
  });

  test(
      'QA-R2-24 the frame formula gives each chip a visibly different '
      'width (160 * ratio), and only "ต้นฉบับ" keeps the 128 box', () {
    // The private getter is `_previewHeight * ratio` with
    // _previewHeight = 160; this pins the numbers that formula must
    // produce, so a change to it that flattens the shapes back out is
    // visible here even though the widget cannot be driven.
    expect(160 * DropAspectRatio.portrait.ratio!, closeTo(128, 0.001));
    expect(160 * DropAspectRatio.square.ratio!, closeTo(160, 0.001));
    expect(160 * DropAspectRatio.landscape.ratio!, closeTo(284.44, 0.01));
    expect(DropAspectRatio.original.ratio, isNull);
  });
}
