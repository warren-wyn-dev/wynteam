import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  setUpAll(() {
    repo = RecordingDropRepository();
    profileRepo = RecordingProfileRepository();
    pollRepo = RecordingDropRepository();
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
}
