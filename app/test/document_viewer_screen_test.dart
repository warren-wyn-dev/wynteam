import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/legal/data/platform_document_repository.dart';
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
    repo.fetchLatestDocument = null;
    repo.fetchLatestError = null;
    repo.fetchLatestOverride = null;
  });

  Widget buildScreen(PlatformDocumentType type) {
    return MaterialApp(
      home: DocumentViewerScreen(
        documentType: type,
        platformDocumentRepository: repo,
      ),
    );
  }

  testWidgets('loading state shows a spinner before the fetch resolves',
      (tester) async {
    final completer = Completer<void>();
    repo.fetchLatestOverride = () => completer.future;

    await tester.pumpWidget(buildScreen(PlatformDocumentType.termsOfService));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'loaded state (terms_of_service) shows the title, version/effective '
      'date subtitle, and content', (tester) async {
    repo.fetchLatestDocument = PlatformDocument(
      type: PlatformDocumentType.termsOfService,
      version: 1,
      title: 'ข้อกำหนดการใช้งาน',
      content: 'เนื้อหา placeholder ของข้อกำหนดการใช้งาน',
      effectiveAt: DateTime(2026, 1, 15),
    );

    await tester.pumpWidget(buildScreen(PlatformDocumentType.termsOfService));
    await tester.pumpAndSettle();

    expect(find.text('ข้อกำหนดการใช้งาน'), findsWidgets);
    expect(find.textContaining('เวอร์ชัน 1'), findsOneWidget);
    expect(find.textContaining('15/01/2026'), findsOneWidget);
    expect(
      find.text('เนื้อหา placeholder ของข้อกำหนดการใช้งาน'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'loaded state (privacy_policy, a different document type) shows its '
      'own title, version, and content', (tester) async {
    repo.fetchLatestDocument = PlatformDocument(
      type: PlatformDocumentType.privacyPolicy,
      version: 2,
      title: 'นโยบายความเป็นส่วนตัว',
      content: 'เนื้อหา placeholder ของนโยบายความเป็นส่วนตัว',
      effectiveAt: DateTime(2026, 3, 1),
    );

    await tester.pumpWidget(buildScreen(PlatformDocumentType.privacyPolicy));
    await tester.pumpAndSettle();

    expect(find.text('นโยบายความเป็นส่วนตัว'), findsWidgets);
    expect(find.textContaining('เวอร์ชัน 2'), findsOneWidget);
    expect(find.textContaining('01/03/2026'), findsOneWidget);
    expect(
      find.text('เนื้อหา placeholder ของนโยบายความเป็นส่วนตัว'),
      findsOneWidget,
    );
  });

  testWidgets('error state shows a message with a retry button that reloads',
      (tester) async {
    repo.fetchLatestError = Exception('network error');

    await tester.pumpWidget(buildScreen(PlatformDocumentType.copyrightPolicy));
    await tester.pumpAndSettle();

    expect(find.text('โหลดเอกสารไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองใหม่'), findsOneWidget);

    repo.fetchLatestError = null;
    repo.fetchLatestDocument = PlatformDocument(
      type: PlatformDocumentType.copyrightPolicy,
      version: 1,
      title: 'นโยบายลิขสิทธิ์',
      content: 'เนื้อหา placeholder ของนโยบายลิขสิทธิ์',
      effectiveAt: DateTime(2026, 2, 1),
    );

    await tester.tap(find.text('ลองใหม่'));
    await tester.pumpAndSettle();

    expect(find.text('โหลดเอกสารไม่สำเร็จ'), findsNothing);
    expect(
      find.text('เนื้อหา placeholder ของนโยบายลิขสิทธิ์'),
      findsOneWidget,
    );
  });
}
