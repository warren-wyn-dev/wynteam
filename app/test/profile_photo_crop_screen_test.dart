import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/profile/presentation/profile_photo_crop_screen.dart';

/// WYN-104. Uses `debugInitialDimensions` + deliberately-undecodable
/// bytes throughout -- decoding a genuinely valid image *through the
/// widget tree* (`Image.memory`) hangs in this sandbox (reproduced and
/// documented for WYN-094, .wyn/company/DECISIONS.md 2026-09-02, "พบ
/// ข้อจำกัดใหม่ของ sandbox"), while invalid bytes fail fast with a
/// caught decode exception -- same `tester.takeException()` pattern
/// already used throughout create_drop_screen_test.dart's "Upload
/// progress (WYN-094)" group. This suite proves the screen's own gesture/
/// button/state wiring (zoom clamping, cancel/done navigation, error
/// handling on a crop failure); the actual pan/zoom -> crop-rectangle ->
/// cropped-pixels math is proven separately with real decoded images in
/// profile_photo_crop_test.dart's plain `test()`s (no widget tree
/// involved there, so no hang risk).
void main() {
  Widget buildScreen({(int, int)? dimensions}) => MaterialApp(
        home: ProfilePhotoCropScreen(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          debugInitialDimensions: dimensions ?? (400, 200),
        ),
      );

  testWidgets('shows the AppBar (ยกเลิก/title/เสร็จสิ้น) and the zoom bar',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    tester.takeException(); // invalid-bytes decode failure, see file doc.

    expect(find.text('ยกเลิก'), findsOneWidget);
    expect(find.text('ปรับตำแหน่งรูป'), findsOneWidget);
    expect(find.text('เสร็จสิ้น'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('tapping ยกเลิก pops with null (avatar stays unchanged)',
      (tester) async {
    Uint8List? popped;
    var hasPopped = false;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<Uint8List>(
                  MaterialPageRoute(
                    builder: (_) => ProfilePhotoCropScreen(
                      imageBytes: Uint8List.fromList([1, 2, 3]),
                      debugInitialDimensions: (400, 200),
                    ),
                  ),
                );
                hasPopped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(hasPopped, isTrue);
    expect(popped, isNull);
  });

  testWidgets(
      'the + button increases zoom (slider value) up to the max, the - '
      'button decreases it back down to the min -- both clamp',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    tester.takeException();

    double sliderValue() => tester.widget<Slider>(find.byType(Slider)).value;
    expect(sliderValue(), 1.0);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(sliderValue(), closeTo(1.25, 0.001));

    // Tap well past the max (3.0) -- must clamp, never overshoot.
    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
    }
    expect(sliderValue(), 3.0);

    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
    }
    expect(sliderValue(), 1.0);
  });

  testWidgets('dragging the slider directly sets the zoom level',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    tester.takeException();

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(2.5);
    await tester.pump();

    expect(tester.widget<Slider>(find.byType(Slider)).value, 2.5);
  });

  testWidgets(
      'a crop failure (e.g. corrupt/undecodable image bytes) shows an '
      'error message instead of crashing or popping', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('เสร็จสิ้น'));
    await tester.pump(); // enters the processing state
    await tester.pumpAndSettle();
    tester.takeException(); // the crop's own decode-failure, caught internally

    expect(find.text('ครอปรูปไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    // Still on this screen -- did not pop despite the failure.
    expect(find.byType(ProfilePhotoCropScreen), findsOneWidget);
  });

  testWidgets(
      'shows a loading spinner first, then a load-failure message '
      'instead of a crash or an infinite spinner, when the image fails '
      'to decode', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProfilePhotoCropScreen(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        // No debugInitialDimensions -- exercises the real
        // decodeImageDimensions() path with intentionally-invalid bytes,
        // which fails fast (not a hang -- see file doc comment).
      ),
    ));

    // Before the (fast-failing) decode settles -- the loading state (the
    // zoom bar's Slider is always mounted, just disabled until ready --
    // see the "shows the AppBar..." test above for its enabled state).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('เปิดรูปไม่สำเร็จ ลองเลือกรูปใหม่อีกครั้ง'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
