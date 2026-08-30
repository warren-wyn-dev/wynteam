import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/hashtag/presentation/hashtag_feed_screen.dart';
import 'package:wyn/features/search/data/discovery_ranking.dart';
import 'package:wyn/features/search/presentation/top_100_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_discovery_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

/// Top100Screen, redefined 2026-08-29 (Founder-approved `03-search.tsx`
/// re-brand -- see .wyn/company/DECISIONS.md) from a content leaderboard
/// to a hashtag leaderboard -- see top_100_screen.dart's own doc comment.
void main() {
  late RecordingDiscoveryRepository discoveryRepo;
  late RecordingDropRepository dropRepo;
  late RecordingClubPostRepository clubPostRepo;
  late RecordingClubRepository clubRepo;
  late RecordingFollowRepository followRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    discoveryRepo = RecordingDiscoveryRepository();
    dropRepo = RecordingDropRepository();
    clubPostRepo = RecordingClubPostRepository();
    clubRepo = RecordingClubRepository();
    followRepo = RecordingFollowRepository();
    profileRepo = RecordingProfileRepository();
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();
  });

  Widget buildScreen() {
    return MaterialApp(
      home: Top100Screen(
        discoveryRepository: discoveryRepo,
        dropRepository: dropRepo,
        clubPostRepository: clubPostRepo,
        clubRepository: clubRepo,
        followRepository: followRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
      ),
    );
  }

  testWidgets('shows a loading spinner, then the ranked hashtag list '
      'in order', (tester) async {
    discoveryRepo.trendingHashtags = const [
      RankedHashtag(tag: 'wyn', postCount: 20),
      RankedHashtag(tag: 'flutter', postCount: 10),
    ];

    await tester.pumpWidget(buildScreen());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('#wyn'), findsOneWidget);
    expect(find.text('20 โพสต์ · กำลังนิยมใน ไทย'), findsOneWidget);
    expect(find.text('#flutter'), findsOneWidget);
    expect(find.text('10 โพสต์ · กำลังนิยมใน ไทย'), findsOneWidget);

    // #wyn (rank 1) must render above #flutter (rank 2).
    final firstTop = tester.getTopLeft(find.text('#wyn')).dy;
    final secondTop = tester.getTopLeft(find.text('#flutter')).dy;
    expect(firstTop, lessThan(secondTop));
  });

  testWidgets('shows the empty state when there are no trending hashtags',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีแฮชแท็กกำลังนิยมตอนนี้'), findsOneWidget);
  });

  testWidgets(
      'a fetch failure shows an error with a retry button, and '
      'retrying re-fetches successfully', (tester) async {
    discoveryRepo.trendingHashtagsError = Exception('boom');
    discoveryRepo.trendingHashtags = const [
      RankedHashtag(tag: 'wyn', postCount: 5),
    ];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('โหลด Top 100 ไม่สำเร็จ'), findsOneWidget);
    expect(find.text('#wyn'), findsNothing);

    discoveryRepo.trendingHashtagsError = null;
    await tester.tap(find.text('ลองใหม่'));
    await tester.pumpAndSettle();

    expect(find.text('โหลด Top 100 ไม่สำเร็จ'), findsNothing);
    expect(find.text('#wyn'), findsOneWidget);
  });

  testWidgets('tapping a ranked hashtag row opens HashtagFeedScreen',
      (tester) async {
    discoveryRepo.trendingHashtags = const [
      RankedHashtag(tag: 'wyn', postCount: 5),
    ];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('#wyn'));
    await tester.pumpAndSettle();

    expect(find.byType(HashtagFeedScreen), findsOneWidget);
  });
}
