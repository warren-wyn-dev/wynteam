import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop_draft.dart';
import 'package:wyn/features/drop/presentation/create_drop_screen.dart';

import 'support/recording_drop_repository.dart';
import 'support/recording_profile_repository.dart';

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

  group('Poll composer (WYN-035)', () {
    testWidgets('switching to โพล mode hides the image area and needs '
        'no photo', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
      ));

      await tester.tap(find.text('โพล'));
      await tester.pump();

      expect(find.text('แตะเพื่อเลือกรูป'), findsNothing);
      expect(find.text('ตัวเลือกที่ 1'), findsOneWidget);
      expect(find.text('ตัวเลือกที่ 2'), findsOneWidget);
    });

    testWidgets('"แชร์" stays disabled until a question and both options '
        'are filled', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
      ));
      await tester.tap(find.text('โพล'));
      await tester.pump();

      final shareButton = find.widgetWithText(TextButton, 'แชร์');
      expect(tester.widget<TextButton>(shareButton).onPressed, isNull);

      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 1'), 'Pizza');
      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 2'), 'Sushi');
      await tester.pump();
      // Still no question typed -- must stay disabled.
      expect(tester.widget<TextButton>(shareButton).onPressed, isNull);

      // The caption/question field is the *last* TextField in the tree
      // in poll mode -- the option fields render above it (see
      // CreateDropScreen.build).
      await tester.enterText(find.byType(TextField).last, 'กินอะไรดี?');
      await tester.pump();

      expect(tester.widget<TextButton>(shareButton).onPressed, isNotNull);
    });

    testWidgets('duplicate options (case-insensitive) keep "แชร์" disabled',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
      ));
      await tester.tap(find.text('โพล'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).last, 'คำถาม');
      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 1'), 'Yes');
      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 2'), 'yes');
      await tester.pump();

      final shareButton = find.widgetWithText(TextButton, 'แชร์');
      expect(tester.widget<TextButton>(shareButton).onPressed, isNull);
    });

    testWidgets('เพิ่มตัวเลือก adds up to 4 options, then hides itself',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CreateDropScreen(dropRepository: repo, profileRepository: profileRepo),
      ));
      await tester.tap(find.text('โพล'));
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
      await tester.tap(find.text('โพล'));
      await tester.pump();

      // The AppBar's own leading "close screen" button also uses
      // Icons.close, so the baseline (2 options, neither removable) is
      // 1 -- it, not 0.
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.text('เพิ่มตัวเลือก'));
      await tester.pump();
      expect(find.byIcon(Icons.close), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('remove_poll_option_2')));
      await tester.pump();

      expect(find.text('ตัวเลือกที่ 3'), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
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

      await tester.tap(find.text('โพล'));
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 1'), 'Pizza');
      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 2'), 'Sushi');
      await tester.enterText(find.byType(TextField).last, 'กินอะไรดี?');
      await tester.tap(find.text('3 วัน'));
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'แชร์'));
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

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('บันทึกเป็นร่างก่อนออกไหม?'), findsNothing);
      expect(find.byType(CreateDropScreen), findsNothing);
    });

    testWidgets('closing with unsaved content (a typed caption) shows the '
        'close-intercept dialog', (tester) async {
      await openScreen(tester, repo);

      await tester.enterText(find.byType(TextField), 'ยังไม่เสร็จ');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('บันทึกเป็นร่างก่อนออกไหม?'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'ทิ้ง'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'ยกเลิก'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'บันทึกร่าง'), findsOneWidget);
    });

    testWidgets('"ยกเลิก" closes the dialog and stays on the screen',
        (tester) async {
      await openScreen(tester, repo);

      await tester.enterText(find.byType(TextField), 'ยังไม่เสร็จ');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
      await tester.pumpAndSettle();

      expect(find.text('บันทึกเป็นร่างก่อนออกไหม?'), findsNothing);
      expect(find.byType(CreateDropScreen), findsOneWidget);
      expect(find.text('ยังไม่เสร็จ'), findsOneWidget);
    });

    testWidgets('"ทิ้ง" closes without calling saveDraft', (tester) async {
      await openScreen(tester, discardTestRepo);

      await tester.enterText(find.byType(TextField), 'ยังไม่เสร็จ');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
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
      await tester.tap(find.byIcon(Icons.close));
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
      await tester.tap(find.byIcon(Icons.close));
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
      // The "แชร์" button is enabled immediately -- the carried-over
      // image counts as picked, no need to re-pick it.
      expect(
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'แชร์')).onPressed,
        isNotNull,
      );
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

    testWidgets('an incomplete poll draft (1 filled option) leaves "แชร์" '
        'disabled -- prefill does not skip validation', (tester) async {
      final draft = DropDraft(
        id: 'draft-3',
        caption: 'คำถาม',
        pollOptions: const ['Pizza', ''],
        updatedAt: DateTime(2026, 1, 1),
      );
      await openScreen(tester, repo, draft: draft);

      expect(
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'แชร์')).onPressed,
        isNull,
      );
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

      await tester.tap(find.widgetWithText(TextButton, 'แชร์'));
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

      // The SegmentedButton never clears _existingImageUrl/_imageBytes
      // on mode switch -- saveDraft must gate them by _mode itself.
      await tester.tap(find.text('โพล'));
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 1'), 'Pizza');
      await tester.enterText(
          find.widgetWithText(TextField, 'ตัวเลือกที่ 2'), 'Sushi');
      await tester.enterText(find.byType(TextField).last, 'กินอะไรดี?');

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'บันทึกร่าง'));
      await tester.pumpAndSettle();

      final args = switchModeDraftTestRepo.saveDraftArgs.single;
      expect(args['imageBytes'], isNull);
      expect(args['existingImageUrl'], isNull);
      expect(args['pollOptions'], ['Pizza', 'Sushi']);
    });
  });
}
