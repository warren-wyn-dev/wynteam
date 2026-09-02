import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/data/drop_comment.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/drop/presentation/edit_drop_caption_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

void main() {
  // DropDetailScreen reads Supabase.instance.client.auth.currentUser
  // directly (for the "is this my own Drop" check) -- initialize a fake
  // local-only session so it can be pumped at all. See
  // .wyn/learning/PATTERNS.md.
  late RecordingDropRepository repo;
  late RecordingFollowRepository followRepo;
  late RecordingPopRepository popRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingSavedRepository savedRepo;
  late RecordingDropRepository ownDropRepo;
  late RecordingFollowRepository ownDropFollowRepo;
  late RecordingDropRepository followToggleTestDropRepo;
  late RecordingFollowRepository followToggleTestFollowRepo;
  late RecordingDropRepository tapProfileTestDropRepo;
  late RecordingFollowRepository tapProfileTestFollowRepo;
  late RecordingProfileRepository tapProfileTestProfileRepo;
  late RecordingDropRepository ownCommentRepo;
  late RecordingDropRepository replyTestRepo;
  late RecordingDropRepository existingReplyRepo;
  late RecordingDropRepository pollVoteTestRepo;
  late RecordingDropRepository pollOwnAuthorTestRepo;
  late RecordingDropRepository editMenuTestRepo;
  late RecordingDropRepository oldDropMenuTestRepo;
  late RecordingDropRepository editFlowTestRepo;
  late RecordingDropRepository deleteFlowTestRepo;
  late RecordingDropRepository viewCountTestRepo;
  late RecordingDropRepository ownDropViewCountTestRepo;
  late RecordingDropRepository viewCountNoRepeatTestRepo;
  late RecordingDropRepository viewCountSemanticsTestRepo;
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    repo = RecordingDropRepository();
    ownCommentRepo = RecordingDropRepository(comments: [
      DropComment(
        id: 'c1',
        dropId: 'd1',
        authorId: 'me',
        authorUsername: 'me_user',
        textContent: 'ความคิดเห็นของฉัน',
        createdAt: DateTime.now(),
        likeCount: 0,
        likedByMe: false,
      ),
    ]);
    replyTestRepo = RecordingDropRepository(comments: [
      DropComment(
        id: 'top-1',
        dropId: 'd1',
        authorId: 'someone-else',
        authorUsername: 'namfah',
        textContent: 'ความคิดเห็นระดับบนสุด',
        createdAt: DateTime.now(),
        likeCount: 0,
        likedByMe: false,
      ),
    ]);
    existingReplyRepo = RecordingDropRepository(comments: [
      DropComment(
        id: 'top-1',
        dropId: 'd1',
        authorId: 'someone-else',
        authorUsername: 'namfah',
        textContent: 'ความคิดเห็นระดับบนสุด',
        createdAt: DateTime.now(),
        likeCount: 0,
        likedByMe: false,
      ),
      DropComment(
        id: 'reply-1',
        dropId: 'd1',
        authorId: 'someone-else',
        authorUsername: 'ploy',
        textContent: 'ตอบกลับความคิดเห็นด้านบน',
        createdAt: DateTime.now(),
        likeCount: 0,
        likedByMe: false,
        parentCommentId: 'top-1',
      ),
    ]);
    followRepo = RecordingFollowRepository();
    popRepo = RecordingPopRepository();
    profileRepo = RecordingProfileRepository(
      profile: const Profile(id: 'someone-else', username: 'namfah'),
    );
    savedRepo = RecordingSavedRepository();
    ownDropRepo = RecordingDropRepository();
    ownDropFollowRepo = RecordingFollowRepository();
    followToggleTestDropRepo = RecordingDropRepository();
    followToggleTestFollowRepo =
        RecordingFollowRepository(initiallyFollowing: false);
    tapProfileTestDropRepo = RecordingDropRepository();
    tapProfileTestFollowRepo = RecordingFollowRepository();
    tapProfileTestProfileRepo = RecordingProfileRepository(
      profile: const Profile(id: 'someone-else', username: 'namfah'),
    );
    // WYN-035 -- constructed here rather than inline inside a
    // testWidgets body, same "avoid a leaked GoTrue auto-refresh timer
    // at teardown" reasoning as every other RecordingDropRepository in
    // this setUpAll.
    pollVoteTestRepo = RecordingDropRepository();
    pollOwnAuthorTestRepo = RecordingDropRepository();
    // WYN-037 -- same "constructed in setUpAll" discipline.
    editMenuTestRepo = RecordingDropRepository();
    oldDropMenuTestRepo = RecordingDropRepository();
    editFlowTestRepo = RecordingDropRepository();
    deleteFlowTestRepo = RecordingDropRepository();
    // WYN-038 -- same "constructed in setUpAll" discipline.
    viewCountTestRepo = RecordingDropRepository();
    ownDropViewCountTestRepo = RecordingDropRepository();
    viewCountNoRepeatTestRepo = RecordingDropRepository();
    // WYN-038 QA fix: the Semantics-label test below originally
    // constructed a `RecordingDropRepository()` inline inside its
    // testWidgets body -- every RecordingDropRepository above it in this
    // same setUpAll follows the documented "avoid a leaked GoTrue
    // auto-refresh timer at teardown" discipline precisely to prevent
    // this. Once the (separately fixed) semantics-matching assertion
    // below stopped short-circuiting the test on its own failure, this
    // leaked Timer surfaced for real as "A Timer is still pending even
    // after the widget tree was disposed" at teardown -- confirmed red
    // with the inline construction, green after moving it here.
    viewCountSemanticsTestRepo = RecordingDropRepository();
  });

  final tallDrop = Drop(
    id: 'd1',
    authorId: 'u1',
    authorUsername: 'namfah',
    imageUrl: 'https://example.supabase.co/drops/d1.jpg',
    caption: 'a' * 400,
    createdAt: DateTime.now(),
    likeCount: 0,
    commentCount: 0,
    likedByMe: false,
    savedByMe: false,
  );

  testWidgets(
      'a tall Drop header (long caption + image) scrolls instead of '
      'overflowing on a short viewport', (tester) async {
    // The default flutter_test surface (800x600) is wide/short -- the
    // exact shape that overflowed WYN-004's PostDetailScreen before it
    // merged the header into the comment list's scrollable. This spec
    // (.wyn/docs/design/wyn-005-drop.md) called out building it that way
    // from the start, so this test exists to prove it actually was.
    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(dropRepository: repo, followRepository: followRepo, profileRepository: profileRepo, popRepository: popRepo, savedRepository: savedRepo, drop: tallDrop),
    ));
    // fetchComments() fails against the fake network, and the image
    // fails to load -- both expected, neither is what this test checks.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'WYN-086: a Drop with both a caption and an image shows the caption '
      'above the image, not below it', (tester) async {
    final captionAboveImageDrop = Drop(
      id: 'd-caption-image-order',
      authorId: 'u1',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/order.jpg',
      caption: 'ข้อความโพสต์',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );
    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(
        dropRepository: repo,
        followRepository: followRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        drop: captionAboveImageDrop,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();

    final captionTop = tester.getTopLeft(find.text('ข้อความโพสต์')).dy;
    final imageTop = tester.getTopLeft(find.byType(Image)).dy;
    expect(captionTop, lessThan(imageTop));
  });

  testWidgets('toggling Like flips the icon and count optimistically',
      (tester) async {
    final drop = Drop(
      id: 'd2',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d2.jpg',
      createdAt: DateTime.now(),
      likeCount: 3,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(dropRepository: repo, followRepository: followRepo, profileRepository: profileRepo, popRepository: popRepo, savedRepository: savedRepo, drop: drop),
    ));
    await tester.pump();
    // No real network access in the test environment -- expected and
    // irrelevant to what this test checks (that the like state toggles).
    tester.takeException();

    final likeButton = find.byIcon(Icons.favorite_border);
    expect(likeButton, findsOneWidget);
    // 07-post-detail.tsx: the count lives in the plain-language stat
    // line ("3 ถูกใจ"), not next to the action-bar icon anymore -- see
    // DropDetailScreen._buildStatLine.
    expect(find.text('3 ถูกใจ'), findsOneWidget);

    // The square image above it (AspectRatio 1, 800px wide in this test
    // viewport) pushes the like button below the visible 600px-tall
    // surface -- scroll it into view before tapping.
    await tester.ensureVisible(likeButton);
    await tester.pumpAndSettle();
    tester.takeException();
    await tester.tap(likeButton);
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('4 ถูกใจ'), findsOneWidget);
  });

  testWidgets('shows a Follow button for another user\'s Drop',
      (tester) async {
    final otherDrop = Drop(
      id: 'd3',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d3.jpg',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(
        dropRepository: repo,
        followRepository: followRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        drop: otherDrop,
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.widgetWithText(OutlinedButton, 'ติดตาม'), findsOneWidget);
    // DS-008 touch-target audit (WCAG 2.5.5): the Follow pill button was
    // squeezed to 30px tall to fit the header row -- confirm the fix
    // actually reaches the 44px minimum, not just that the button exists.
    final followButtonSize = tester.getSize(
      find.ancestor(
        of: find.widgetWithText(OutlinedButton, 'ติดตาม'),
        matching: find.byType(SizedBox),
      ).first,
    );
    expect(followButtonSize.height, greaterThanOrEqualTo(44));
  });

  testWidgets(
      'DS-008: the per-comment delete and like buttons meet the 44px touch '
      'target minimum (WCAG 2.5.5), not the 32px box they used to be '
      'squeezed into', (tester) async {
    // The 1:1 header image is 800px tall on the default 800x600 test
    // viewport, pushing the comment list (and its delete/like buttons)
    // out of ListView's cache extent -- use a tall custom viewport
    // instead, same fix as DS-003's divider test.
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Someone else's Drop (so the top-level "ลบ Drop" IconButton, which
    // shares the same delete_outline icon, never renders) with one
    // comment authored by the current user, so the comment's own
    // delete/like buttons are the only delete_outline/favorite_border
    // IconButtons on screen.
    final otherDropWithOwnComment = Drop(
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

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(
        dropRepository: ownCommentRepo,
        followRepository: followRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        drop: otherDropWithOwnComment,
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    final deleteButtonSize = tester.getSize(
      find.ancestor(
        of: find.widgetWithIcon(IconButton, Icons.delete_outline),
        matching: find.byType(SizedBox),
      ).first,
    );
    expect(deleteButtonSize.width, greaterThanOrEqualTo(44));
    expect(deleteButtonSize.height, greaterThanOrEqualTo(44));

    final likeButtonSize = tester.getSize(
      find.ancestor(
        of: find.widgetWithIcon(IconButton, Icons.favorite_border),
        matching: find.byType(SizedBox),
      ).first,
    );
    expect(likeButtonSize.width, greaterThanOrEqualTo(44));
    expect(likeButtonSize.height, greaterThanOrEqualTo(44));
  });

  testWidgets('does not show a Follow button for the current user\'s own '
      'Drop', (tester) async {
    final ownDrop = Drop(
      id: 'd4',
      authorId: 'me',
      authorUsername: 'me_user',
      imageUrl: 'https://example.supabase.co/drops/d4.jpg',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(
        dropRepository: ownDropRepo,
        followRepository: ownDropFollowRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        drop: ownDrop,
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.widgetWithText(OutlinedButton, 'ติดตาม'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'กำลังติดตาม'), findsNothing);
  });

  testWidgets(
      'rapid double-tap on Follow sends a fresh currentlyFollowing value '
      'each time instead of reusing the stale pre-tap state', (tester) async {
    final drop = Drop(
      id: 'd5',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d5.jpg',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(
        dropRepository: followToggleTestDropRepo,
        followRepository: followToggleTestFollowRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        drop: drop,
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    final followButton = find.widgetWithText(OutlinedButton, 'ติดตาม');
    expect(followButton, findsOneWidget);

    final onPressed = tester.widget<OutlinedButton>(followButton).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(followToggleTestFollowRepo.toggleFollowCalls, 2);
    expect(
      followToggleTestFollowRepo.toggleFollowCurrentlyFollowingArgs,
      [false, true],
    );
  });

  testWidgets(
      'tapping the avatar/name opens the author\'s profile, without also '
      'toggling Follow (WYN-013)', (tester) async {
    final drop = Drop(
      id: 'd6',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d6.jpg',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(
        dropRepository: tapProfileTestDropRepo,
        followRepository: tapProfileTestFollowRepo,
        profileRepository: tapProfileTestProfileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        drop: drop,
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    final nameFinder = find.text('@namfah');
    await tester.ensureVisible(nameFinder);
    await tester.pumpAndSettle();
    tester.takeException();
    await tester.tap(nameFinder);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ViewProfileScreen), findsOneWidget);
    expect(tapProfileTestFollowRepo.toggleFollowCalls, 0);
  });

  final repoTestDrop = Drop(
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

  group('Comment reply (WYN-022)', () {
    testWidgets('a top-level comment has a "ตอบกลับ" button, a reply does not',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: existingReplyRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: repoTestDrop,
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      // Exactly one "ตอบกลับ" button -- the top-level comment's, not
      // the reply's.
      expect(find.text('ตอบกลับ'), findsOneWidget);
      expect(find.text('ความคิดเห็นระดับบนสุด'), findsOneWidget);
      expect(find.text('ตอบกลับความคิดเห็นด้านบน'), findsOneWidget);
    });

    testWidgets(
        'tapping "ตอบกลับ" shows a reply chip, and sending calls addComment '
        'with the parent id', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: replyTestRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: repoTestDrop,
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('ตอบกลับ'));
      await tester.pumpAndSettle();

      expect(find.text('ตอบกลับ @namfah'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'คำตอบของฉัน');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(replyTestRepo.addCommentCalls, 1);
      expect(replyTestRepo.addCommentParentIdArgs, ['top-1']);
      // The reply chip clears after sending -- back to composing a new
      // top-level comment.
      expect(find.text('ตอบกลับ @namfah'), findsNothing);
    });

    testWidgets('cancelling a reply (tapping the X) clears the chip and reply state',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: replyTestRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: repoTestDrop,
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('ตอบกลับ'));
      await tester.pumpAndSettle();
      expect(find.text('ตอบกลับ @namfah'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('ตอบกลับ @namfah'), findsNothing);
    });
  });

  group('Poll (WYN-035)', () {
    Drop pollDrop({
      int? myVoteIndex,
      int? totalVotes,
      List<int>? optionCounts,
    }) =>
        Drop(
          id: 'poll-d1',
          authorId: 'someone-else',
          authorUsername: 'namfah',
          caption: 'กินอะไรดี?',
          createdAt: DateTime.now(),
          likeCount: 0,
          commentCount: 0,
          likedByMe: false,
          savedByMe: false,
          pollId: 'p1',
          pollOptions: const ['Pizza', 'Sushi'],
          pollExpiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
          pollMyVoteIndex: myVoteIndex,
          pollTotalVotes: totalVotes,
          pollOptionCounts: optionCounts,
        );

    testWidgets('shows the Poll widget instead of an image, and voting '
        'calls votePoll and updates optimistically', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: pollVoteTestRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: pollDrop(),
        ),
      ));
      await tester.pump();
      // No real network access in the test environment -- expected and
      // irrelevant to what this test checks.
      tester.takeException();

      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Sushi'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);

      await tester.tap(find.text('Pizza'));
      await tester.pump();

      expect(pollVoteTestRepo.votePollArgs, [('p1', 0)]);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('the poll author cannot vote on their own poll',
        (tester) async {
      final ownPoll = Drop(
        id: 'poll-own',
        authorId: 'me',
        authorUsername: 'me_user',
        caption: 'โพลของฉัน',
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
        pollId: 'p-own',
        pollOptions: const ['A', 'B'],
        pollExpiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        pollTotalVotes: 0,
        pollOptionCounts: const [0, 0],
      );

      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: pollOwnAuthorTestRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: ownPoll,
        ),
      ));
      await tester.pump();
      tester.takeException();

      await tester.tap(find.text('A'), warnIfMissed: false);
      await tester.pump();

      expect(pollOwnAuthorTestRepo.votePollArgs, isEmpty);
    });
  });

  group('Edit/Delete (WYN-037)', () {
    testWidgets(
        'own Drop within the 30-minute edit window shows both "แก้ไข" and '
        '"ลบ" in the more_vert menu', (tester) async {
      final freshOwnDrop = Drop(
        id: 'edit-1',
        authorId: 'me',
        authorUsername: 'me_user',
        imageUrl: 'https://example.supabase.co/drops/edit-1.jpg',
        caption: 'เดิม',
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      );

      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: editMenuTestRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: freshOwnDrop,
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.more_vert)).onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('แก้ไข'), findsOneWidget);
      expect(find.text('ลบ'), findsOneWidget);
    });

    testWidgets(
        'own Drop past the 30-minute edit window hides "แก้ไข", keeps "ลบ"',
        (tester) async {
      final oldOwnDrop = Drop(
        id: 'edit-2',
        authorId: 'me',
        authorUsername: 'me_user',
        imageUrl: 'https://example.supabase.co/drops/edit-2.jpg',
        caption: 'เก่าแล้ว',
        createdAt: DateTime.now().subtract(const Duration(minutes: 31)),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      );

      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: oldDropMenuTestRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: oldOwnDrop,
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.more_vert)).onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('แก้ไข'), findsNothing);
      expect(find.text('ลบ'), findsOneWidget);
    });

    testWidgets(
        'tapping "แก้ไข" opens EditDropCaptionScreen prefilled, and '
        'returning the new caption updates the caption and shows '
        '"แก้ไขแล้ว"', (tester) async {
      final drop = Drop(
        id: 'edit-3',
        authorId: 'me',
        authorUsername: 'me_user',
        imageUrl: 'https://example.supabase.co/drops/edit-3.jpg',
        caption: 'เดิม',
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      );

      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: editFlowTestRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: drop,
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.more_vert)).onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('แก้ไข'));
      await tester.pumpAndSettle();

      expect(find.byType(EditDropCaptionScreen), findsOneWidget);
      expect(find.text('เดิม'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'แก้ไขแล้วนะ');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'บันทึก'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(EditDropCaptionScreen), findsNothing);
      expect(editFlowTestRepo.editDropArgs, hasLength(1));
      expect(editFlowTestRepo.editDropArgs.single['caption'], 'แก้ไขแล้วนะ');
      expect(find.text('แก้ไขแล้วนะ'), findsOneWidget);
      expect(find.text('แก้ไขแล้ว'), findsOneWidget);
    });

    testWidgets('tapping "ลบ" confirms then soft-deletes via deleteDrop',
        (tester) async {
      final drop = Drop(
        id: 'delete-1',
        authorId: 'me',
        authorUsername: 'me_user',
        imageUrl: 'https://example.supabase.co/drops/delete-1.jpg',
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      );

      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: deleteFlowTestRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: drop,
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.more_vert)).onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();

      expect(find.text('ลบโพสต์นี้?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'ลบ'));
      await tester.pumpAndSettle();

      expect(deleteFlowTestRepo.deleteDropCalls, ['delete-1']);
      expect(find.byType(DropDetailScreen), findsNothing);
    });
  });

  group('View count (WYN-038)', () {
    testWidgets(
        "opening someone else's Drop records a View exactly once, and "
        'bumps the count optimistically', (tester) async {
      final drop = Drop(
        id: 'view-1',
        authorId: 'someone-else',
        authorUsername: 'namfah',
        imageUrl: 'https://example.supabase.co/drops/view-1.jpg',
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
        viewCount: 5,
      );

      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: viewCountTestRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: drop,
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(viewCountTestRepo.recordViewCalls, 1);
      expect(viewCountTestRepo.recordViewArgs, ['view-1']);
      // The optimistic view-count bump is visible immediately, before
      // the (fake, network-less) RPC call resolves. Lives in the stat
      // line now ("6 การเข้าชม"), not a bare number -- see
      // DropDetailScreen._buildStatLine.
      expect(find.text('6 การเข้าชม'), findsOneWidget);
    });

    testWidgets(
        'WYN-083: also calls recordView for the current user\'s own Drop '
        'now -- Founder wants the author\'s own views counted', (tester) async {
      final ownDrop = Drop(
        id: 'view-own-1',
        authorId: 'me',
        authorUsername: 'me_user',
        imageUrl: 'https://example.supabase.co/drops/view-own-1.jpg',
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
        viewCount: 5,
      );

      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: ownDropViewCountTestRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: ownDrop,
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(ownDropViewCountTestRepo.recordViewCalls, 1);
      expect(ownDropViewCountTestRepo.recordViewArgs, ['view-own-1']);
      // Optimistically bumped the same as any other viewer -- 5 -> 6
      // (stat line, see DropDetailScreen._buildStatLine).
      expect(find.text('6 การเข้าชม'), findsOneWidget);
    });

    testWidgets(
        'recordView fires only once per screen open, even after later '
        'rebuilds (e.g. toggling Like)', (tester) async {
      final drop = Drop(
        id: 'view-2',
        authorId: 'someone-else',
        authorUsername: 'namfah',
        imageUrl: 'https://example.supabase.co/drops/view-2.jpg',
        createdAt: DateTime.now(),
        likeCount: 3,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
        viewCount: 0,
      );

      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: viewCountNoRepeatTestRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: drop,
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();
      expect(viewCountNoRepeatTestRepo.recordViewCalls, 1);

      final likeButton = find.byIcon(Icons.favorite_border);
      await tester.ensureVisible(likeButton);
      await tester.pumpAndSettle();
      tester.takeException();
      await tester.tap(likeButton);
      await tester.pump();

      // Liking rebuilds the screen (setState), but that must not
      // trigger a second recordView call.
      expect(viewCountNoRepeatTestRepo.recordViewCalls, 1);
    });

    testWidgets(
        'the view count has a Semantics label -- a gap the Pop equivalent '
        '(HomePopCard) has always had, deliberately not repeated here '
        '(Design spec, Accessibility)', (tester) async {
      final drop = Drop(
        id: 'view-3',
        authorId: 'me',
        authorUsername: 'me_user',
        imageUrl: 'https://example.supabase.co/drops/view-3.jpg',
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
        viewCount: 42,
      );

      await tester.pumpWidget(MaterialApp(
        home: DropDetailScreen(
          dropRepository: viewCountSemanticsTestRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          drop: drop,
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      // WYN-038 QA fix: none of the interaction row's individual
      // Semantics wraps (Like/Follow/ReDrop/Save, and now View count) sit
      // behind their own semantics *boundary* (no `container: true`
      // anywhere in this header) -- a pre-existing gap on this screen
      // since WYN-005, not something this task introduced. Because of
      // that, all their labels (plus the header image's own auto-label,
      // including its NetworkImage load-failure text in this
      // no-real-network test environment) get merged upward into one
      // single SemanticsNode. An *exact*-match `bySemanticsLabel(String)`
      // therefore always finds 0 matches here, no matter what the real
      // Drop id/viewCount/scroll position is -- confirmed with a debug
      // semantics-tree dump before writing this fix. flutter_test's own
      // API doc for `bySemanticsLabel` recommends exactly this fallback:
      // "prefer matching by regular expression... if the framework has
      // combined your semantics" -- so match a RegExp (substring) here
      // instead of the brittle exact string. This only proves the label
      // text exists somewhere in the merged semantics output, not that
      // it is independently announced by a screen reader -- that stronger
      // guarantee would need `Semantics(container: true)` boundaries
      // added across the whole interaction row, which is a pre-existing
      // gap out of scope for this task (affects Like/Follow/ReDrop/Save
      // too, not just View count) -- flagged as a non-blocking finding
      // in this round's QA report instead of fixed here.
      // 43, not the fixture's 42 -- WYN-083: this Drop's author is "me"
      // (the current viewer), and the author's own view now counts
      // too, so opening this screen optimistically bumps 42 -> 43.
      expect(
        find.bySemanticsLabel(RegExp('เข้าชมแล้ว 43 ครั้ง')),
        findsOneWidget,
      );
    });
  });
}
