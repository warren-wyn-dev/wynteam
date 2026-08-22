import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/moderation/data/appeal.dart';
import 'package:wyn/features/moderation/data/appeal_status.dart';
import 'package:wyn/features/moderation/data/moderation_action_type.dart';
import 'package:wyn/features/moderation/data/moderation_report.dart';
import 'package:wyn/features/moderation/data/moderation_target_summary.dart';
import 'package:wyn/features/moderation/presentation/appeal_detail_screen.dart';
import 'package:wyn/features/moderation/presentation/moderation_queue_screen.dart';
import 'package:wyn/features/moderation/presentation/moderation_report_detail_screen.dart';
import 'package:wyn/features/report/data/report_category.dart';
import 'package:wyn/features/report/data/report_target_type.dart';

import 'support/recording_appeal_repository.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_moderation_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

void main() {
  // Every RecordingXRepository built in setUp() (not inline inside a
  // testWidgets callback) -- each constructs a real SupabaseClient with
  // its own GoTrue auto-refresh Timer, and building one mid-test leaves
  // that Timer pending outside the fake-async zone flutter_test expects
  // it in. See .wyn/learning/PATTERNS.md and drop_comment_like_test.dart.
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingFollowRepository followRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingSavedRepository savedRepo;
  late RecordingClubRepository clubRepo;
  late RecordingClubPostRepository clubPostRepo;

  setUp(() {
    dropRepo = RecordingDropRepository();
    popRepo = RecordingPopRepository();
    followRepo = RecordingFollowRepository();
    profileRepo = RecordingProfileRepository();
    savedRepo = RecordingSavedRepository();
    clubRepo = RecordingClubRepository();
    clubPostRepo = RecordingClubPostRepository();
  });

  ModerationReport userReport({String id = 'r1'}) => ModerationReport(
        id: id,
        targetType: ReportTargetType.user,
        targetId: 'target-user-1',
        category: ReportCategory.harassment,
        detail: 'พฤติกรรมไม่เหมาะสม',
        status: 'pending',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

  Widget buildScreen(
    RecordingModerationRepository repository, {
    RecordingAppealRepository? appealRepository,
  }) =>
      MaterialApp(
        home: ModerationQueueScreen(
          moderationRepository: repository,
          appealRepository: appealRepository ?? RecordingAppealRepository(),
          currentModeratorId: 'moderator-1',
          dropRepository: dropRepo,
          popRepository: popRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          savedRepository: savedRepo,
          clubRepository: clubRepo,
          clubPostRepository: clubPostRepo,
        ),
      );

  testWidgets('empty state shows the inbox message, not a crash', (tester) async {
    final repo = RecordingModerationRepository(queuePages: const [[]]);
    await tester.pumpWidget(buildScreen(repo));
    await tester.pumpAndSettle();

    expect(find.text('ไม่มีรายงานที่รอตรวจสอบ'), findsOneWidget);
  });

  testWidgets('shows category · target type, the summary, and the reporter\'s '
      'detail text -- never the reporter\'s identity', (tester) async {
    final report = userReport();
    final repo = RecordingModerationRepository(
      queuePages: [
        [report],
      ],
      targetSummaries: {
        report.id: const ModerationTargetSummary(exists: true, label: '@somchai'),
      },
    );
    await tester.pumpWidget(buildScreen(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('คุกคาม/กลั่นแกล้ง (Harassment) · ผู้ใช้'), findsOneWidget);
    expect(find.text('@somchai'), findsOneWidget);
    expect(find.text('พฤติกรรมไม่เหมาะสม'), findsOneWidget);
  });

  testWidgets('tapping a row opens ModerationReportDetailScreen for that report',
      (tester) async {
    final report = userReport();
    final repo = RecordingModerationRepository(
      queuePages: [
        [report],
      ],
      targetSummaries: {
        report.id: const ModerationTargetSummary(exists: true, label: '@somchai'),
      },
    );
    await tester.pumpWidget(buildScreen(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('คุกคาม/กลั่นแกล้ง (Harassment) · ผู้ใช้'));
    await tester.pumpAndSettle();

    expect(find.byType(ModerationReportDetailScreen), findsOneWidget);
  });

  testWidgets(
      'returning from Detail with a result message removes that row (optimistic) '
      'and shows the SnackBar', (tester) async {
    final report = userReport();
    final repo = RecordingModerationRepository(
      queuePages: [
        [report],
      ],
      targetSummaries: {
        report.id: const ModerationTargetSummary(exists: true, label: '@somchai'),
      },
    );
    await tester.pumpWidget(buildScreen(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('คุกคาม/กลั่นแกล้ง (Harassment) · ผู้ใช้'));
    await tester.pumpAndSettle();

    // Simulate Detail popping with a result (as it does after a
    // successful ModerationActionSheet submit) by popping the route
    // directly with the exact string ModerationReportDetailScreen would.
    Navigator.of(tester.element(find.byType(ModerationReportDetailScreen)))
        .pop('ดำเนินการแล้ว: คำเตือน (Warning)');
    await tester.pumpAndSettle();

    expect(find.textContaining('คุกคาม/กลั่นแกล้ง (Harassment) · ผู้ใช้'), findsNothing);
    expect(find.text('ไม่มีรายงานที่รอตรวจสอบ'), findsOneWidget);
    expect(find.text('ดำเนินการแล้ว: คำเตือน (Warning)'), findsOneWidget);
  });

  // WYN-030 -- the "อุทธรณ์" tab, mirroring _ReportsTab's own 4 tests
  // above.
  group('Appeals tab', () {
    Appeal userAppeal({String id = 'a1'}) => Appeal(
          id: id,
          moderationActionId: 'action-1',
          reason: 'ฉันไม่ได้ทำผิดกฎ',
          status: AppealStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          actionType: ModerationActionType.restrict,
          actionReason: 'สแปม',
          actionCreatedAt: DateTime.now().subtract(const Duration(days: 1)),
          actionReportId: 'r1',
          actionTargetUserId: 'target-user-1',
          appellantUsername: 'somchai',
        );

    Future<void> goToAppealsTab(WidgetTester tester) async {
      await tester.tap(find.text('อุทธรณ์'));
      await tester.pumpAndSettle();
    }

    testWidgets('empty state shows the no-appeals message, not a crash', (tester) async {
      final repo = RecordingModerationRepository(queuePages: const [[]]);
      final appealRepo = RecordingAppealRepository(pendingAppealsPages: const [[]]);
      await tester.pumpWidget(buildScreen(repo, appealRepository: appealRepo));
      await tester.pumpAndSettle();
      await goToAppealsTab(tester);

      expect(find.text('ไม่มีอุทธรณ์ที่รอตรวจสอบ'), findsOneWidget);
    });

    testWidgets('shows the action type, appellant, and reason', (tester) async {
      final repo = RecordingModerationRepository(queuePages: const [[]]);
      final appeal = userAppeal();
      final appealRepo = RecordingAppealRepository(pendingAppealsPages: [
        [appeal],
      ]);
      await tester.pumpWidget(buildScreen(repo, appealRepository: appealRepo));
      await tester.pumpAndSettle();
      await goToAppealsTab(tester);

      expect(find.textContaining('อุทธรณ์: จำกัดสิทธิ์ (Restrict)'), findsOneWidget);
      expect(find.text('@somchai'), findsOneWidget);
      expect(find.text('ฉันไม่ได้ทำผิดกฎ'), findsOneWidget);
    });

    testWidgets('tapping a row opens AppealDetailScreen for that appeal', (tester) async {
      final repo = RecordingModerationRepository(queuePages: const [[]]);
      final appeal = userAppeal();
      final appealRepo = RecordingAppealRepository(pendingAppealsPages: [
        [appeal],
      ]);
      await tester.pumpWidget(buildScreen(repo, appealRepository: appealRepo));
      await tester.pumpAndSettle();
      await goToAppealsTab(tester);

      await tester.tap(find.textContaining('อุทธรณ์: จำกัดสิทธิ์ (Restrict)'));
      await tester.pumpAndSettle();

      expect(find.byType(AppealDetailScreen), findsOneWidget);
    });

    testWidgets(
        'returning from Detail with a result message removes that row (optimistic) '
        'and shows the SnackBar', (tester) async {
      final repo = RecordingModerationRepository(queuePages: const [[]]);
      final appeal = userAppeal();
      final appealRepo = RecordingAppealRepository(pendingAppealsPages: [
        [appeal],
      ]);
      await tester.pumpWidget(buildScreen(repo, appealRepository: appealRepo));
      await tester.pumpAndSettle();
      await goToAppealsTab(tester);

      await tester.tap(find.textContaining('อุทธรณ์: จำกัดสิทธิ์ (Restrict)'));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(AppealDetailScreen))).pop('อนุมัติอุทธรณ์แล้ว');
      await tester.pumpAndSettle();

      expect(find.textContaining('อุทธรณ์: จำกัดสิทธิ์ (Restrict)'), findsNothing);
      expect(find.text('ไม่มีอุทธรณ์ที่รอตรวจสอบ'), findsOneWidget);
      expect(find.text('อนุมัติอุทธรณ์แล้ว'), findsOneWidget);
    });
  });
}
