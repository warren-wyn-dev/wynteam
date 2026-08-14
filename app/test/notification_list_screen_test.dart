import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/home/presentation/pop_single_clip_screen.dart';
import 'package:wyn/features/notification/data/notification.dart';
import 'package:wyn/features/notification/presentation/notification_list_screen.dart';
import 'package:wyn/features/pop/data/pop.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_notification_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

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
  late RecordingNotificationRepository deletedDropRepo;
  late RecordingNotificationRepository mixedReadRepo;

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
    // One unread, one already read before this visit -- lets the
    // highlight test tell a correctly-mapped snapshot apart from a
    // broken one (e.g. inverted, or not populated at all), rather than
    // asserting something that would hold regardless. See
    // .wyn/learning/PATTERNS.md.
    mixedReadRepo = RecordingNotificationRepository(notifications: [
      likeDropNotification(isRead: false),
      followNotification(isRead: true),
    ]);
  });

  Widget buildScreen(
    RecordingNotificationRepository notificationRepository, {
    RecordingDropRepository? dropRepository,
  }) =>
      MaterialApp(
        home: NotificationListScreen(
          notificationRepository: notificationRepository,
          dropRepository: dropRepository ?? dropRepo,
          popRepository: popRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          savedRepository: savedRepo,
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
}
