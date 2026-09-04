// QA round 2 (2026-09-04) -- AI QA & Security.
//
// B-108-1: the heart beside a comment must be the 16px the Icon it
// replaced was, not the 24 that IconButton.iconSize could not reach.
//
// The permanent test that shipped with the fix regex-matches
// drop_detail_screen.dart for `size: 16`. This one measures what the
// widget tree actually lays out, and compares it against the delete
// icon sitting right next to it -- which is the thing a reader sees.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/wyn_heart_icon.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/data/drop_comment.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

void main() {
  late RecordingDropRepository repo;
  late RecordingFollowRepository followRepo;
  late RecordingPopRepository popRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingSavedRepository savedRepo;

  final drop = Drop(
    id: 'd1',
    authorId: 'someone-else',
    authorUsername: 'namfah',
    imageUrl: 'https://example.supabase.co/drops/d1.jpg',
    createdAt: DateTime.now(),
    likeCount: 0,
    commentCount: 1,
    likedByMe: false,
    savedByMe: false,
  );
  // Authored by the viewer, so the delete icon is on screen next to the
  // heart -- the pair whose sizes disagreed.
  final comment = DropComment(
    id: 'c1',
    dropId: 'd1',
    authorId: 'me',
    authorUsername: 'me',
    textContent: 'สวยมาก',
    createdAt: DateTime.now(),
    likeCount: 0,
    likedByMe: false,
  );

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    repo = RecordingDropRepository(comments: [comment]);
    followRepo = RecordingFollowRepository();
    popRepo = RecordingPopRepository();
    profileRepo = RecordingProfileRepository(
      profile: const Profile(id: 'someone-else', username: 'namfah'),
    );
    savedRepo = RecordingSavedRepository();
  });

  testWidgets(
      'QA-R2-25 the comment heart renders at 16px, the same size as the '
      'delete icon beside it', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(
        dropRepository: repo,
        followRepository: followRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        drop: drop,
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.scrollUntilVisible(
      find.text('สวยมาก'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    tester.takeException();

    final sizes = tester
        .widgetList<WynHeartIcon>(find.byType(WynHeartIcon))
        .map((h) => h.size)
        .toList();
    // The header's own Like heart is also on screen; the comment's is
    // the small one, and there must BE a small one.
    expect(sizes, contains(16.0),
        reason: 'the comment heart drew at 24 before the fix (B-108-1)');
    expect(sizes, isNot(contains(24.0)),
        reason: 'nothing on this screen should be a 24px heart');

    // And measured, in laid-out pixels, against the icon it sits
    // beside -- the comparison a reader actually makes. The delete icon
    // gets its 16 through IconButton.iconSize/IconTheme, which is
    // exactly the mechanism that could not reach the heart.
    final deleteIcon = find.byIcon(Icons.delete_outline);
    expect(deleteIcon, findsOneWidget);
    final deleteSize = tester.getSize(deleteIcon.first);
    final heartSize = tester.getSize(find.byWidgetPredicate(
      (w) => w is WynHeartIcon && w.size == 16,
    ));
    expect(deleteSize.width, 16.0);
    expect(heartSize.width, deleteSize.width);
    expect(heartSize.height, deleteSize.height);
  });
}
