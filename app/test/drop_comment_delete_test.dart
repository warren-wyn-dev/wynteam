import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  // See drop_comment_like_test.dart / feed_screen_test.dart for why the
  // repo (and its underlying SupabaseClient auto-refresh Timer) and the
  // fake session are built once in setUpAll rather than per-test.
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
    commentCount: 2,
    likedByMe: false,
    savedByMe: false,
    // WYN-038 QA fix: this Drop belongs to "someone-else", so opening
    // DropDetailScreen as "me" fires the optimistic View count bump
    // (0 -> 1) alongside the interaction row's other counters. Without
    // a non-zero starting viewCount here, that bump collides with the
    // comment count landing on "1" after the delete test below removes
    // one of the two seeded comments, making `find.text('1')` match two
    // widgets (StateError: "Too many elements") -- a real regression this
    // QA round caught (red) before fixing (green). 10 is an arbitrary
    // value chosen only to keep 10/11 clear of the comment count's 2/1.
    viewCount: 10,
  );
  final ownComment = DropComment(
    id: 'c1',
    dropId: 'd1',
    authorId: 'me',
    authorUsername: 'me_user',
    textContent: 'คอมเมนต์ของฉันเอง',
    createdAt: DateTime.now(),
    likeCount: 0,
    likedByMe: false,
  );
  final otherComment = DropComment(
    id: 'c2',
    dropId: 'd1',
    authorId: 'someone-else',
    authorUsername: 'ploy',
    textContent: 'คอมเมนต์ของคนอื่น',
    createdAt: DateTime.now(),
    likeCount: 0,
    likedByMe: false,
  );

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    repo = RecordingDropRepository(comments: [ownComment, otherComment]);
    followRepo = RecordingFollowRepository();
    popRepo = RecordingPopRepository();
    profileRepo = RecordingProfileRepository(
      profile: const Profile(id: 'someone-else', username: 'namfah'),
    );
    savedRepo = RecordingSavedRepository();
  });

  testWidgets(
      'shows a delete button only next to the current user\'s own comment',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(dropRepository: repo, followRepository: followRepo, profileRepository: profileRepo, popRepository: popRepo, savedRepository: savedRepo, drop: drop),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    // Both comments are pushed below the viewport by the 800px header
    // image in this 800x600 test surface -- see .wyn/learning/PATTERNS.md.
    await tester.scrollUntilVisible(
      find.text('คอมเมนต์ของคนอื่น'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    tester.takeException();

    expect(find.text('คอมเมนต์ของฉันเอง'), findsOneWidget);
    expect(find.text('คอมเมนต์ของคนอื่น'), findsOneWidget);
    // Exactly one delete_outline icon -- next to the own comment only.
    // (The Drop's own header delete button doesn't apply here since this
    // drop belongs to "someone-else".)
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets(
      'deleting an own comment asks for confirmation, then removes it from '
      'the list and decrements the Drop\'s comment count', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(dropRepository: repo, followRepository: followRepo, profileRepository: profileRepo, popRepository: popRepo, savedRepository: savedRepo, drop: drop),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    final deleteButton = find.byIcon(Icons.delete_outline);
    await tester.scrollUntilVisible(
      deleteButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    tester.takeException();
    expect(deleteButton, findsOneWidget);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // Confirmation dialog is up -- deleting shouldn't happen yet.
    expect(find.text('ลบคอมเมนต์นี้?'), findsOneWidget);
    expect(repo.deleteCommentCalls, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'ลบ'));
    await tester.pumpAndSettle();

    expect(repo.deleteCommentCalls, ['c1']);
    expect(find.text('คอมเมนต์ของฉันเอง'), findsNothing);
    expect(find.text('คอมเมนต์ของคนอื่น'), findsOneWidget);

    // The Drop's own comment-count label sits in the header, above the
    // comments -- scroll back up to see it reflect the decrement.
    await tester.scrollUntilVisible(
      find.text('1'),
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    tester.takeException();
    expect(find.text('1'), findsOneWidget);
  });
}
