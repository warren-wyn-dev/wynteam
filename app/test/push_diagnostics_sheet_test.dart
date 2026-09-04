import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/push/presentation/push_diagnostics_sheet.dart';
import 'package:wyn/features/push/presentation/push_notification_service.dart';

import 'support/fake_push_notification_service.dart';
import 'support/fake_supabase_session.dart';

/// The sheet exists to answer, on the device, questions that neither the
/// device nor the server could answer alone. These tests are written
/// around those answers being *legible* -- a row that says nothing
/// useful is the same failure as no sheet at all.
void main() {
  // FakePushNotificationService builds a real PushTokenRepository, which
  // reaches Supabase.instance in its constructor.
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  Future<void> pumpSheet(WidgetTester tester, PushDiagnostics result) async {
    final service = FakePushNotificationService()..diagnostics = result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PushDiagnosticsSheet(pushNotificationService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  PushDiagnostics healthy() => const PushDiagnostics(
        firebaseReady: true,
        webPushConfigured: true,
        permission: PushPermissionState.granted,
        hasToken: true,
        tokenTail: 'a1b2c3d4',
        thisDeviceRegistered: true,
        registeredDeviceCount: 2,
      );

  testWidgets('a device that can receive push says so', (tester) async {
    await pumpSheet(tester, healthy());

    expect(find.byKey(const Key('push_diagnostics_loading')), findsNothing);
    expect(find.textContaining('เครื่องนี้พร้อมรับการแจ้งเตือนแล้ว'), findsOneWidget);
  });

  // The case that took a whole session to identify: everything on this
  // device is correct, and the account is registered somewhere else, so
  // pushes are arriving on a device nobody is watching.
  testWidgets('registered on another device is called out as such',
      (tester) async {
    await pumpSheet(
      tester,
      const PushDiagnostics(
        firebaseReady: true,
        webPushConfigured: true,
        permission: PushPermissionState.granted,
        hasToken: true,
        tokenTail: 'a1b2c3d4',
        thisDeviceRegistered: false,
        registeredDeviceCount: 1,
      ),
    );

    expect(
      find.textContaining('ไม่มีเครื่องนี้'),
      findsOneWidget,
      reason: 'the whole point of the sheet is naming this case',
    );
    expect(find.textContaining('ยังรับการแจ้งเตือนไม่ได้'), findsOneWidget);
  });

  testWidgets('an account with no registered device at all is distinguished',
      (tester) async {
    await pumpSheet(
      tester,
      const PushDiagnostics(
        firebaseReady: true,
        webPushConfigured: true,
        permission: PushPermissionState.granted,
        hasToken: false,
        thisDeviceRegistered: false,
        registeredDeviceCount: 0,
      ),
    );

    expect(find.textContaining('ยังไม่ได้ลงทะเบียนเครื่องไหนเลย'), findsOneWidget);
  });

  // iOS refuses a push subscription to a web app opened in Safari rather
  // than from the Home Screen, and reports it as "unsupported" -- which
  // reads as a broken app unless the sheet says what it means.
  testWidgets('unsupported explains the Home Screen requirement',
      (tester) async {
    await pumpSheet(
      tester,
      const PushDiagnostics(
        firebaseReady: true,
        webPushConfigured: true,
        permission: PushPermissionState.unsupported,
      ),
    );

    expect(find.textContaining('ไอคอนบนหน้าจอโฮม'), findsOneWidget);
  });

  testWidgets('never shows more of a token than its tail', (tester) async {
    await pumpSheet(tester, healthy());

    expect(find.textContaining('a1b2c3d4'), findsOneWidget);
  });

  testWidgets('a failure from the platform is reported, not swallowed',
      (tester) async {
    await pumpSheet(
      tester,
      const PushDiagnostics(
        firebaseReady: true,
        webPushConfigured: true,
        permission: PushPermissionState.granted,
        failure: 'messaging/permission-blocked',
      ),
    );

    expect(find.textContaining('messaging/permission-blocked'), findsOneWidget);
  });
}
