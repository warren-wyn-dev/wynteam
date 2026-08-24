import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/widgets/drop_grid_tile.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_drop_grid_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

Drop _drop({required String id, String? imageUrl}) => Drop(
      id: id,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: imageUrl,
      caption: imageUrl == null ? 'ข้อความอย่างเดียว' : null,
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // Constructed in setUpAll -- see profile_drafts_tab_test.dart's own
  // comment on why (GoTrue Timer/FakeAsync zone attribution).
  late RecordingDropRepository repo;
  late RecordingFollowRepository followRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    repo = RecordingDropRepository(feedDrops: [
      _drop(id: 'd1', imageUrl: 'https://example.supabase.co/drops/d1.jpg'),
      _drop(id: 'd2'), // text-only, no image
      _drop(id: 'd3', imageUrl: 'https://example.supabase.co/drops/d3.jpg'),
    ]);
    followRepo = RecordingFollowRepository();
    profileRepo = RecordingProfileRepository();
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();
  });

  testWidgets(
      'onlyWithImages: true (the Media tab) shows only Drops that have an '
      'image', (tester) async {
    await tester.pumpWidget(_wrap(ProfileDropGridTab(
      dropRepository: repo,
      followRepository: followRepo,
      profileRepository: profileRepo,
      popRepository: popRepo,
      savedRepository: savedRepo,
      authorId: 'someone-else',
      emptyText: 'ยังไม่มีสื่อ',
      onlyWithImages: true,
    )));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(DropGridTile), findsNWidgets(2));
  });

  testWidgets('onlyWithImages: false (the default, Posts tab) shows every '
      'Drop including text-only ones', (tester) async {
    await tester.pumpWidget(_wrap(ProfileDropGridTab(
      dropRepository: repo,
      followRepository: followRepo,
      profileRepository: profileRepo,
      popRepository: popRepo,
      savedRepository: savedRepo,
      authorId: 'someone-else',
      emptyText: 'ยังไม่มีโพสต์',
    )));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(DropGridTile), findsNWidgets(3));
  });
}
