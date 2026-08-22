import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/moderation/data/appeal.dart';
import 'package:wyn/features/moderation/data/appeal_status.dart';
import 'package:wyn/features/moderation/data/moderation_action_type.dart';
import 'package:wyn/features/moderation/presentation/appeal_detail_screen.dart';

import 'support/recording_appeal_repository.dart';

void main() {
  late RecordingAppealRepository appealRepo;

  setUp(() {
    appealRepo = RecordingAppealRepository();
  });

  Appeal buildAppeal({
    String id = 'appeal-1',
    List<String>? evidencePaths,
    String actionTargetUserId = 'target-user-1',
  }) =>
      Appeal(
        id: id,
        moderationActionId: 'action-1',
        reason: 'ฉันไม่ได้ทำผิดกฎ',
        evidencePaths: evidencePaths,
        status: AppealStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        actionType: ModerationActionType.restrict,
        actionReason: 'สแปม',
        actionCreatedAt: DateTime.now().subtract(const Duration(days: 1)),
        actionReportId: 'r1',
        actionTargetUserId: actionTargetUserId,
        actionReviewerUsername: 'moderator_a',
        appellantUsername: 'somchai',
        appellantDisplayName: 'Somchai',
      );

  Widget buildScreen(Appeal appeal, {String? currentModeratorId = 'moderator-1'}) => MaterialApp(
        home: AppealDetailScreen(
          appealRepository: appealRepo,
          appeal: appeal,
          currentModeratorId: currentModeratorId,
        ),
      );

  testWidgets('shows the original action, appellant identity, and appeal reason -- '
      'never the appellant\'s reviewer id itself', (tester) async {
    await tester.pumpWidget(buildScreen(buildAppeal()));
    await tester.pumpAndSettle();

    expect(find.textContaining('บทลงโทษเดิม: จำกัดสิทธิ์ (Restrict)'), findsOneWidget);
    expect(find.text('สแปม'), findsOneWidget);
    expect(find.text('Somchai (@somchai)'), findsOneWidget);
    expect(find.text('ฉันไม่ได้ทำผิดกฎ'), findsOneWidget);
    expect(find.text('ผู้ดำเนินการ: @moderator_a'), findsOneWidget);
  });

  testWidgets('Approve/Reject buttons visible for a normal (non-self) review',
      (tester) async {
    await tester.pumpWidget(buildScreen(buildAppeal()));
    await tester.pumpAndSettle();

    expect(find.text('อนุมัติ'), findsOneWidget);
    expect(find.text('ปฏิเสธ'), findsOneWidget);
  });

  // The self-review guard -- WYN-030's design doc explicitly calls this
  // out. UI-level defense only; the real boundary is decide_appeal()
  // itself raising an exception (see supabase/schema.sql).
  testWidgets(
      'self-review: currentModeratorId == the moderation action\'s target hides '
      'both Approve and Reject', (tester) async {
    await tester.pumpWidget(buildScreen(
      buildAppeal(actionTargetUserId: 'moderator-1'),
      currentModeratorId: 'moderator-1',
    ));
    await tester.pumpAndSettle();

    expect(find.text('อนุมัติ'), findsNothing);
    expect(find.text('ปฏิเสธ'), findsNothing);
    expect(
      find.text('คุณไม่สามารถตัดสินอุทธรณ์นี้ได้ เนื่องจากเป็นบทลงโทษที่มีต่อบัญชีของคุณเอง'),
      findsOneWidget,
    );
  });

  testWidgets('a null currentModeratorId is never treated as a self-review match',
      (tester) async {
    await tester.pumpWidget(buildScreen(
      buildAppeal(actionTargetUserId: 'target-user-1'),
      currentModeratorId: null,
    ));
    await tester.pumpAndSettle();

    expect(find.text('อนุมัติ'), findsOneWidget);
    expect(find.text('ปฏิเสธ'), findsOneWidget);
  });

  testWidgets('tapping อนุมัติ then confirming pops with an approved message',
      (tester) async {
    await tester.pumpWidget(buildScreen(buildAppeal()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('อนุมัติ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยืนยัน'));
    await tester.pumpAndSettle();

    expect(appealRepo.decideAppealCalls, 1);
    expect(appealRepo.lastDecideAppealApprove, isTrue);
    expect(find.byType(AppealDetailScreen), findsNothing);
  });

  testWidgets('a decide-race (already decided by someone else) pops with that message',
      (tester) async {
    appealRepo.decideAppealError = Exception('This appeal has already been decided');

    String? poppedMessage;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            poppedMessage = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => AppealDetailScreen(
                  appealRepository: appealRepo,
                  appeal: buildAppeal(),
                  currentModeratorId: 'moderator-1',
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('อนุมัติ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยืนยัน'));
    await tester.pumpAndSettle();

    expect(poppedMessage, 'อุทธรณ์นี้ถูกตัดสินไปแล้วโดยผู้ตรวจสอบคนอื่น');
  });

  testWidgets('evidence thumbnails render when the appeal has evidence paths',
      (tester) async {
    await tester.pumpWidget(buildScreen(
      buildAppeal(evidencePaths: ['user-1/123-0.jpg', 'user-1/123-1.jpg']),
    ));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('หลักฐานรูปที่ 1'), findsOneWidget);
    expect(find.bySemanticsLabel('หลักฐานรูปที่ 2'), findsOneWidget);
  });
}
