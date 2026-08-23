import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/presentation/pop_single_clip_screen.dart';
import 'package:wyn/features/home/presentation/widgets/trending_tile.dart';
import 'package:wyn/features/search/presentation/top_100_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_discovery_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

HomeFeedItem _dropItem({String id = 'd1', String authorUsername = 'namfah'}) =>
    HomeFeedItem(
      id: id,
      contentType: HomeContentType.drop,
      authorId: 'author-$id',
      authorUsername: authorUsername,
      createdAt: DateTime.now(),
      caption: 'caption',
      imageUrl: 'https://example.supabase.co/drops/$id.jpg',
      likeCount: 10,
      commentCount: 1,
      likedByMe: false,
      savedByMe: false,
    );

HomeFeedItem _popItem({String id = 'p1', String authorUsername = 'ploy'}) =>
    HomeFeedItem(
      id: id,
      contentType: HomeContentType.pop,
      authorId: 'author-$id',
      authorUsername: authorUsername,
      createdAt: DateTime.now(),
      caption: 'caption',
      videoUrl: 'https://example.supabase.co/pops/$id.mp4',
      durationSeconds: 10,
      viewCount: 5,
      likeCount: 3,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

void main() {
  late RecordingDiscoveryRepository discoveryRepo;
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingFollowRepository followRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingSavedRepository savedRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    discoveryRepo = RecordingDiscoveryRepository();
    dropRepo = RecordingDropRepository();
    popRepo = RecordingPopRepository();
    followRepo = RecordingFollowRepository();
    profileRepo = RecordingProfileRepository();
    savedRepo = RecordingSavedRepository();
  });

  Widget buildScreen() {
    return MaterialApp(
      home: Top100Screen(
        discoveryRepository: discoveryRepo,
        dropRepository: dropRepo,
        popRepository: popRepo,
        followRepository: followRepo,
        profileRepository: profileRepo,
        savedRepository: savedRepo,
      ),
    );
  }

  testWidgets('shows a loading spinner, then the ranked list in order',
      (tester) async {
    discoveryRepo.topContentItems = [
      _dropItem(id: 'd1', authorUsername: 'first'),
      _dropItem(id: 'd2', authorUsername: 'second'),
    ];

    await tester.pumpWidget(buildScreen());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    tester.takeException(); // Image.network fails to load in the test env.

    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('@first'), findsOneWidget);
    expect(find.text('@second'), findsOneWidget);

    // #1 must render above #2 -- top() compares each row's vertical
    // position rather than trusting list order alone.
    final rank1Top = tester.getTopLeft(find.text('#1')).dy;
    final rank2Top = tester.getTopLeft(find.text('#2')).dy;
    expect(rank1Top, lessThan(rank2Top));
  });

  testWidgets('shows the empty state when there is no content', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีเนื้อหาติด Top 100 ตอนนี้'), findsOneWidget);
  });

  testWidgets(
      'a fetch failure shows an error with a retry button, and '
      'retrying re-fetches successfully', (tester) async {
    discoveryRepo.topContentError = Exception('boom');
    discoveryRepo.topContentItems = [_dropItem()];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('โหลด Top 100 ไม่สำเร็จ'), findsOneWidget);
    expect(find.text('#1'), findsNothing);

    discoveryRepo.topContentError = null;
    await tester.tap(find.text('ลองใหม่'));
    await tester.pumpAndSettle();
    tester.takeException(); // Image.network fails to load in the test env.

    expect(find.text('โหลด Top 100 ไม่สำเร็จ'), findsNothing);
    expect(find.text('#1'), findsOneWidget);
  });

  testWidgets('tapping a Drop row opens DropDetailScreen', (tester) async {
    discoveryRepo.topContentItems = [_dropItem(authorUsername: 'namfah')];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('@namfah'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(DropDetailScreen), findsOneWidget);
  });

  testWidgets('tapping a Pop row opens PopSingleClipScreen', (tester) async {
    discoveryRepo.topContentItems = [_popItem(authorUsername: 'ploy')];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('@ploy'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(PopSingleClipScreen), findsOneWidget);
  });

  testWidgets(
      'rows never show the Rainbow ring (WYN-042 -- distinct from '
      'Trending Now)', (tester) async {
    discoveryRepo.topContentItems = [_dropItem()];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    tester.takeException();

    final tile = tester.widget<TrendingTile>(find.byType(TrendingTile));
    expect(tile.showRainbowRing, isFalse);
  });
}
