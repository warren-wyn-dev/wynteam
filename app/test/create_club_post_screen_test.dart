import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/presentation/create_club_post_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_profile_repository.dart';

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
}
