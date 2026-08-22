import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/moderation/data/moderation_action_type.dart';
import 'package:wyn/features/moderation/data/moderation_report.dart';
import 'package:wyn/features/moderation/data/moderation_target_summary.dart';
import 'package:wyn/features/moderation/presentation/moderation_report_detail_screen.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
import 'package:wyn/features/report/data/report_category.dart';
import 'package:wyn/features/report/data/report_target_type.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_moderation_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'moderator-1');
  });

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

  ModerationReport reportFor(ReportTargetType type, {String id = 'r1'}) => ModerationReport(
        id: id,
        targetType: type,
        targetId: 'target-1',
        category: ReportCategory.spam,
        detail: 'สแปม',
        status: 'pending',
        createdAt: DateTime.now(),
      );

  Widget buildScreen({
    required ModerationReport report,
    required RecordingModerationRepository moderationRepository,
  }) =>
      MaterialApp(
        home: ModerationReportDetailScreen(
          moderationRepository: moderationRepository,
          report: report,
          dropRepository: dropRepo,
          popRepository: popRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          savedRepository: savedRepo,
          clubRepository: clubRepo,
          clubPostRepository: clubPostRepo,
        ),
      );

  testWidgets(
      'shows all 6 action buttons for a drop target, in least-to-most-severe order',
      (tester) async {
    final report = reportFor(ReportTargetType.drop);
    final repo = RecordingModerationRepository(
      targetSummaries: {
        report.id: const ModerationTargetSummary(exists: true, label: 'แคปชัน'),
      },
    );
    await tester.pumpWidget(buildScreen(report: report, moderationRepository: repo));
    await tester.pumpAndSettle();

    for (final action in ModerationActionType.values) {
      expect(find.widgetWithText(OutlinedButton, action.label), findsOneWidget);
    }
  });

  testWidgets('hides "ลบเนื้อหา (Remove Content)" for a user target', (tester) async {
    final report = reportFor(ReportTargetType.user);
    final repo = RecordingModerationRepository(
      targetSummaries: {
        report.id: const ModerationTargetSummary(exists: true, label: '@somchai'),
      },
    );
    await tester.pumpWidget(buildScreen(report: report, moderationRepository: repo));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(OutlinedButton, ModerationActionType.removeContent.label),
      findsNothing,
    );
    expect(find.widgetWithText(OutlinedButton, ModerationActionType.warning.label), findsOneWidget);
  });

  testWidgets('hides "ลบเนื้อหา (Remove Content)" for a club target', (tester) async {
    final report = reportFor(ReportTargetType.club);
    final repo = RecordingModerationRepository(
      targetSummaries: {
        report.id: const ModerationTargetSummary(exists: true, label: 'ชมรมถ่ายภาพ'),
      },
    );
    await tester.pumpWidget(buildScreen(report: report, moderationRepository: repo));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(OutlinedButton, ModerationActionType.removeContent.label),
      findsNothing,
    );
  });

  testWidgets('tapping an action button opens ModerationActionSheet for that action',
      (tester) async {
    final report = reportFor(ReportTargetType.drop);
    final repo = RecordingModerationRepository(
      targetSummaries: {
        report.id: const ModerationTargetSummary(exists: true, label: 'แคปชัน'),
      },
    );
    await tester.pumpWidget(buildScreen(report: report, moderationRepository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, ModerationActionType.warning.label));
    await tester.pumpAndSettle();

    expect(find.text('ยืนยัน: ${ModerationActionType.warning.label}'), findsOneWidget);
  });

  testWidgets('a successful action pops this screen with a result message',
      (tester) async {
    final report = reportFor(ReportTargetType.drop);
    final repo = RecordingModerationRepository(
      targetSummaries: {
        report.id: const ModerationTargetSummary(exists: true, label: 'แคปชัน'),
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ModerationReportDetailScreen(
                  moderationRepository: repo,
                  report: report,
                  dropRepository: dropRepo,
                  popRepository: popRepo,
                  followRepository: followRepo,
                  profileRepository: profileRepo,
                  savedRepository: savedRepo,
                  clubRepository: clubRepo,
                  clubPostRepository: clubPostRepo,
                ),
              ),
            );
          },
          child: const Text('open detail'),
        ),
      ),
    ));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, ModerationActionType.warning.label));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'คำเตือน');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยัน'));
    await tester.pumpAndSettle();

    expect(find.byType(ModerationReportDetailScreen), findsNothing);
    expect(repo.applyActionCalls, 1);
  });

  testWidgets('tapping the content link for an existing user target opens ViewProfileScreen',
      (tester) async {
    final report = reportFor(ReportTargetType.user);
    final repo = RecordingModerationRepository(
      targetSummaries: {
        report.id: const ModerationTargetSummary(exists: true, label: '@somchai'),
      },
    );
    await tester.pumpWidget(buildScreen(report: report, moderationRepository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ผู้ใช้: @somchai'));
    await tester.pumpAndSettle();

    expect(find.byType(ViewProfileScreen), findsOneWidget);
  });

  testWidgets('tapping the content link for a deleted target shows a SnackBar, no navigation',
      (tester) async {
    final report = reportFor(ReportTargetType.user);
    final repo = RecordingModerationRepository(
      targetSummaries: {
        report.id: const ModerationTargetSummary(exists: false, label: '(บัญชีนี้ถูกลบไปแล้ว)'),
      },
    );
    await tester.pumpWidget(buildScreen(report: report, moderationRepository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('(บัญชีนี้ถูกลบไปแล้ว)'));
    await tester.pumpAndSettle();

    expect(find.byType(ViewProfileScreen), findsNothing);
    expect(find.text('บัญชีนี้ถูกลบไปแล้ว'), findsOneWidget);
  });
}
