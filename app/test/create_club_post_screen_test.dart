import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/presentation/create_club_post_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_profile_repository.dart';

/// Drains every pending exception, not just the first -- WYN-103's
/// image-limit tests seed several images at once via
/// debugInitialImagesBytes with deliberately-invalid bytes (same
/// "harmless expected decode failure" posture as CreateDropScreen's own
/// tests), which reports one "Invalid image data" exception per image
/// rather than a single one.
void _drainExpectedImageDecodeExceptions(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

void main() {
  late RecordingClubPostRepository clubPostRepo;
  late RecordingProfileRepository profileRepo;

  final testClub = Club(
    id: 'club-1',
    name: 'ชมรมถ่ายภาพ',
    privacy: ClubPrivacy.public,
    ownerId: 'me',
    createdAt: DateTime.now(),
    memberCount: 5,
  );

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    clubPostRepo = RecordingClubPostRepository();
    profileRepo = RecordingProfileRepository(
      searchResults: [const Profile(id: 'u1', username: 'namfah', displayName: 'น้ำฝน')],
    );
  });

  Widget buildScreen() => MaterialApp(
        home: CreateClubPostScreen(
          clubPostRepository: clubPostRepo,
          club: testClub,
          channelId: 'channel-1',
          channelName: 'ทั่วไป',
          profileRepository: profileRepo,
        ),
      );

  // WYN-103: seeds _images directly via the debugInitialImagesBytes
  // test-only seam instead of tapping "แนบรูป" and going through a real
  // image_picker pick -- see CreateDropScreen's identically-named field
  // for why (a hang specific to this sandbox, documented in
  // .wyn/company/DECISIONS.md, 2026-09-02).
  Widget buildScreenWithImages(int imageCount) => MaterialApp(
        home: CreateClubPostScreen(
          clubPostRepository: clubPostRepo,
          club: testClub,
          channelId: 'channel-1',
          channelName: 'ทั่วไป',
          profileRepository: profileRepo,
          debugInitialImagesBytes: List.generate(
            imageCount,
            (i) => Uint8List.fromList([1, 2, 3]),
          ),
        ),
      );

  testWidgets('posting plain text content with no mention sends an empty '
      'mentionedUserIds set', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.byType(TextField).first, 'สวัสดีทุกคน');
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'โพสต์'));
    await tester.pumpAndSettle();

    expect(clubPostRepo.createPostCalls, 1);
    expect(clubPostRepo.createPostMentionedUserIdsArgs, [<String>{}]);
  });

  testWidgets('selecting a mention while composing sends its resolved user id '
      'in mentionedUserIds on post', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.byType(TextField).first, 'ทักทาย @nam');
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('น้ำฝน'));
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'โพสต์'));
    await tester.pumpAndSettle();

    expect(clubPostRepo.createPostCalls, 1);
    expect(clubPostRepo.createPostMentionedUserIdsArgs, [
      {'u1'},
    ]);
  });

  group('Poll composer (WYN-115)', () {
    testWidgets(
        'switching to poll mode hides "แนบรูป" and shows the poll option '
        'fields instead', (tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.widgetWithText(OutlinedButton, 'แนบรูป'), findsOneWidget);
      expect(find.text('ตัวเลือกที่ 1'), findsNothing);

      await tester.tap(find.byKey(const Key('club_post_poll_mode_button')));
      await tester.pump();

      expect(find.widgetWithText(OutlinedButton, 'แนบรูป'), findsNothing);
      expect(find.text('ตัวเลือกที่ 1'), findsOneWidget);
      expect(find.text('ตัวเลือกที่ 2'), findsOneWidget);
    });

    testWidgets(
        '"โพสต์" stays disabled in poll mode until the question and both '
        'options are filled in', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.tap(find.byKey(const Key('club_post_poll_mode_button')));
      await tester.pump();

      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'โพสต์')).onPressed,
          isNull);

      await tester.enterText(find.byType(TextField).first, 'อาหารเที่ยงนี้กินอะไรดี?');
      await tester.enterText(find.widgetWithText(TextField, 'ตัวเลือกที่ 1'), 'ข้าวมันไก่');
      await tester.pump();

      // Second option still empty -- still disabled.
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'โพสต์')).onPressed,
          isNull);

      await tester.enterText(find.widgetWithText(TextField, 'ตัวเลือกที่ 2'), 'ส้มตำ');
      await tester.pump();

      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'โพสต์')).onPressed,
          isNotNull);
    });

    testWidgets(
        'posting in poll mode calls createPollClubPost with the question, '
        'trimmed options, and selected duration', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.tap(find.byKey(const Key('club_post_poll_mode_button')));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'อาหารเที่ยงนี้กินอะไรดี?');
      await tester.enterText(find.widgetWithText(TextField, 'ตัวเลือกที่ 1'), 'ข้าวมันไก่ ');
      await tester.enterText(find.widgetWithText(TextField, 'ตัวเลือกที่ 2'), ' ส้มตำ');
      await tester.pump();

      await tester.tap(find.text('3 วัน'));
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'โพสต์'));
      await tester.pumpAndSettle();

      expect(clubPostRepo.createPostCalls, 0);
      expect(clubPostRepo.createPollClubPostArgs, [
        {
          'clubId': 'club-1',
          'channelId': 'channel-1',
          'question': 'อาหารเที่ยงนี้กินอะไรดี?',
          'options': ['ข้าวมันไก่', 'ส้มตำ'],
          'durationDays': 3,
          'mentionedUserIds': <String>{},
        },
      ]);
    });

    testWidgets('"+ เพิ่มตัวเลือก" adds a 3rd option field with a remove button',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.tap(find.byKey(const Key('club_post_poll_mode_button')));
      await tester.pump();

      await tester.tap(find.text('เพิ่มตัวเลือก'));
      await tester.pump();

      expect(find.text('ตัวเลือกที่ 3'), findsOneWidget);
      expect(find.byKey(const Key('remove_club_poll_option_2')), findsOneWidget);
    });
  });

  group('Image limit (WYN-103)', () {
    testWidgets(
        'the limit is 9, not 10 -- "แนบรูป" stays tappable at 9/9 and '
        'shows a SnackBar instead of just going inert', (tester) async {
      await tester.pumpWidget(buildScreenWithImages(9));
      _drainExpectedImageDecodeExceptions(tester);

      final attachButton =
          find.widgetWithText(OutlinedButton, 'แนบรูป');
      // Still tappable (not disabled) -- WYN-103 explicitly moved away
      // from a disabled button here in favor of tap-then-SnackBar.
      expect(tester.widget<OutlinedButton>(attachButton).onPressed, isNotNull);

      await tester.tap(attachButton);
      await tester.pump();

      expect(find.text('เพิ่มรูปได้สูงสุด 9 รูปต่อโพสต์'), findsOneWidget);
    });

    testWidgets('below the limit, "แนบรูป" does not show the limit SnackBar',
        (tester) async {
      await tester.pumpWidget(buildScreenWithImages(3));
      _drainExpectedImageDecodeExceptions(tester);

      expect(find.text('เพิ่มรูปได้สูงสุด 9 รูปต่อโพสต์'), findsNothing);
    });
  });
}
