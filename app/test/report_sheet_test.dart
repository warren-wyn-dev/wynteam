import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/report/data/report_category.dart';
import 'package:wyn/features/report/data/report_target_type.dart';
import 'package:wyn/features/report/presentation/report_sheet.dart';

import 'support/recording_report_repository.dart';

void main() {
  // Built once (not per-test) -- see RecordingDropRepository's doc
  // comment / drop_comment_delete_test.dart for why: each instance
  // starts its own SupabaseClient auto-refresh Timer, and building a
  // fresh one inside every testWidgets body accumulates timers that
  // trip the "Timer still pending" test-binding assertion.
  late RecordingReportRepository repo;

  setUpAll(() {
    repo = RecordingReportRepository();
  });

  setUp(() {
    repo.hasOpenReportResult = false;
    repo.hasOpenReportError = null;
    repo.submitReportError = null;
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    // A realistic phone viewport, not the 800x600 default -- the sheet's
    // maxHeight (90% of screen height) needs a believable screen height
    // to bound against, and 10 fixed categories plus the detail field
    // need to be reachable in it. See store_screen_test.dart's
    // pumpAtViewport for the same pattern.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showReportSheet(
                context,
                reportRepository: repo,
                targetType: ReportTargetType.drop,
                targetId: 'd1',
                targetLabel: 'รายงานโพสต์นี้',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('submit is disabled until a category is chosen', (tester) async {
    await pumpSheet(tester);
    tester.takeException();

    final submitButton =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'ส่งรายงาน'));
    expect(submitButton.onPressed, isNull);

    await tester.ensureVisible(find.text(ReportCategory.spam.label));
    await tester.tap(find.text(ReportCategory.spam.label));
    await tester.pump();

    final enabledButton =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'ส่งรายงาน'));
    expect(enabledButton.onPressed, isNotNull);
  });

  testWidgets('Other category requires a written detail before submit enables',
      (tester) async {
    await pumpSheet(tester);

    await tester.ensureVisible(find.text(ReportCategory.other.label));
    await tester.tap(find.text(ReportCategory.other.label));
    await tester.pump();

    var button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'ส่งรายงาน'));
    expect(button.onPressed, isNull);

    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'มีเหตุผลเพิ่มเติม');
    await tester.pump();

    button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'ส่งรายงาน'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
      'submitting calls submitReport with the chosen category and closes the sheet',
      (tester) async {
    final callsBefore = repo.submitReportCalls;
    await pumpSheet(tester);

    await tester.ensureVisible(find.text(ReportCategory.harassment.label));
    await tester.tap(find.text(ReportCategory.harassment.label));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'ส่งรายงาน'));
    await tester.tap(find.widgetWithText(FilledButton, 'ส่งรายงาน'));
    await tester.pumpAndSettle();

    expect(repo.submitReportCalls, callsBefore + 1);
    expect(repo.lastTargetType, ReportTargetType.drop);
    expect(repo.lastTargetId, 'd1');
    expect(repo.lastCategory, ReportCategory.harassment);
    expect(find.text('ส่งรายงานแล้ว ทีมงานจะตรวจสอบเร็วๆ นี้'), findsOneWidget);
    // The sheet itself is gone -- only the SnackBar and the trigger
    // screen remain.
    expect(find.text(ReportCategory.harassment.label), findsNothing);
  });

  testWidgets(
      'shows an already-reported message instead of the form when a report is already open',
      (tester) async {
    repo.hasOpenReportResult = true;
    await pumpSheet(tester);

    expect(find.text('คุณรายงานสิ่งนี้ไปแล้ว ทีมงานกำลังตรวจสอบ'), findsOneWidget);
    expect(find.text(ReportCategory.spam.label), findsNothing);
  });
}
