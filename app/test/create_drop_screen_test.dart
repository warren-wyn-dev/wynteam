import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:wyn/features/drop/data/drop_repository.dart';
import 'package:wyn/features/drop/presentation/create_drop_screen.dart';

import 'support/fake_image_picker_platform.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_profile_repository.dart';

/// Encodes a solid-color 40x40 square as PNG bytes -- a synthetic "photo"
/// that ImagePicker's fake platform hands back, so _pickImage()'s real
/// centerCropToSquare() path runs against something ui.instantiateImageCodec
/// can actually decode. Mirrors square_crop_test.dart's _rectanglePng.
Future<Uint8List> _fakePickedImagePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 40, 40),
    ui.Paint()..color = const ui.Color(0xFF2D6CDF),
  );
  final image = await recorder.endRecording().toImage(40, 40);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// A createDrop() that never resolves -- used to hold _isSharing at true
/// for the duration of a test, the same way a real in-flight upload would.
class _HangingCreateDropRepository extends RecordingDropRepository {
  @override
  Future<void> createDrop({
    required Uint8List imageBytes,
    required String imageExtension,
    required String caption,
    Set<String> mentionedUserIds = const {},
  }) {
    createDropCalls++;
    createDropImageExtensionArgs.add(imageExtension);
    return Completer<void>().future;
  }
}

/// _pickImage()'s real centerCropToSquare() path does several rounds of
/// genuine dart:ui native work (instantiateImageCodec -> Canvas render ->
/// toImage -> toByteData) chained together. A single pumpAndSettle()/pump()
/// after the picker tap never resolves it in this test environment -- each
/// native completion only gets flushed back into the widget tree during a
/// *real*-time window (tester.runAsync()), and the chain has more than one
/// such native step, so one window isn't enough either. Looping bounded
/// runAsync()+pump() rounds until the share button lights up (proof the
/// crop finished and _imageBytes is set) reproduces what pumpAndSettle()
/// normally does for fake-clock-only work, but for this real-native chain.
/// See .wyn/learning/PATTERNS.md.
Future<void> _pumpUntilImagePicked(WidgetTester tester) async {
  final shareButton = find.widgetWithText(TextButton, 'แชร์');
  for (var round = 0; round < 10; round++) {
    if (tester.widget<TextButton>(shareButton).onPressed != null) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }
  fail('centerCropToSquare() did not finish within the round budget -- '
      'see _pumpUntilImagePicked doc comment.');
}

void main() {
  late RecordingDropRepository repo;
  late RecordingProfileRepository profileRepo;
  setUpAll(() {
    repo = RecordingDropRepository();
    profileRepo = RecordingProfileRepository();
  });

  testWidgets(
      'the "แชร์" button stays disabled until an image is picked '
      '(a Drop always needs a photo, unlike WYN-004 posts)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
    ));

    final shareButton = find.widgetWithText(TextButton, 'แชร์');
    expect(shareButton, findsOneWidget);
    expect(tester.widget<TextButton>(shareButton).onPressed, isNull);

    // Typing a caption alone must not enable it either -- an image is
    // mandatory, not just one of two options like WYN-004's text/image.
    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.pump();

    expect(tester.widget<TextButton>(shareButton).onPressed, isNull);
  });

  testWidgets('shows a placeholder prompt before any image is picked',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
    ));

    expect(find.text('แตะเพื่อเลือกรูป'), findsOneWidget);
  });

  group('WYN-025 R2: confirm-discard on exit', () {
    late RecordingDropRepository exitRepo;
    late RecordingProfileRepository exitProfileRepo;
    setUp(() {
      exitRepo = RecordingDropRepository();
      exitProfileRepo = RecordingProfileRepository();
    });

    // Pushes CreateDropScreen from an "open" button on a first route, so
    // there's an actual route underneath to observe a real pop landing on
    // (mirrors zoky_checkout_summary_screen_test.dart's "pops back to the
    // first route" setup) -- pumping CreateDropScreen directly as `home:`
    // would leave nothing to pop back to.
    Future<void> pumpComposer(
      WidgetTester tester, {
      GlobalKey<NavigatorState>? navigatorKey,
      DropRepository? repository,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateDropScreen(
                        dropRepository: repository ?? exitRepo,
                        profileRepository: exitProfileRepo,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('leaving with no typed content closes immediately, no dialog',
        (tester) async {
      await pumpComposer(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(CreateDropScreen), findsNothing);
      expect(find.text('ทิ้งการเปลี่ยนแปลง?'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets(
        'tapping close with a typed caption shows the discard dialog; '
        'ยกเลิก keeps the caption and stays on the composer', (tester) async {
      await pumpComposer(tester);

      await tester.enterText(find.byType(TextField), 'สวัสดีชาว WYN');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('ทิ้งการเปลี่ยนแปลง?'), findsOneWidget);

      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateDropScreen), findsOneWidget);
      expect(find.text('สวัสดีชาว WYN'), findsOneWidget);
    });

    testWidgets('tapping ทิ้ง in the discard dialog closes the composer',
        (tester) async {
      await pumpComposer(tester);

      await tester.enterText(find.byType(TextField), 'สวัสดีชาว WYN');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ทิ้ง'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateDropScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets(
        'system back (PopScope) with unsaved content shows the same '
        'discard dialog as the close button', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await pumpComposer(tester, navigatorKey: navigatorKey);

      await tester.enterText(find.byType(TextField), 'สวัสดีชาว WYN');
      await tester.pump();

      navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('ทิ้งการเปลี่ยนแปลง?'), findsOneWidget);

      await tester.tap(find.text('ทิ้ง'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateDropScreen), findsNothing);
    });

    group('image-picking tests', () {
      // Each RecordingDropRepository wraps a real throwaway SupabaseClient
      // whose GoTrue client starts a Timer.periodic -- built here (not
      // inline in testWidgets) so it leaks outside this group's own
      // fake-async zone instead of tripping "A Timer is still pending"
      // at test teardown. Mirrors drop_feed_screen_test.dart's "For You
      // ranking" group / search_screen_test.dart. See
      // .wyn/learning/PATTERNS.md. This group's own setUp() shadows the
      // outer group's exitRepo/exitProfileRepo because these two tests
      // each need a repository with different behaviour (a hanging
      // createDrop(), or one to assert call counts on) than the shared
      // default.
      late _HangingCreateDropRepository hangingRepo;
      late RecordingDropRepository publishRepo;
      setUp(() {
        hangingRepo = _HangingCreateDropRepository();
        publishRepo = RecordingDropRepository();
      });

      testWidgets(
          'while sharing, the close button is disabled and system back is '
          'blocked silently instead of showing the dialog', (tester) async {
        ImagePickerPlatform.instance = FakeImagePickerPlatform(
          await tester.runAsync(_fakePickedImagePng) as Uint8List,
        );
        final navigatorKey = GlobalKey<NavigatorState>();
        await pumpComposer(
          tester,
          navigatorKey: navigatorKey,
          repository: hangingRepo,
        );

        await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.text('เลือกจากคลังภาพ'));
        await tester.pump();
        await _pumpUntilImagePicked(tester);

        await tester.tap(find.widgetWithText(TextButton, 'แชร์'));
        await tester.pump();

        // createDrop() above never resolves, so _isSharing stays true.
        final closeButton = tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close));
        expect(closeButton.onPressed, isNull);

        navigatorKey.currentState!.maybePop();
        await tester.pump();
        await tester.pump();

        expect(find.text('ทิ้งการเปลี่ยนแปลง?'), findsNothing);
        expect(find.byType(CreateDropScreen), findsOneWidget);
      });

      testWidgets(
          'a successful publish closes the composer without hitting the '
          'discard dialog, and sends the cropped image as JPEG (WYN-025 R1)',
          (tester) async {
        ImagePickerPlatform.instance = FakeImagePickerPlatform(
          await tester.runAsync(_fakePickedImagePng) as Uint8List,
        );
        await pumpComposer(tester, repository: publishRepo);

        await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.text('เลือกจากคลังภาพ'));
        await tester.pump();
        await _pumpUntilImagePicked(tester);

        await tester.enterText(find.byType(TextField), 'แคปชันของฉัน');
        await tester.pump();

        await tester.tap(find.widgetWithText(TextButton, 'แชร์'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateDropScreen), findsNothing);
        expect(find.text('ทิ้งการเปลี่ยนแปลง?'), findsNothing);
        expect(publishRepo.createDropCalls, 1);
        expect(publishRepo.createDropImageExtensionArgs, ['jpg']);
      });
    });
  });
}
