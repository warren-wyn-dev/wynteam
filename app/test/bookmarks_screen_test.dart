import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/presentation/pop_single_clip_screen.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
import 'package:wyn/features/saved/presentation/bookmarks_screen.dart';
import 'package:wyn/features/saved/presentation/widgets/saved_post_row.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

/// 15-bookmarks.tsx -- BookmarksScreen's own full-width post-row list
/// (SavedPostRow), separate from ProfileSavedTab's 3-column grid. See
/// bookmarks_screen.dart's own doc comment.
void main() {
  setUpAll(initFakeSupabaseSession);

  final savedDrop = HomeFeedItem(
    id: 'drop-1',
    contentType: HomeContentType.drop,
    authorId: 'author-1',
    authorUsername: 'warren',
    authorDisplayName: 'WARREN',
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    caption: 'WYNOS เริ่มจากคำถามง่าย ๆ ว่า...',
    imageUrl: 'https://example.com/drop-1.jpg',
    likeCount: 352,
    commentCount: 5,
    likedByMe: false,
    savedByMe: true,
    redropCount: 13,
  );

  final savedPop = HomeFeedItem(
    id: 'pop-1',
    contentType: HomeContentType.pop,
    authorId: 'author-2',
    authorUsername: 'zen',
    authorDisplayName: 'ZEN',
    createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    caption: 'สักวันหนึ่งคุณจะขอบคุณตัวเองในวันนี้',
    videoUrl: 'https://example.com/pop-1.mp4',
    thumbnailUrl: 'https://example.com/pop-1-thumb.jpg',
    durationSeconds: 12,
    viewCount: 40,
    likeCount: 128,
    commentCount: 2,
    likedByMe: false,
    savedByMe: true,
  );

  // Repositories are built fresh in setUp (not inline inside a testWidgets
  // body) -- same convention as home_feed_screen_test.dart/side_menu_test
  // .dart's own RecordingXRepository setup. Each Recording repo's fake
  // SupabaseClient starts a real GoTrueClient auto-refresh Timer; building
  // one *inside* a testWidgets callback registers that Timer inside this
  // test's own FakeAsync zone, which then fails "!timersPending" in
  // tearDown -- setUp runs outside that zone, so it doesn't.
  late RecordingSavedRepository savedRepo;
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingFollowRepository followRepo;
  late RecordingProfileRepository profileRepo;

  setUp(() {
    savedRepo = RecordingSavedRepository();
    dropRepo = RecordingDropRepository();
    popRepo = RecordingPopRepository();
    followRepo = RecordingFollowRepository();
    profileRepo = RecordingProfileRepository();
  });

  Widget buildScreen() => MaterialApp(
        home: BookmarksScreen(
          savedRepository: savedRepo,
          dropRepository: dropRepo,
          popRepository: popRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
        ),
      );

  testWidgets(
      'shows a full-width row per saved item -- author, caption, and '
      'like/comment/repost counts, for both Drop and Pop', (tester) async {
    savedRepo.feedItems.addAll([savedDrop, savedPop]);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    // Both rows' fake thumbnail URLs 400 -- harmless NetworkImageLoadException
    // noise, same convention as home_feed_screen_test.dart's own
    // takeException() calls (SavedPostRow's errorBuilder keeps this from
    // affecting layout, but the exception itself still surfaces here).
    tester.takeException();

    expect(find.byType(SavedPostRow), findsNWidgets(2));
    expect(find.text('WARREN'), findsOneWidget);
    expect(find.text('ZEN'), findsOneWidget);
    expect(find.text('WYNOS เริ่มจากคำถามง่าย ๆ ว่า...'), findsOneWidget);
    expect(find.text('สักวันหนึ่งคุณจะขอบคุณตัวเองในวันนี้'), findsOneWidget);
    expect(find.text('352'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
  });

  testWidgets('tapping a row\'s bookmark button unsaves it and removes the '
      'row from the list', (tester) async {
    savedRepo.feedItems.add(savedDrop);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.byType(SavedPostRow), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark));
    await tester.pumpAndSettle();

    expect(find.byType(SavedPostRow), findsNothing);
    expect(dropRepo.toggleSaveCalls, 1);
  });

  testWidgets('unsaving a Pop item calls PopRepository.toggleSave, not '
      'DropRepository', (tester) async {
    savedRepo.feedItems.add(savedPop);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.byIcon(Icons.bookmark));
    await tester.pumpAndSettle();

    expect(popRepo.toggleSaveCalls, 1);
    expect(dropRepo.toggleSaveCalls, 0);
  });

  testWidgets('shows the reference empty state when nothing is saved',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีโพสต์ที่บันทึกไว้'), findsOneWidget);
    expect(
      find.text('กดไอคอนบันทึกที่โพสต์ไหนก็ได้ เพื่อเก็บไว้ดูทีหลัง'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a Drop row opens DropDetailScreen', (tester) async {
    savedRepo.feedItems.add(savedDrop);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('WYNOS เริ่มจากคำถามง่าย ๆ ว่า...'));
    await tester.pumpAndSettle();
    // DropDetailScreen also renders the same broken image URL.
    tester.takeException();

    expect(find.byType(DropDetailScreen), findsOneWidget);
  });

  testWidgets('tapping a Pop row opens PopSingleClipScreen', (tester) async {
    savedRepo.feedItems.add(savedPop);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('สักวันหนึ่งคุณจะขอบคุณตัวเองในวันนี้'));
    await tester.pumpAndSettle();
    // PopSingleClipScreen also renders the same broken thumbnail URL.
    tester.takeException();

    expect(find.byType(PopSingleClipScreen), findsOneWidget);
  });

  testWidgets('tapping the author name opens their profile', (tester) async {
    savedRepo.feedItems.add(savedDrop);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('WARREN'));
    await tester.pumpAndSettle();

    expect(find.byType(ViewProfileScreen), findsOneWidget);
  });
}
