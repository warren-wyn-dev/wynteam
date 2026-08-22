import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/moderation/presentation/appeal_decision_sheet.dart';

import 'support/recording_appeal_repository.dart';

void main() {
  late RecordingAppealRepository appealRepo;

  setUp(() {
    appealRepo = RecordingAppealRepository();
  });

  Future<void> openSheet(WidgetTester tester, {required bool approve}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppealDecisionSheet(
              context,
              appealRepository: appealRepo,
              appealId: 'appeal-1',
              approve: approve,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('approve needs no reason -- ยืนยัน submits immediately with a null reason',
      (tester) async {
    await openSheet(tester, approve: true);

    expect(find.text('ยืนยัน: อนุมัติอุทธรณ์'), findsOneWidget);
    await tester.tap(find.text('ยืนยัน'));
    await tester.pumpAndSettle();

    expect(appealRepo.decideAppealCalls, 1);
    expect(appealRepo.lastDecideAppealId, 'appeal-1');
    expect(appealRepo.lastDecideAppealApprove, isTrue);
    expect(appealRepo.lastDecideAppealReason, isNull);
  });

  testWidgets('reject disables ยืนยัน until a reason is typed, then submits it',
      (tester) async {
    await openSheet(tester, approve: false);

    expect(find.text('ยืนยัน: ปฏิเสธอุทธรณ์'), findsOneWidget);
    final confirmButton = find.widgetWithText(FilledButton, 'ยืนยัน');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'หลักฐานไม่เพียงพอ');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(appealRepo.decideAppealCalls, 1);
    expect(appealRepo.lastDecideAppealApprove, isFalse);
    expect(appealRepo.lastDecideAppealReason, 'หลักฐานไม่เพียงพอ');
  });

  testWidgets('a race with another moderator (already decided) resolves to alreadyDecided',
      (tester) async {
    appealRepo.decideAppealError = Exception('This appeal has already been decided');

    AppealDecisionSheetOutcome? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showAppealDecisionSheet(
                context,
                appealRepository: appealRepo,
                appealId: 'appeal-1',
                approve: true,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ยืนยัน'));
    await tester.pumpAndSettle();

    expect(result, AppealDecisionSheetOutcome.alreadyDecided);
  });

  testWidgets('a generic failure shows an inline error and stays open', (tester) async {
    appealRepo.decideAppealError = Exception('network error');

    await openSheet(tester, approve: true);
    await tester.tap(find.text('ยืนยัน'));
    await tester.pumpAndSettle();

    expect(find.text('ดำเนินการไม่สำเร็จ ลองอีกครั้ง'), findsOneWidget);
    expect(find.text('ยืนยัน: อนุมัติอุทธรณ์'), findsOneWidget);
  });
}
