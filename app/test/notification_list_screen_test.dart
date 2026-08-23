import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/chat/presentation/conversation_screen.dart';
import 'package:wyn/features/club/data/club_post.dart';
import 'package:wyn/features/club/presentation/club_page.dart';
import 'package:wyn/features/club/presentation/club_post_detail_screen.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/home/presentation/pop_single_clip_screen.dart';
import 'package:wyn/features/notification/data/notification.dart';
import 'package:wyn/features/notification/presentation/notification_list_screen.dart';
import 'package:wyn/features/pop/data/pop.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
import 'package:wyn/features/profile/presentation/widgets/avatar_circle.dart';

import 'package:wyn/features/zoky/presentation/zoky_order_detail_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_chat_repository.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_notification_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';
import 'support/recording_appeal_repository.dart';
import 'support/recording_zoky_repository.dart';

void main() {
  // Every RecordingXRepository is built once per test in setUp() (not
  // inline inside a testWidgets callback) -- each constructs a real
  // SupabaseClient with its own GoTrue auto-refresh Timer, and building
  // one mid-test leaves that Timer pending outside the fake-async zone
  // flutter_test expects it in. See .wyn/learning/PATTERNS.md and
  // drop_comment_like_test.dart (WYN-005).
  late RecordingFollowRepository followRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingSavedRepository savedRepo;
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingDropRepository emptyDropRepo;
  late RecordingClubRepository clubRepo;
  late RecordingClubPostRepository clubPostRepo;
  late RecordingClubPostRepository clubPostWithResultRepo;
  late RecordingZokyRepository zokyRepo;
  late RecordingAppealRepository appealRepo;
  late RecordingChatRepository chatRepo;

  // One RecordingNotificationRepository per scenario, all built in
  // setUp() for the same reason as the repos above -- never inline
  // inside a testWidgets callback.
  late RecordingNotificationRepository allTypesRepo;
  late RecordingNotificationRepository emptyRepo;
  late RecordingNotificationRepository likeDropRepo;
  late RecordingNotificationRepository commentDropRepo;
  late RecordingNotificationRepository likePopRepo;
  late RecordingNotificationRepository commentPopRepo;
  late RecordingNotificationRepository followRepoNotif;
  late RecordingNotificationRepository messageRequestRepo;
  late RecordingNotificationRepository deletedDropRepo;
  late RecordingNotificationRepository mixedReadRepo;
  late RecordingNotificationRepository clubJoinRequestRepo;
  late RecordingNotificationRepository clubJoinApprovedRepo;
  late RecordingNotificationRepository clubPostLikeRepo;
  late RecordingNotificationRepository clubPostCommentRepo;
  late RecordingNotificationRepository deletedClubPostRepo;
  late RecordingNotificationRepository allNewClubTypesRepo;
  late RecordingNotificationRepository newOrderRepo;
  late RecordingNotificationRepository allOrderTypesRepo;
  late RecordingNotificationRepository allMentionTypesRepo;
  late RecordingNotificationRepository mentionDropRepo;
  late RecordingNotificationRepository mentionClubPostRepo;
  late RecordingNotificationRepository allModerationTypesRepo;
  late RecordingNotificationRepository moderationWarningRepo;
  late RecordingNotificationRepository moderationContentRemovedRepo;
  late RecordingNotificationRepository allModerationTypesNullActorRepo;

  final now = DateTime.now();

  WynNotification likeDropNotification({bool isRead = false}) => WynNotification(
        id: 'n-like-drop',
        type: NotificationType.likeDrop,
        actorId: 'u1',
        actorUsername: 'namfah',
        actorDisplayName: 'น้ำฝน',
        dropId: 'd1',
        isRead: isRead,
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

  WynNotification commentDropNotification() => WynNotification(
        id: 'n-comment-drop',
        type: NotificationType.commentDrop,
        actorId: 'u1',
        actorUsername: 'namfah',
        actorDisplayName: 'น้ำฝน',
        dropId: 'd1',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

  WynNotification likePopNotification() => WynNotification(
        id: 'n-like-pop',
        type: NotificationType.likePop,
        actorId: 'u2',
        actorUsername: 'ploy',
        popId: 'p1',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 2)),
      );

  WynNotification commentPopNotification() => WynNotification(
        id: 'n-comment-pop',
        type: NotificationType.commentPop,
        actorId: 'u2',
        actorUsername: 'ploy',
        popId: 'p1',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 2)),
      );

  WynNotification followNotification({bool isRead = false}) => WynNotification(
        id: 'n-follow',
        type: NotificationType.follow,
        actorId: 'u3',
        actorUsername: 'benz',
        isRead: isRead,
        createdAt: now.subtract(const Duration(days: 2)),
      );

  WynNotification messageRequestNotification() => WynNotification(
        id: 'n-message-request',
        type: NotificationType.messageRequest,
        actorId: 'u6',
        actorUsername: 'namfah',
        actorDisplayName: 'น้ำฝน',
        conversationId: 'conv-1',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

  WynNotification clubJoinRequestNotification() => WynNotification(
        id: 'n-club-join-request',
        type: NotificationType.clubJoinRequest,
        actorId: 'u4',
        actorUsername: 'gam',
        clubId: 'club-1',
        clubName: 'ชมรมถ่ายภาพ',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

  WynNotification clubJoinApprovedNotification() => WynNotification(
        id: 'n-club-join-approved',
        type: NotificationType.clubJoinApproved,
        actorId: 'u5',
        actorUsername: 'owner_user',
        clubId: 'club-1',
        clubName: 'ชมรมถ่ายภาพ',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 15)),
      );

  WynNotification clubPostLikeNotification() => WynNotification(
        id: 'n-club-post-like',
        type: NotificationType.clubPostLike,
        actorId: 'u4',
        actorUsername: 'gam',
        clubId: 'club-1',
        clubName: 'ชมรมถ่ายภาพ',
        clubPostId: 'cp1',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 20)),
      );

  WynNotification clubPostCommentNotification() => WynNotification(
        id: 'n-club-post-comment',
        type: NotificationType.clubPostComment,
        actorId: 'u4',
        actorUsername: 'gam',
        clubId: 'club-1',
        clubName: 'ชมรมถ่ายภาพ',
        clubPostId: 'cp1',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 25)),
      );

  WynNotification mentionDropNotification() => WynNotification(
        id: 'n-mention-drop',
        type: NotificationType.mentionDrop,
        actorId: 'u4',
        actorUsername: 'gam',
        dropId: 'd1',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

  WynNotification mentionClubPostNotification() => WynNotification(
        id: 'n-mention-club-post',
        type: NotificationType.mentionClubPost,
        actorId: 'u4',
        actorUsername: 'gam',
        clubId: 'club-1',
        clubName: 'ชมรมถ่ายภาพ',
        clubPostId: 'cp1',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 6)),
      );

  // WYN-029 -- actorId/actorUsername deliberately set to the *reviewer's*
  // real identity here (mirroring what apply_moderation_action() really
  // stores in actor_id, per supabase/schema.sql), specifically so the
  // tests below can prove NotificationListScreen never surfaces it, not
  // just that it happens not to be present in the fixture.
  WynNotification moderationWarningNotification() => WynNotification(
        id: 'n-moderation-warning',
        type: NotificationType.moderationWarning,
        actorId: 'reviewer-1',
        actorUsername: 'moderator_somchai',
        reason: 'สแปมซ้ำหลายครั้ง',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 2)),
      );

  WynNotification moderationContentRemovedNotification() => WynNotification(
        id: 'n-moderation-content-removed',
        type: NotificationType.moderationContentRemoved,
        actorId: 'reviewer-1',
        actorUsername: 'moderator_somchai',
        dropId: 'd1',
        reason: 'เนื้อหาผิดกฎหมาย',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 1)),
      );

  // WYN-029 fix (.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md)
  // -- this is what these 2 types actually look like post-fix: actorId/
  // actorUsername/actorDisplayName genuinely null (apply_moderation_action()
  // now inserts actor_id = NULL), not just a real actor the screen chooses
  // to hide. The fixtures above (with a real reviewer identity) stay as
  // they are -- they still prove the UI-layer guard works even if a row
  // somehow carried a real actor -- these prove the screen also survives
  // the actual null-actor shape without crashing.
  WynNotification moderationWarningNullActorNotification() => WynNotification(
        id: 'n-moderation-warning-null-actor',
        type: NotificationType.moderationWarning,
        reason: 'สแปมซ้ำหลายครั้ง',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 2)),
      );

  WynNotification moderationContentRemovedNullActorNotification() =>
      WynNotification(
        id: 'n-moderation-content-removed-null-actor',
        type: NotificationType.moderationContentRemoved,
        reason: 'เนื้อหาผิดกฎหมาย',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 1)),
      );

  WynNotification newOrderNotification() => WynNotification(
        id: 'n-new-order',
        type: NotificationType.newOrder,
        actorId: 'u6',
        actorUsername: 'buyer_user',
        orderId: 'order-1',
        orderStoreName: 'ร้านทดสอบ',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 3)),
      );

  WynNotification orderShippedNotification() => WynNotification(
        id: 'n-order-shipped',
        type: NotificationType.orderShipped,
        actorId: 'u7',
        actorUsername: 'seller_user',
        orderId: 'order-1',
        orderStoreName: 'ร้านทดสอบ',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 4)),
      );

  WynNotification orderCancelledNotification() => WynNotification(
        id: 'n-order-cancelled',
        type: NotificationType.orderCancelled,
        actorId: 'u7',
        actorUsername: 'seller_user',
        orderId: 'order-1',
        orderStoreName: 'ร้านทดสอบ',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 6)),
      );

  WynNotification orderRefundedNotification() => WynNotification(
        id: 'n-order-refunded',
        type: NotificationType.orderRefunded,
        actorId: 'u7',
        actorUsername: 'seller_user',
        orderId: 'order-1',
        orderStoreName: 'ร้านทดสอบ',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 7)),
      );

  final testDrop = Drop(
    id: 'd1',
    authorId: 'me',
    authorUsername: 'me_user',
    imageUrl: 'https://example.supabase.co/drops/d1.jpg',
    createdAt: now,
    likeCount: 1,
    commentCount: 0,
    likedByMe: false,
    savedByMe: false,
  );

  final testPop = Pop(
    id: 'p1',
    authorId: 'me',
    authorUsername: 'me_user',
    videoUrl: 'https://example.supabase.co/pops/p1.mp4',
    durationSeconds: 15,
    viewCount: 0,
    createdAt: now,
    likeCount: 1,
    commentCount: 0,
    likedByMe: false,
    savedByMe: false,
  );

  final testClubPost = ClubPost(
    id: 'cp1',
    clubId: 'club-1',
    authorId: 'me',
    authorUsername: 'me_user',
    content: 'สวัสดีชาว Club',
    pinned: false,
    createdAt: now,
    likeCount: 1,
    commentCount: 0,
    likedByMe: false,
    savedByMe: false,
  );

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    followRepo = RecordingFollowRepository();
    profileRepo = RecordingProfileRepository();
    savedRepo = RecordingSavedRepository();
    dropRepo = RecordingDropRepository(feedDrops: [testDrop]);
    popRepo = RecordingPopRepository(feedPops: [testPop]);
    // Deliberately empty -- simulates a Drop deleted since the
    // notification was created.
    emptyDropRepo = RecordingDropRepository(feedDrops: []);
    clubRepo = RecordingClubRepository();
    clubPostRepo = RecordingClubPostRepository();
    clubPostWithResultRepo = RecordingClubPostRepository()..byIdResult = testClubPost;
    zokyRepo = RecordingZokyRepository();
    appealRepo = RecordingAppealRepository();
    chatRepo = RecordingChatRepository();

    allTypesRepo = RecordingNotificationRepository(notifications: [
      likeDropNotification(),
      commentDropNotification(),
      likePopNotification(),
      commentPopNotification(),
      followNotification(),
    ]);
    emptyRepo = RecordingNotificationRepository(notifications: []);
    likeDropRepo = RecordingNotificationRepository(
      notifications: [likeDropNotification()],
    );
    commentDropRepo = RecordingNotificationRepository(
      notifications: [commentDropNotification()],
    );
    likePopRepo = RecordingNotificationRepository(
      notifications: [likePopNotification()],
    );
    commentPopRepo = RecordingNotificationRepository(
      notifications: [commentPopNotification()],
    );
    followRepoNotif = RecordingNotificationRepository(
      notifications: [followNotification()],
    );
    deletedDropRepo = RecordingNotificationRepository(
      notifications: [likeDropNotification()],
    );
    messageRequestRepo = RecordingNotificationRepository(
      notifications: [messageRequestNotification()],
    );
    // One unread, one already read before this visit -- lets the
    // highlight test tell a correctly-mapped snapshot apart from a
    // broken one (e.g. inverted, or not populated at all), rather than
    // asserting something that would hold regardless. See
    // .wyn/learning/PATTERNS.md.
    mixedReadRepo = RecordingNotificationRepository(notifications: [
      likeDropNotification(isRead: false),
      followNotification(isRead: true),
    ]);
    clubJoinRequestRepo =
        RecordingNotificationRepository(notifications: [clubJoinRequestNotification()]);
    clubJoinApprovedRepo =
        RecordingNotificationRepository(notifications: [clubJoinApprovedNotification()]);
    clubPostLikeRepo =
        RecordingNotificationRepository(notifications: [clubPostLikeNotification()]);
    clubPostCommentRepo =
        RecordingNotificationRepository(notifications: [clubPostCommentNotification()]);
    deletedClubPostRepo =
        RecordingNotificationRepository(notifications: [clubPostLikeNotification()]);
    allNewClubTypesRepo = RecordingNotificationRepository(notifications: [
      clubJoinRequestNotification(),
      clubJoinApprovedNotification(),
      clubPostLikeNotification(),
      clubPostCommentNotification(),
    ]);
    newOrderRepo = RecordingNotificationRepository(notifications: [newOrderNotification()]);
    allOrderTypesRepo = RecordingNotificationRepository(notifications: [
      newOrderNotification(),
      orderShippedNotification(),
      orderCancelledNotification(),
      orderRefundedNotification(),
    ]);
    allMentionTypesRepo = RecordingNotificationRepository(notifications: [
      mentionDropNotification(),
      mentionClubPostNotification(),
    ]);
    mentionDropRepo = RecordingNotificationRepository(notifications: [mentionDropNotification()]);
    mentionClubPostRepo =
        RecordingNotificationRepository(notifications: [mentionClubPostNotification()]);
    allModerationTypesRepo = RecordingNotificationRepository(notifications: [
      moderationWarningNotification(),
      moderationContentRemovedNotification(),
    ]);
    moderationWarningRepo =
        RecordingNotificationRepository(notifications: [moderationWarningNotification()]);
    moderationContentRemovedRepo =
        RecordingNotificationRepository(notifications: [moderationContentRemovedNotification()]);
    allModerationTypesNullActorRepo = RecordingNotificationRepository(notifications: [
      moderationWarningNullActorNotification(),
      moderationContentRemovedNullActorNotification(),
    ]);
  });

  Widget buildScreen(
    RecordingNotificationRepository notificationRepository, {
    RecordingDropRepository? dropRepository,
    RecordingClubPostRepository? clubPostRepository,
    RecordingZokyRepository? zokyRepository,
  }) =>
      MaterialApp(
        home: NotificationListScreen(
          notificationRepository: notificationRepository,
          dropRepository: dropRepository ?? dropRepo,
          popRepository: popRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          savedRepository: savedRepo,
          clubRepository: clubRepo,
          clubPostRepository: clubPostRepository ?? clubPostRepo,
          zokyRepository: zokyRepository ?? zokyRepo,
          appealRepository: appealRepo,
          chatRepository: chatRepo,
        ),
      );

  testWidgets('shows type-specific Thai messages for all 5 notification '
      'types', (tester) async {
    await tester.pumpWidget(buildScreen(allTypesRepo));
    await tester.pumpAndSettle();

    expect(find.text('น้ำฝน ถูกใจ Drop ของคุณ'), findsOneWidget);
    expect(find.text('น้ำฝน แสดงความคิดเห็นใน Drop ของคุณ'), findsOneWidget);
    expect(find.text('@ploy ถูกใจ Pop ของคุณ'), findsOneWidget);
    expect(find.text('@ploy แสดงความคิดเห็นใน Pop ของคุณ'), findsOneWidget);
    expect(find.text('@benz เริ่มติดตามคุณ'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no notifications',
      (tester) async {
    await tester.pumpWidget(buildScreen(emptyRepo));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีการแจ้งเตือน'), findsOneWidget);
  });

  testWidgets('calls markAllAsRead once after the initial fetch succeeds',
      (tester) async {
    await tester.pumpWidget(buildScreen(likeDropRepo));
    await tester.pumpAndSettle();

    expect(likeDropRepo.markAllAsReadCalls, 1);
  });

  testWidgets(
      'a row that was unread at fetch time is highlighted and a row that '
      'was already read is not -- and the unread one keeps its highlight '
      'for this visit even after markAllAsRead completes in the '
      'background', (tester) async {
    await tester.pumpWidget(buildScreen(mixedReadRepo));
    await tester.pumpAndSettle();
    // markAllAsRead is a fire-and-forget call; pumpAndSettle already lets
    // it complete. The unread row's highlight comes from a snapshot taken
    // at fetch time, not a live read of WynNotification.isRead, so it
    // must still be there even though the DB row is now marked read.
    expect(mixedReadRepo.markAllAsReadCalls, 1);

    final unreadContainer = tester.widget<Container>(
      find.ancestor(
        of: find.text('น้ำฝน ถูกใจ Drop ของคุณ'),
        matching: find.byType(Container),
      ),
    );
    final readContainer = tester.widget<Container>(
      find.ancestor(
        of: find.text('@benz เริ่มติดตามคุณ'),
        matching: find.byType(Container),
      ),
    );
    expect(unreadContainer.color, isNotNull);
    expect(readContainer.color, isNull);
  });

  testWidgets('tapping a Like Drop notification opens DropDetailScreen',
      (tester) async {
    await tester.pumpWidget(buildScreen(likeDropRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('น้ำฝน ถูกใจ Drop ของคุณ'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(DropDetailScreen), findsOneWidget);
  });

  testWidgets('tapping a Comment Drop notification opens DropDetailScreen',
      (tester) async {
    await tester.pumpWidget(buildScreen(commentDropRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('น้ำฝน แสดงความคิดเห็นใน Drop ของคุณ'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(DropDetailScreen), findsOneWidget);
  });

  testWidgets('tapping a Like Pop notification opens PopSingleClipScreen',
      (tester) async {
    await tester.pumpWidget(buildScreen(likePopRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('@ploy ถูกใจ Pop ของคุณ'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(PopSingleClipScreen), findsOneWidget);
  });

  testWidgets('tapping a Comment Pop notification opens PopSingleClipScreen',
      (tester) async {
    await tester.pumpWidget(buildScreen(commentPopRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('@ploy แสดงความคิดเห็นใน Pop ของคุณ'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(PopSingleClipScreen), findsOneWidget);
  });

  testWidgets('tapping a Follow notification opens ViewProfileScreen',
      (tester) async {
    await tester.pumpWidget(buildScreen(followRepoNotif));
    await tester.pumpAndSettle();

    await tester.tap(find.text('@benz เริ่มติดตามคุณ'));
    await tester.pumpAndSettle();

    final screen = tester.widget<ViewProfileScreen>(
      find.byType(ViewProfileScreen),
    );
    expect(screen.userId, 'u3');
  });

  group('message_request notification (WYN-032)', () {
    testWidgets('shows the Thai message with the actor\'s name', (tester) async {
      await tester.pumpWidget(buildScreen(messageRequestRepo));
      await tester.pumpAndSettle();

      expect(find.text('น้ำฝน ส่งคำขอข้อความถึงคุณ'), findsOneWidget);
    });

    testWidgets('tapping opens ConversationScreen directly for that conversation',
        (tester) async {
      await tester.pumpWidget(buildScreen(messageRequestRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('น้ำฝน ส่งคำขอข้อความถึงคุณ'));
      await tester.pumpAndSettle();

      final screen = tester.widget<ConversationScreen>(find.byType(ConversationScreen));
      expect(screen.conversationId, 'conv-1');
      expect(screen.otherUserId, 'u6');
      expect(screen.otherUsername, 'namfah');
    });
  });

  group('Club notification types (WYN-015)', () {
    testWidgets('shows type-specific Thai messages including the club name for all 4 '
        'new types', (tester) async {
      await tester.pumpWidget(buildScreen(allNewClubTypesRepo));
      await tester.pumpAndSettle();

      expect(find.text('@gam ขอเข้าร่วม ชมรมถ่ายภาพ ของคุณ'), findsOneWidget);
      expect(
        find.text('@owner_user อนุมัติคำขอเข้าร่วม ชมรมถ่ายภาพ ของคุณแล้ว'),
        findsOneWidget,
      );
      expect(find.text('@gam ถูกใจโพสต์ของคุณใน ชมรมถ่ายภาพ'), findsOneWidget);
      expect(
        find.text('@gam แสดงความคิดเห็นในโพสต์ของคุณใน ชมรมถ่ายภาพ'),
        findsOneWidget,
      );
    });

    // The Design spec calls for club_join_request to open straight to
    // the Members tab (index 1), not the default Posts tab, so the
    // pending request is immediately visible.
    testWidgets('tapping a club_join_request notification opens ClubPage on the '
        'Members tab', (tester) async {
      await tester.pumpWidget(buildScreen(clubJoinRequestRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('@gam ขอเข้าร่วม ชมรมถ่ายภาพ ของคุณ'));
      await tester.pumpAndSettle();

      final screen = tester.widget<ClubPage>(find.byType(ClubPage));
      expect(screen.clubId, 'club-1');
      expect(screen.initialTabIndex, 1);
    });

    testWidgets('tapping a club_join_approved notification opens ClubPage on the '
        'default Posts tab', (tester) async {
      await tester.pumpWidget(buildScreen(clubJoinApprovedRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('@owner_user อนุมัติคำขอเข้าร่วม ชมรมถ่ายภาพ ของคุณแล้ว'));
      await tester.pumpAndSettle();

      final screen = tester.widget<ClubPage>(find.byType(ClubPage));
      expect(screen.clubId, 'club-1');
      expect(screen.initialTabIndex, 0);
    });

    testWidgets('tapping a club_post_like notification opens ClubPostDetailScreen',
        (tester) async {
      await tester.pumpWidget(buildScreen(
        clubPostLikeRepo,
        clubPostRepository: clubPostWithResultRepo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('@gam ถูกใจโพสต์ของคุณใน ชมรมถ่ายภาพ'));
      await tester.pumpAndSettle();

      expect(find.byType(ClubPostDetailScreen), findsOneWidget);
    });

    testWidgets('tapping a club_post_comment notification opens ClubPostDetailScreen',
        (tester) async {
      await tester.pumpWidget(buildScreen(
        clubPostCommentRepo,
        clubPostRepository: clubPostWithResultRepo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('@gam แสดงความคิดเห็นในโพสต์ของคุณใน ชมรมถ่ายภาพ'));
      await tester.pumpAndSettle();

      expect(find.byType(ClubPostDetailScreen), findsOneWidget);
    });

    testWidgets(
        'tapping a notification whose club post was already deleted shows a '
        'SnackBar instead of opening ClubPostDetailScreen', (tester) async {
      // clubPostRepo (the default) has byIdResult unset (null) --
      // simulates the post having been deleted since the notification
      // was created.
      await tester.pumpWidget(buildScreen(deletedClubPostRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('@gam ถูกใจโพสต์ของคุณใน ชมรมถ่ายภาพ'));
      await tester.pumpAndSettle();

      expect(find.text('โพสต์นี้ถูกลบไปแล้ว'), findsOneWidget);
      expect(find.byType(ClubPostDetailScreen), findsNothing);
    });
  });

  testWidgets(
      'tapping a notification whose Drop was already deleted shows a '
      'message instead of crashing or navigating', (tester) async {
    await tester.pumpWidget(buildScreen(deletedDropRepo, dropRepository: emptyDropRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('น้ำฝน ถูกใจ Drop ของคุณ'));
    await tester.pumpAndSettle();

    expect(find.text('Drop นี้ถูกลบไปแล้ว'), findsOneWidget);
    expect(find.byType(DropDetailScreen), findsNothing);
  });

  group('Order notification types (ZOKY-005 R1)', () {
    testWidgets('shows type-specific Thai messages including the store name for all '
        '4 new types', (tester) async {
      await tester.pumpWidget(buildScreen(allOrderTypesRepo));
      await tester.pumpAndSettle();

      expect(find.text('@buyer_user สั่งซื้อสินค้าจาก ร้านทดสอบ'), findsOneWidget);
      expect(find.text('คำสั่งซื้อของคุณจาก ร้านทดสอบ ถูกจัดส่งแล้ว'), findsOneWidget);
      expect(find.text('คำสั่งซื้อจากร้าน ร้านทดสอบ ถูกยกเลิก'), findsOneWidget);
      expect(find.text('คำสั่งซื้อของคุณจาก ร้านทดสอบ ถูกคืนเงินแล้ว'), findsOneWidget);
    });

    testWidgets('tapping a new_order notification opens ZokyOrderDetailScreen',
        (tester) async {
      await tester.pumpWidget(buildScreen(newOrderRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('@buyer_user สั่งซื้อสินค้าจาก ร้านทดสอบ'));
      await tester.pumpAndSettle();

      final screen = tester.widget<ZokyOrderDetailScreen>(find.byType(ZokyOrderDetailScreen));
      expect(screen.orderId, 'order-1');
    });
  });

  group('Mention notification types (WYN-021)', () {
    testWidgets('shows type-specific Thai messages for both mention types',
        (tester) async {
      await tester.pumpWidget(buildScreen(allMentionTypesRepo));
      await tester.pumpAndSettle();

      expect(find.text('@gam กล่าวถึงคุณใน Drop'), findsOneWidget);
      expect(find.text('@gam กล่าวถึงคุณในโพสต์ที่ ชมรมถ่ายภาพ'), findsOneWidget);
    });

    testWidgets('tapping a mention_drop notification opens DropDetailScreen',
        (tester) async {
      await tester.pumpWidget(buildScreen(mentionDropRepo));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('@gam กล่าวถึงคุณใน Drop'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(DropDetailScreen), findsOneWidget);
    });

    testWidgets('tapping a mention_club_post notification opens ClubPostDetailScreen',
        (tester) async {
      await tester.pumpWidget(buildScreen(
        mentionClubPostRepo,
        clubPostRepository: clubPostWithResultRepo,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('@gam กล่าวถึงคุณในโพสต์ที่ ชมรมถ่ายภาพ'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(ClubPostDetailScreen), findsOneWidget);
    });
  });

  group('Moderation notification types (WYN-029)', () {
    testWidgets('shows type-specific Thai messages including the reason for both types',
        (tester) async {
      await tester.pumpWidget(buildScreen(allModerationTypesRepo));
      await tester.pumpAndSettle();

      expect(
        find.text('คุณได้รับคำเตือนจากทีมงาน WYN: สแปมซ้ำหลายครั้ง'),
        findsOneWidget,
      );
      expect(
        find.text(
          'เนื้อหาของคุณถูกลบเนื่องจากละเมิดกฎการใช้งาน WYN -- เหตุผล: เนื้อหาผิดกฎหมาย',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'never shows the reviewer\'s real identity -- no AvatarCircle, no '
        'username text anywhere in the row, for either type', (tester) async {
      await tester.pumpWidget(buildScreen(allModerationTypesRepo));
      await tester.pumpAndSettle();

      // AvatarCircle is what every *other* notification type renders --
      // its total absence here (not just "hidden behind something else")
      // is the actual guarantee: the reviewer's avatar/username never
      // reaches the widget tree at all for these 2 types.
      expect(find.byType(AvatarCircle), findsNothing);
      expect(find.byIcon(Icons.shield_outlined), findsNWidgets(2));
      // The fixtures' actor username would appear as "@moderator_somchai"
      // if _messageFor ever used actorNameOrUsername for these types --
      // it must not, per the design doc's Screen 5.
      expect(find.textContaining('moderator_somchai'), findsNothing);
    });

    testWidgets('tapping a moderation_warning notification does nothing (no navigation)',
        (tester) async {
      await tester.pumpWidget(buildScreen(moderationWarningRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('คุณได้รับคำเตือนจากทีมงาน WYN: สแปมซ้ำหลายครั้ง'));
      await tester.pumpAndSettle();
      tester.takeException();

      // Still on NotificationListScreen -- nothing was pushed.
      expect(find.byType(NotificationListScreen), findsOneWidget);
      expect(find.byType(DropDetailScreen), findsNothing);
    });

    testWidgets(
        'tapping a moderation_content_removed notification does nothing, even '
        'though this fixture (unrealistically) carries a dropId', (tester) async {
      await tester.pumpWidget(buildScreen(moderationContentRemovedRepo));
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('เนื้อหาของคุณถูกลบเนื่องจากละเมิดกฎการใช้งาน WYN -- เหตุผล: เนื้อหาผิดกฎหมาย'),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(NotificationListScreen), findsOneWidget);
      expect(find.byType(DropDetailScreen), findsNothing);
    });

    // WYN-029 fix regression coverage
    // (.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md) -- proves
    // the screen renders correctly, without crashing, for the *actual*
    // post-fix shape of these 2 types (actorId/actorUsername/
    // actorDisplayName genuinely null, not just a real actor the screen
    // declines to show).
    testWidgets(
        'renders both types correctly with no crash when actorId/'
        'actorUsername/actorDisplayName are genuinely null (the real '
        'post-fix shape, not just a hidden real actor)', (tester) async {
      await tester.pumpWidget(buildScreen(allModerationTypesNullActorRepo));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        find.text('คุณได้รับคำเตือนจากทีมงาน WYN: สแปมซ้ำหลายครั้ง'),
        findsOneWidget,
      );
      expect(
        find.text(
          'เนื้อหาของคุณถูกลบเนื่องจากละเมิดกฎการใช้งาน WYN -- เหตุผล: เนื้อหาผิดกฎหมาย',
        ),
        findsOneWidget,
      );
      expect(find.byType(AvatarCircle), findsNothing);
      expect(find.byIcon(Icons.shield_outlined), findsNWidgets(2));

      // Tapping still does nothing (no navigation, no crash from a null
      // actorId anywhere on the no-op path either).
      await tester.tap(
        find.text('คุณได้รับคำเตือนจากทีมงาน WYN: สแปมซ้ำหลายครั้ง'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(NotificationListScreen), findsOneWidget);
    });
  });
}
