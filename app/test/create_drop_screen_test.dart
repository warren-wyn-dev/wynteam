import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/data/drop_draft.dart';
import 'package:wyn/features/drop/data/location_result.dart';
import 'package:wyn/features/drop/presentation/create_drop_screen.dart';
import 'package:wyn/features/drop/presentation/location_picker_screen.dart';
import 'package:wyn/features/follow/presentation/close_friends_screen.dart';
import 'package:wyn/features/follow/presentation/exclude_friends_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_location_repository.dart';
import 'support/recording_profile_repository.dart';

/// CreateDropScreen, restyled to `04-drop.tsx` (2026-08-29, Founder-
/// approved re-brand -- see .wyn/company/DECISIONS.md): the header's
/// share button is now "โพสต์" (was "แชร์"), "ยกเลิก" is a plain text
/// button (was an Icons.close leading icon), poll mode is toggled from
/// the bottom toolbar's poll icon (Key('toolbar_poll_button'), was a top
/// SegmentedButton with a "โพล" label), and there's no dashed empty-state
/// image box (picking an image is toolbar-only now). Every real behavior
/// this file already covered (poll composition, drafts, restricted
/// accounts, text-only Drops) is unchanged -- only how each test reaches
/// it is updated to match.
void main() {
  late RecordingDropRepository repo;
  late RecordingProfileRepository profileRepo;
  // A fresh instance for the poll-submit test's own call-tracking
  // assertions -- constructed here (setUpAll), not inline inside a
  // testWidgets body, so the SupabaseClient it wraps (and the GoTrue
  // auto-refresh timer that starts with it) isn't attributed to that
  // single test's FakeAsync zone and flagged as a leaked timer at
  // teardown. Every RecordingXRepository across this project's test
  // suite already follows this same "construct outside the test body"
  // discipline for the same reason.
  late RecordingDropRepository pollRepo;
  // WYN-036 -- same one-repo-per-scenario, constructed-in-setUpAll
  // discipline as pollRepo above.
  late RecordingDropRepository saveDraftTestRepo;
  late RecordingDropRepository discardTestRepo;
  late RecordingDropRepository publishFromDraftTestRepo;
  late RecordingDropRepository saveDraftFailTestRepo;
  late RecordingDropRepository switchModeDraftTestRepo;
  // WYNOS V1.0.0 Beta requirement 2 -- same setUpAll discipline as
  // every other repo above.
  late RecordingDropRepository textDropRepo;
  // WYN-094 -- same setUpAll discipline as every other repo above
  // (constructing a RecordingDropRepository inline inside a testWidgets
  // body attributes its real SupabaseClient's GoTrue auto-refresh Timer
  // to that single test's FakeAsync zone, which doesn't just get flagged
  // as a "leaked timer" -- it can hang the test outright, since that
  // Timer is real-wall-clock and not integrated with pumpAndSettle's
  // frame-scheduling wait loop. Learned the hard way while building this
  // group: see .wyn/company/DECISIONS.md, 2026-09-02).
  late RecordingDropRepository progressRepo;
  late RecordingDropRepository progressFailRepo;
  setUpAll(() {
    repo = RecordingDropRepository();
    profileRepo = RecordingProfileRepository();
    pollRepo = RecordingDropRepository();
    saveDraftTestRepo = RecordingDropRepository();
    discardTestRepo = RecordingDropRepository();
    publishFromDraftTestRepo = RecordingDropRepository();
    saveDraftFailTestRepo = RecordingDropRepository()
      ..saveDraftError = Exception('network error');
    switchModeDraftTestRepo = RecordingDropRepository();
    progressRepo = RecordingDropRepository();
    progressFailRepo = RecordingDropRepository()
      ..createDropError = Exception('network error');
    textDropRepo = RecordingDropRepository();
  });

  Finder postButton() => find.byKey(const Key('post_button'));
  Finder cancelButton() => find.byKey(const Key('cancel_button'));
  Finder pollToggle() => find.byKey(const Key('toolbar_poll_button'));

  testWidgets(
      'the "โพสต์" button stays disabled with neither an image nor a '
      'caption, but a caption alone enables it (WYNOS V1.0.0 Beta '
      'requirement 2: image, caption, or both)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
    ));

    final shareButton = postButton();
    expect(shareButton, findsOneWidget);
    expect(tester.widget<TextButton>(shareButton).onPressed, isNull);

    // A caption alone (no image) is now enough to enable it.
    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.pump();

    expect(tester.widget<TextButton>(shareButton).onPressed, isNotNull);
  });

  testWidgets(
      'shows no image UI at all before anything is picked -- attaching a '
      'photo is toolbar-only now, not a tap-anywhere empty-state box',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
    ));

    expect(find.text('แตะเพื่อเลือกรูป (ไม่บังคับ)'), findsNothing);
    expect(find.byKey(const Key('toolbar_photo_button')), findsOneWidget);
    expect(find.byKey(const Key('toolbar_camera_button')), findsOneWidget);
  });

  testWidgets(
      'publishing with a caption and no image calls createTextDrop, not '
      'createDrop (WYNOS V1.0.0 Beta requirement 2)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreateDropScreen(
        dropRepository: textDropRepo,
        profileRepository: profileRepo,
      ),
    ));

    await tester.enterText(find.byType(TextField), 'แคปชันอย่างเดียว ไม่มีรูป');
    await tester.pump();

    await tester.tap(postButton());
    await tester.pumpAndSettle();

    expect(textDropRepo.createTextDropArgs, hasLength(1));
    expect(textDropRepo.createTextDropArgs.single['caption'],
        'แคปชันอย่างเดียว ไม่มีรูป');
    expect(textDropRepo.createDropMentionedUserIdsArgs, isEmpty);
  });

  group('Poll composer (WYN-035)', () {
    testWidgets('tapping the toolbar poll icon hides the image toolbar '
        'and needs no photo', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
      ));

      await tester.tap(pollToggle());
      await tester.pump();

      expect(find.text('ตัวเลือกที่ 1'), findsOneWidget);
      expect(find.text('ตัวเลือกที่ 2'), findsOneWidget);
      // Photo/camera are disabled in poll mode (a Drop carries either an
      // image or a Poll, never both) -- still present, just inert.
      final photoIcon = tester.widget<InkWell>(find.descendant(
        of: find.byKey(const Key('toolbar_photo_button')),
        matching: find.byType(InkWell),
      ));
      expect(photoIcon.onTap, isNull);
    });

    testWidgets('"โพสต์" stays disabled until a question and both options '
        'are filled', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
      ));
      await tester.tap(pollToggle());
      await tester.pump();

      final shareButton = postButton();
      expect(tester.widget<TextButton>(shareButton).onPressed, isNull);

      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 1'), 'Pizza');
      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 2'), 'Sushi');
      await tester.pump();
      // Still no question typed -- must stay disabled.
      expect(tester.widget<TextButton>(shareButton).onPressed, isNull);

      // The caption/question field is the *first* TextField in the tree
      // in poll mode -- the option fields render below it (see
      // CreateDropScreen.build).
      await tester.enterText(find.byType(TextField).first, 'กินอะไรดี?');
      await tester.pump();

      expect(tester.widget<TextButton>(shareButton).onPressed, isNotNull);
    });

    testWidgets('duplicate options (case-insensitive) keep "โพสต์" disabled',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
      ));
      await tester.tap(pollToggle());
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'คำถาม');
      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 1'), 'Yes');
      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 2'), 'yes');
      await tester.pump();

      expect(tester.widget<TextButton>(postButton()).onPressed, isNull);
    });

    testWidgets('เพิ่มตัวเลือก adds up to 4 options, then hides itself',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
      ));
      await tester.tap(pollToggle());
      await tester.pump();

      await tester.tap(find.text('เพิ่มตัวเลือก'));
      await tester.pump();
      await tester.tap(find.text('เพิ่มตัวเลือก'));
      await tester.pump();

      expect(find.text('ตัวเลือกที่ 4'), findsOneWidget);
      expect(find.text('เพิ่มตัวเลือก'), findsNothing);
    });

    testWidgets('removing a 3rd option removes its field; the first 2 '
        'have no remove button', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
      ));
      await tester.tap(pollToggle());
      await tester.pump();

      // The header no longer has an Icons.close leading button (it's a
      // plain "ยกเลิก" text button now) -- baseline with 2 options
      // (neither removable) is 0.
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.tap(find.text('เพิ่มตัวเลือก'));
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('remove_poll_option_2')));
      await tester.pump();

      expect(find.text('ตัวเลือกที่ 3'), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('sharing a valid poll calls createPollDrop with the '
        'question, options, and selected duration', (tester) async {
      // CreateDropScreen pops on success -- needs a real route to pop
      // back to, same fix as QuoteRedropScreenTest's buildScreen/openScreen.
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateDropScreen(
                      dropRepository: pollRepo,
                      profileRepository: profileRepo,
                    ),
                  ),
                ),
                child: const Text('เปิด'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('เปิด'));
      await tester.pumpAndSettle();

      await tester.tap(pollToggle());
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 1'), 'Pizza');
      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 2'), 'Sushi');
      await tester.enterText(find.byType(TextField).first, 'กินอะไรดี?');
      await tester.tap(find.text('3 วัน'));
      await tester.pump();

      await tester.tap(postButton());
      await tester.pumpAndSettle();

      expect(pollRepo.createPollDropArgs, hasLength(1));
      final args = pollRepo.createPollDropArgs.single;
      expect(args['question'], 'กินอะไรดี?');
      expect(args['options'], ['Pizza', 'Sushi']);
      expect(args['durationDays'], 3);
      expect(find.byType(CreateDropScreen), findsNothing);
    });
  });

  group('Draft (WYN-036)', () {
    // CreateDropScreen's close-intercept dialog pops via a direct
    // Navigator.pop() call, which needs a real route to pop back to --
    // same fix as QuoteRedropScreenTest's buildScreen/openScreen and
    // the poll-submit test above.
    Widget buildScreen(RecordingDropRepository dropRepository, {DropDraft? draft}) =>
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateDropScreen(
                        dropRepository: dropRepository,
                        profileRepository: profileRepo,
                        draft: draft,
                      ),
                    ),
                  ),
                  child: const Text('เปิด'),
                ),
              ),
            ),
          ),
        );

    Future<void> openScreen(WidgetTester tester, RecordingDropRepository dropRepository,
        {DropDraft? draft}) async {
      await tester.pumpWidget(buildScreen(dropRepository, draft: draft));
      await tester.tap(find.text('เปิด'));
      await tester.pumpAndSettle();
    }

    testWidgets('closing with no content at all pops immediately, no dialog',
        (tester) async {
      await openScreen(tester, repo);

      await tester.tap(cancelButton());
      await tester.pumpAndSettle();

      expect(find.text('บันทึกเป็นร่างก่อนออกไหม?'), findsNothing);
      expect(find.byType(CreateDropScreen), findsNothing);
    });

    testWidgets('closing with unsaved content (a typed caption) shows the '
        'close-intercept dialog', (tester) async {
      await openScreen(tester, repo);

      await tester.enterText(find.byType(TextField), 'ยังไม่เสร็จ');
      await tester.pump();
      await tester.tap(cancelButton());
      await tester.pumpAndSettle();

      expect(find.text('บันทึกเป็นร่างก่อนออกไหม?'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'ทิ้ง'), findsOneWidget);
      // 2 now: the header's own "ยกเลิก" button underneath, plus the
      // dialog's -- both coexist since the dialog is an overlay, not a
      // replacement.
      expect(find.widgetWithText(TextButton, 'ยกเลิก'), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'บันทึกร่าง'), findsOneWidget);
    });

    testWidgets('"ยกเลิก" (in the dialog) closes the dialog and stays on '
        'the screen', (tester) async {
      await openScreen(tester, repo);

      await tester.enterText(find.byType(TextField), 'ยังไม่เสร็จ');
      await tester.pump();
      await tester.tap(cancelButton());
      await tester.pumpAndSettle();

      // 2 "ยกเลิก" texts now exist on screen (the header button behind
      // the dialog, and the dialog's own button) -- the dialog's is the
      // last one on top.
      await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก').last);
      await tester.pumpAndSettle();

      expect(find.text('บันทึกเป็นร่างก่อนออกไหม?'), findsNothing);
      expect(find.byType(CreateDropScreen), findsOneWidget);
      expect(find.text('ยังไม่เสร็จ'), findsOneWidget);
    });

    testWidgets('"ทิ้ง" closes without calling saveDraft', (tester) async {
      await openScreen(tester, discardTestRepo);

      await tester.enterText(find.byType(TextField), 'ยังไม่เสร็จ');
      await tester.pump();
      await tester.tap(cancelButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'ทิ้ง'));
      await tester.pumpAndSettle();

      expect(discardTestRepo.saveDraftArgs, isEmpty);
      expect(find.byType(CreateDropScreen), findsNothing);
    });

    testWidgets('"บันทึกร่าง" calls saveDraft with the current content and '
        'closes', (tester) async {
      await openScreen(tester, saveDraftTestRepo);

      await tester.enterText(find.byType(TextField), 'เดี๋ยวมาเขียนต่อ');
      await tester.pump();
      await tester.tap(cancelButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'บันทึกร่าง'));
      await tester.pumpAndSettle();

      expect(saveDraftTestRepo.saveDraftArgs, hasLength(1));
      final args = saveDraftTestRepo.saveDraftArgs.single;
      expect(args['draftId'], isNull);
      expect(args['caption'], 'เดี๋ยวมาเขียนต่อ');
      expect(find.byType(CreateDropScreen), findsNothing);
    });

    testWidgets('a failed saveDraft shows a snackbar and stays on screen',
        (tester) async {
      await openScreen(tester, saveDraftFailTestRepo);

      await tester.enterText(find.byType(TextField), 'เดี๋ยวมาเขียนต่อ');
      await tester.pump();
      await tester.tap(cancelButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'บันทึกร่าง'));
      await tester.pumpAndSettle();

      expect(find.text('บันทึกร่างไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
      expect(find.byType(CreateDropScreen), findsOneWidget);
    });

    testWidgets('opening with an image-mode draft prefills the existing '
        'image and caption', (tester) async {
      final draft = DropDraft(
        id: 'draft-1',
        imageUrl: 'https://example.com/draft.jpg',
        caption: 'ยังคิดแคปชันไม่ออก',
        updatedAt: DateTime(2026, 1, 1),
      );
      await openScreen(tester, repo, draft: draft);
      // NetworkImageLoadException -- same expected noise as elsewhere in
      // this suite (there's no real network in tests).
      tester.takeException();

      expect(find.text('ยังคิดแคปชันไม่ออก'), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as NetworkImage).url, 'https://example.com/draft.jpg');
      // The "โพสต์" button is enabled immediately -- the carried-over
      // image counts as picked, no need to re-pick it.
      expect(tester.widget<TextButton>(postButton()).onPressed, isNotNull);
    });

    testWidgets('opening with a poll-mode draft prefills poll mode, '
        'options, duration, and the question', (tester) async {
      final draft = DropDraft(
        id: 'draft-2',
        caption: 'กินอะไรดี?',
        pollOptions: const ['Pizza', 'Sushi', 'Burger'],
        pollDurationDays: 7,
        updatedAt: DateTime(2026, 1, 1),
      );
      await openScreen(tester, repo, draft: draft);

      expect(find.text('กินอะไรดี?'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Pizza'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Sushi'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Burger'), findsOneWidget);
      // "7 วัน" segment selected -- SegmentedButton renders every
      // segment's label as plain Text regardless of selection, so
      // this only proves the segment exists, not that it's selected;
      // the real proof is createPollDrop's durationDays argument,
      // covered by the publish test below.
      expect(find.text('7 วัน'), findsOneWidget);
    });

    testWidgets('an incomplete poll draft (1 filled option) leaves "โพสต์" '
        'disabled -- prefill does not skip validation', (tester) async {
      final draft = DropDraft(
        id: 'draft-3',
        caption: 'คำถาม',
        pollOptions: const ['Pizza', ''],
        updatedAt: DateTime(2026, 1, 1),
      );
      await openScreen(tester, repo, draft: draft);

      expect(tester.widget<TextButton>(postButton()).onPressed, isNull);
    });

    testWidgets('publishing from an opened draft creates the Drop and '
        'deletes the draft', (tester) async {
      final draft = DropDraft(
        id: 'draft-4',
        imageUrl: 'https://example.com/draft.jpg',
        caption: 'พร้อมแชร์แล้ว',
        updatedAt: DateTime(2026, 1, 1),
      );
      await openScreen(tester, publishFromDraftTestRepo, draft: draft);
      // NetworkImageLoadException -- same expected noise as above.
      tester.takeException();

      await tester.tap(postButton());
      await tester.pumpAndSettle();

      expect(publishFromDraftTestRepo.createDropFromExistingImageArgs, hasLength(1));
      expect(
        publishFromDraftTestRepo.createDropFromExistingImageArgs.single['imageUrl'],
        'https://example.com/draft.jpg',
      );
      expect(publishFromDraftTestRepo.deleteDraftCalls, ['draft-4']);
      expect(find.byType(CreateDropScreen), findsNothing);
    });

    testWidgets(
        'switching an image-mode draft to โพล mode before saving as a '
        'draft again does not leak the leftover image into the poll '
        'draft', (tester) async {
      final draft = DropDraft(
        id: 'draft-5',
        imageUrl: 'https://example.com/draft.jpg',
        updatedAt: DateTime(2026, 1, 1),
      );
      await openScreen(tester, switchModeDraftTestRepo, draft: draft);
      // NetworkImageLoadException -- same expected noise as above.
      tester.takeException();

      // The toolbar's poll toggle never clears _existingImageUrl/
      // _imageBytes on mode switch -- saveDraft must gate them by
      // _mode itself.
      await tester.tap(pollToggle());
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 1'), 'Pizza');
      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 2'), 'Sushi');
      await tester.enterText(find.byType(TextField).first, 'กินอะไรดี?');

      await tester.tap(cancelButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'บันทึกร่าง'));
      await tester.pumpAndSettle();

      final args = switchModeDraftTestRepo.saveDraftArgs.single;
      expect(args['imageBytes'], isNull);
      expect(args['existingImageUrl'], isNull);
      expect(args['pollOptions'], ['Pizza', 'Sushi']);
    });
  });

  group('Upload progress (WYN-094)', () {
    // image_picker's default MethodChannelImagePicker instance hangs
    // when exercised under AutomatedTestWidgetsFlutterBinding in this
    // sandbox (reproduced in complete isolation -- an ImagePickerPlatform
    // fake + a bare testWidgets pump alone hangs; the identical call
    // sequence in a plain test() returns instantly). There is no working
    // way to widget-test the real tap-toolbar-button-to-pick-an-image
    // flow here, so these tests go through CreateDropScreen's
    // debugInitialImagesBytes test-only seam instead of a real pick --
    // everything downstream of "_imagesBytes is populated" (the actual
    // WYN-094 behavior: the progress bar, its percentage math, and its
    // visibility rules) is exercised for real.
    //
    // The seeded bytes are deliberately NOT a real decodable image:
    // decoding a genuinely valid image through the widget tree's
    // Image.memory (PaintingBinding.instantiateImageCodecWithSize) hangs
    // the same way in this sandbox, while invalid bytes fail fast with a
    // caught "Invalid image data" exception -- same "harmless expected
    // exception in a test env" shape as this suite's existing
    // NetworkImageLoadException/tester.takeException() pattern (see the
    // Draft group above), swallowed the same way.
    Widget buildWithImages(
      RecordingDropRepository dropRepository,
      int imageCount,
    ) =>
        MaterialApp(
          home: CreateDropScreen(
            dropRepository: dropRepository,
            profileRepository: profileRepo,
            debugInitialImagesBytes: List.generate(
              imageCount,
              (i) => Uint8List.fromList([1, 2, 3]),
            ),
          ),
        );

    testWidgets(
        'posting with images shows a progress bar that advances as each '
        'image actually finishes uploading, then disappears on success',
        (tester) async {
      final gate = [Completer<void>(), Completer<void>()];
      progressRepo.imageUploadGate = gate;

      await tester.pumpWidget(buildWithImages(progressRepo, 2));
      // Invalid-image-data decode failure -- see group comment above.
      tester.takeException();

      expect(find.text('2/9'), findsOneWidget);
      // No progress bar yet -- _isSharing is still false before "โพสต์"
      // is tapped.
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await tester.tap(postButton());
      await tester.pump();

      // 1st image not finished yet -- 0/2.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('0/2'), findsOneWidget);
      expect(find.textContaining('0%'), findsOneWidget);

      gate[0].complete();
      await tester.pump();
      await tester.pump();

      // 1st image done, 2nd still in flight -- 1/2, 50%.
      expect(find.textContaining('1/2'), findsOneWidget);
      expect(find.textContaining('50%'), findsOneWidget);

      gate[1].complete();
      await tester.pumpAndSettle();

      // Both done -- createDrop resolves, the screen pops (success),
      // so the progress bar is gone along with the rest of the form.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(progressRepo.createDropImageCountArgs, [2]);
    });

    testWidgets(
        'posting a caption-only Drop (no images) never shows a progress '
        'bar -- publishing without images is fast enough that a real bar '
        "wouldn't reflect anything meaningful", (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CreateDropScreen(
          dropRepository: textDropRepo,
          profileRepository: profileRepo,
        ),
      ));

      await tester.enterText(
          find.byType(TextField), 'แคปชันอย่างเดียว ไม่มีรูป (WYN-094)');
      await tester.pump();

      await tester.tap(postButton());
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets(
        'a failed upload hides the progress bar and re-enables the "โพสต์" '
        'button instead of leaving it stuck at a stale percentage',
        (tester) async {
      await tester.pumpWidget(buildWithImages(progressFailRepo, 1));
      // Invalid-image-data decode failure -- see group comment above.
      tester.takeException();

      await tester.tap(postButton());
      await tester.pumpAndSettle();
      // A 2nd occurrence can surface here too depending on frame timing.
      tester.takeException();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
      expect(tester.widget<TextButton>(postButton()).onPressed, isNotNull);
    });
  });

  // WYN-097 -- Audience Selector.
  group('Audience Selector (WYN-097)', () {
    late RecordingDropRepository audienceRepo;
    late RecordingFollowRepository followRepo;

    setUp(() {
      audienceRepo = RecordingDropRepository();
      followRepo = RecordingFollowRepository();
    });

    Widget buildScreen() => MaterialApp(
          home: CreateDropScreen(
            dropRepository: audienceRepo,
            profileRepository: profileRepo,
            followRepository: followRepo,
          ),
        );

    testWidgets('defaults to "ทุกคน" and posting without touching it '
        'passes AudienceOption.everyone', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.text('ทุกคน'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(postButton());
      await tester.pumpAndSettle();

      expect(audienceRepo.createTextDropArgs.single['audience'],
          AudienceOption.everyone);
    });

    testWidgets('tapping the chip opens a sheet with all 5 options',
        (tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.tap(find.text('ทุกคน'));
      await tester.pumpAndSettle();

      expect(find.text('ใครเห็นโพสต์นี้ได้บ้าง'), findsOneWidget);
      expect(find.text('ทุกคนเห็นโพสต์นี้ได้'), findsOneWidget);
      expect(find.text('เพื่อน'), findsOneWidget);
      expect(find.text('ซ่อนเพื่อนบางคน'), findsOneWidget);
      expect(find.text('เพื่อนที่สนิท'), findsOneWidget);
      expect(find.text('เฉพาะฉัน'), findsOneWidget);
    });

    testWidgets('selecting "เพื่อน" applies immediately, updates the chip, '
        'and is passed to createTextDrop', (tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.tap(find.text('ทุกคน'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เพื่อน'));
      await tester.pumpAndSettle();

      expect(find.text('เพื่อน'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(postButton());
      await tester.pumpAndSettle();

      expect(audienceRepo.createTextDropArgs.single['audience'],
          AudienceOption.friends);
    });

    testWidgets('selecting "เฉพาะฉัน" applies immediately and updates the '
        'chip', (tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.tap(find.text('ทุกคน'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เฉพาะฉัน'));
      await tester.pumpAndSettle();

      expect(find.text('เฉพาะฉัน'), findsOneWidget);
    });

    testWidgets(
        'selecting "ซ่อนเพื่อนบางคน" opens ExcludeFriendsScreen; picking '
        'friends there sets the chip and is passed through on post',
        (tester) async {
      followRepo.mutualFollows = [
        const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
      ];

      await tester.pumpWidget(buildScreen());

      await tester.tap(find.text('ทุกคน'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ซ่อนเพื่อนบางคน'));
      await tester.pumpAndSettle();

      expect(find.byType(ExcludeFriendsScreen), findsOneWidget);

      await tester.tap(find.text('@namfah'));
      await tester.pump();
      await tester.tap(find.text('เสร็จสิ้น (1)'));
      await tester.pumpAndSettle();

      expect(find.text('ซ่อนเพื่อนบางคน'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(postButton());
      await tester.pumpAndSettle();

      final args = audienceRepo.createTextDropArgs.single;
      expect(args['audience'], AudienceOption.friendsExcept);
    });

    testWidgets(
        'selecting "เพื่อนที่สนิท" with an empty list routes through '
        'CloseFriendsScreen\'s welcome banner first, then selects it',
        (tester) async {
      // At least one mutual follow, so CloseFriendsScreen renders its
      // welcome banner + list instead of the (higher-priority) "no
      // friends at all" empty state -- this test is specifically about
      // the empty *close-friends* list, not an empty mutual-follow list.
      followRepo.mutualFollows = [
        const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
      ];

      await tester.pumpWidget(buildScreen());

      await tester.tap(find.text('ทุกคน'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เพื่อนที่สนิท'));
      await tester.pumpAndSettle();

      expect(find.byType(CloseFriendsScreen), findsOneWidget);
      expect(
        find.text('คุณยังไม่มีเพื่อนที่สนิท เลือกจากรายชื่อเพื่อนของคุณได้เลย'),
        findsOneWidget,
      );

      // Back out of CloseFriendsScreen -- selecting it doesn't require
      // adding anyone right there, per Design spec.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text('เพื่อนที่สนิท'), findsOneWidget);
      expect(find.byType(CreateDropScreen), findsOneWidget);
    });

    testWidgets(
        'selecting "เพื่อนที่สนิท" with an existing (non-empty) list '
        'selects immediately, without opening CloseFriendsScreen',
        (tester) async {
      followRepo.closeFriends = [const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah')];

      await tester.pumpWidget(buildScreen());

      await tester.tap(find.text('ทุกคน'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เพื่อนที่สนิท'));
      await tester.pumpAndSettle();

      expect(find.byType(CloseFriendsScreen), findsNothing);
      expect(find.text('เพื่อนที่สนิท'), findsOneWidget);
    });
  });

  // WYN-098 -- Location Check-in.
  group('Location Check-in (WYN-098)', () {
    late RecordingDropRepository locationTestRepo;
    late RecordingLocationRepository locationRepo;

    setUp(() {
      locationTestRepo = RecordingDropRepository();
      locationRepo = RecordingLocationRepository();
    });

    Widget buildScreen() => MaterialApp(
          home: CreateDropScreen(
            dropRepository: locationTestRepo,
            profileRepository: profileRepo,
            locationRepository: locationRepo,
          ),
        );

    testWidgets('tapping the location toolbar icon opens '
        'LocationPickerScreen', (tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.tap(find.byKey(const Key('toolbar_location_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LocationPickerScreen), findsOneWidget);
    });

    testWidgets(
        'picking a place shows a chip on the composer and passes it to '
        'createTextDrop on post', (tester) async {
      locationRepo.searchResultsByQuery = {
        'starbucks': [
          const LocationResult(
            name: 'Starbucks',
            address: 'สยามพารากอน',
            lat: 13.7466,
            lon: 100.5347,
            placeId: '1',
          ),
        ],
      };

      await tester.pumpWidget(buildScreen());
      await tester.tap(find.byKey(const Key('toolbar_location_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'starbucks');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Starbucks'));
      await tester.pumpAndSettle();

      // Back on CreateDropScreen -- the chip shows the place name.
      expect(find.byType(CreateDropScreen), findsOneWidget);
      expect(find.text('Starbucks'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byKey(const Key('post_button')));
      await tester.pumpAndSettle();

      final args = locationTestRepo.createTextDropArgs.single;
      final location = args['location'] as LocationResult?;
      expect(location?.name, 'Starbucks');
      expect(location?.placeId, '1');
    });

    testWidgets('tapping X on the location chip removes it', (tester) async {
      locationRepo.searchResultsByQuery = {
        'starbucks': [
          const LocationResult(
            name: 'Starbucks',
            address: null,
            lat: 13.7466,
            lon: 100.5347,
            placeId: '1',
          ),
        ],
      };

      await tester.pumpWidget(buildScreen());
      await tester.tap(find.byKey(const Key('toolbar_location_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'starbucks');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Starbucks'));
      await tester.pumpAndSettle();
      expect(find.text('Starbucks'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      expect(find.text('Starbucks'), findsNothing);
    });

    testWidgets('posting without picking a location passes a null '
        'location', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byKey(const Key('post_button')));
      await tester.pumpAndSettle();

      expect(locationTestRepo.createTextDropArgs.single['location'], isNull);
    });
  });
}
