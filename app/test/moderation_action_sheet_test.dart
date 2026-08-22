import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/moderation/data/moderation_action_type.dart';
import 'package:wyn/features/moderation/presentation/moderation_action_sheet.dart';

import 'support/recording_moderation_repository.dart';

void main() {
  Future<ModerationActionSheetOutcome?> openSheet(
    WidgetTester tester, {
    required RecordingModerationRepository repository,
    required ModerationActionType actionType,
  }) async {
    ModerationActionSheetOutcome? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showModerationActionSheet(
                context,
                moderationRepository: repository,
                reportId: 'r1',
                actionType: actionType,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets(
      'No Action -- confirm stays disabled until a reason is typed, no duration '
      'picker shown', (tester) async {
    final repo = RecordingModerationRepository();
    await openSheet(tester, repository: repo, actionType: ModerationActionType.noAction);

    expect(find.text('ระยะเวลา'), findsNothing);
    final confirmButton = find.widgetWithText(FilledButton, 'ยืนยัน');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'ปิดเคส ไม่มีปัญหา');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
  });

  testWidgets(
      'Restrict -- confirm stays disabled until BOTH a reason and a duration '
      'are chosen', (tester) async {
    final repo = RecordingModerationRepository();
    await openSheet(tester, repository: repo, actionType: ModerationActionType.restrict);

    expect(find.text('ระยะเวลา'), findsOneWidget);
    final confirmButton = find.widgetWithText(FilledButton, 'ยืนยัน');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'สแปม');
    await tester.pump();
    // Reason alone still isn't enough for Restrict/Suspend.
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.tap(find.text('3 วัน'));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(repo.applyActionCalls, 1);
    expect(repo.lastReportId, 'r1');
    expect(repo.lastActionType, ModerationActionType.restrict);
    expect(repo.lastReason, 'สแปม');
    expect(repo.lastDurationDays, 3);
  });

  testWidgets('Ban -- shows the permanent-and-no-Unban-button warning copy',
      (tester) async {
    final repo = RecordingModerationRepository();
    await openSheet(tester, repository: repo, actionType: ModerationActionType.ban);

    expect(find.text('ระยะเวลา'), findsNothing);
    expect(
      find.textContaining('ยกเลิกได้เฉพาะทาง Database โดย admin เท่านั้นในรอบนี้'),
      findsOneWidget,
    );

    // Ban's confirm button must not be red -- same "never red, even for
    // Ban" rule as every other high-impact confirm in this app.
    final filledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ยืนยัน'),
    );
    expect(filledButton.style?.backgroundColor, isNull);
  });

  testWidgets('successful submit pops with ModerationActionSheetOutcome.success',
      (tester) async {
    final repo = RecordingModerationRepository();

    ModerationActionSheetOutcome? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showModerationActionSheet(
                context,
                moderationRepository: repo,
                reportId: 'r1',
                actionType: ModerationActionType.warning,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'คำเตือน');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยัน'));
    await tester.pumpAndSettle();

    expect(repo.applyActionCalls, 1);
    expect(repo.lastActionType, ModerationActionType.warning);
    expect(result, ModerationActionSheetOutcome.success);
    expect(find.text('ดำเนินการไม่สำเร็จ ลองอีกครั้ง'), findsNothing);
  });

  testWidgets(
      'a report already actioned by another moderator closes the sheet with '
      'alreadyActionedByOthers instead of a generic retry error', (tester) async {
    final repo = RecordingModerationRepository(
      applyActionError: Exception('Report has already been actioned'),
    );

    ModerationActionSheetOutcome? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showModerationActionSheet(
                context,
                moderationRepository: repo,
                reportId: 'r1',
                actionType: ModerationActionType.warning,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'คำเตือน');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยัน'));
    await tester.pumpAndSettle();

    expect(result, ModerationActionSheetOutcome.alreadyActionedByOthers);
  });

  testWidgets('an unrelated failure shows a generic retry error and keeps the sheet open',
      (tester) async {
    final repo = RecordingModerationRepository(
      applyActionError: Exception('network error'),
    );
    await openSheet(tester, repository: repo, actionType: ModerationActionType.warning);

    await tester.enterText(find.byType(TextField), 'คำเตือน');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยัน'));
    await tester.pumpAndSettle();

    expect(find.text('ดำเนินการไม่สำเร็จ ลองอีกครั้ง'), findsOneWidget);
  });
}
