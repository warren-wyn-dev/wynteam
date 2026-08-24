import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/legal/presentation/document_acceptance_screen.dart';
import 'package:wyn/features/legal/presentation/document_viewer_screen.dart';

import 'support/recording_platform_document_repository.dart';

void main() {
  // Constructed in setUpAll, not inline in a test body -- see
  // settings_screen_test.dart's own comment on why (the GoTrue
  // auto-refresh timer started by the SupabaseClient each Recording
  // repository wraps must not be attributed to a single test's FakeAsync
  // zone). One shared instance, with mutable fields reassigned/reset per
  // test case instead of constructing a fresh repository (and the
  // SupabaseClient it wraps) inline in every testWidgets body (WYN-044
  // debug fix).
  late RecordingPlatformDocumentRepository repo;

  setUpAll(() {
    repo = RecordingPlatformDocumentRepository();
  });

  setUp(() {
    repo.acceptMandatoryDocumentsCalls = 0;
    repo.acceptMandatoryDocumentsError = null;
    repo.fetchLatestDocument = null;
    repo.fetchLatestError = null;
  });

  Widget buildScreen({required VoidCallback onAccepted}) {
    return MaterialApp(
      home: DocumentAcceptanceScreen(
        platformDocumentRepository: repo,
        onAccepted: onAccepted,
      ),
    );
  }

  testWidgets(
      'the accept button starts disabled, and enables only once the '
      'checkbox is ticked (Design Rule #2 -- single checkbox)',
      (tester) async {
    await tester.pumpWidget(buildScreen(onAccepted: () {}));
    await tester.pumpAndSettle();

    final buttonBefore =
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(buttonBefore.onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    final buttonAfter = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(buttonAfter.onPressed, isNotNull);
  });

  testWidgets(
      'the disabled accept button has a Semantics label explaining why '
      '(mirrors ReportSheet\'s disabled-button pattern)', (tester) async {
    await tester.pumpWidget(buildScreen(onAccepted: () {}));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('ยอมรับและดำเนินการต่อ ปิดใช้งานจนกว่าจะติ๊กยอมรับ'),
      findsOneWidget,
    );
  });

  testWidgets(
      'accepting calls acceptMandatoryDocuments (which upserts all 3 '
      'mandatory types in one call) and invokes onAccepted',
      (tester) async {
    var acceptedCalls = 0;
    await tester.pumpWidget(buildScreen(onAccepted: () => acceptedCalls++));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repo.acceptMandatoryDocumentsCalls, 1);
    expect(acceptedCalls, 1);
  });

  testWidgets('a failed acceptance shows an error SnackBar and does not '
      'call onAccepted', (tester) async {
    repo.acceptMandatoryDocumentsError = Exception('network error');
    var acceptedCalls = 0;
    await tester.pumpWidget(buildScreen(onAccepted: () => acceptedCalls++));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('ยอมรับไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(acceptedCalls, 0);
  });

  // Each label gets its own testWidgets block (not a shared for-loop
  // reusing one tester) -- pumping the same MaterialApp/DocumentAcceptance
  // Screen widget type again in the same test body reuses the existing
  // Navigator's State (and its route stack) instead of resetting it, so
  // a second pumpWidget call would still show whatever screen the first
  // iteration's tap already pushed. See .wyn/learning/PATTERNS.md.
  for (final label in [
    'ข้อกำหนดการใช้งาน',
    'นโยบายความเป็นส่วนตัว',
    'แนวทางชุมชน',
  ]) {
    testWidgets('tapping "$label" opens DocumentViewerScreen', (tester) async {
      await tester.pumpWidget(buildScreen(onAccepted: () {}));
      await tester.pumpAndSettle();

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.byType(DocumentViewerScreen), findsOneWidget);
    });
  }

  testWidgets('there is no AppBar and no way to skip/dismiss the screen',
      (tester) async {
    await tester.pumpWidget(buildScreen(onAccepted: () {}));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('ข้าม'), findsNothing);
    expect(find.text('ภายหลัง'), findsNothing);
  });
}
