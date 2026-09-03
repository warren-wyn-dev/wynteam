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
