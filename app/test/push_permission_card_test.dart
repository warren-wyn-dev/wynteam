import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/push/presentation/push_notification_service.dart';
import 'package:wyn/features/push/presentation/push_permission_card.dart';

import 'support/fake_supabase_session.dart';
import 'support/fake_push_notification_service.dart';

/// Beta4 §11.2 -- the in-app explainer that must come before the OS
/// notification prompt.
///
/// What these tests are really guarding is a rule about *when the OS
/// prompt is allowed to appear*: never on sight, only after a person
/// has read what push is for and tapped a button that says so. That
/// prompt is a one-shot on every platform WYNOS runs on, so a reflexive
/// refusal to an unexplained system dialog is permanent and no later UI
/// can reopen it. Before Beta4, `RootShell.initState` fired it the
/// instant onboarding finished.
void main() {
  late FakePushNotificationService service;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    service = FakePushNotificationService();
  });

  Widget wrap() => MaterialApp(
        home: Scaffold(
          body: PushPermissionCard(pushNotificationService: service),
        ),
      );

  testWidgets('asks nothing while the permission state is still unknown',
      (tester) async {
    // Held open, so the card stays in the state it is in before its
    // first read resolves. Nothing should be offered yet -- flashing an
    // ask that turns out to be unnecessary (the person may already have
    // granted, or the build may not support push at all) is its own
    // kind of wrong.
    final hold = Completer<void>();
    service.holdCurrentState = hold;
    service.currentState = PushPermissionState.notDetermined;

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byKey(const Key('push_permission_ask')), findsNothing);
    expect(find.byKey(const Key('push_permission_denied')), findsNothing);

    hold.complete();
    await tester.pumpAndSettle();

    // ...and it does appear once the answer is actually known.
    expect(find.byKey(const Key('push_permission_ask')), findsOneWidget);
  });

  testWidgets('offers the ask, with a reason, when nobody has been asked yet',
      (tester) async {
    service.currentState = PushPermissionState.notDetermined;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('push_permission_ask')), findsOneWidget);
    expect(find.text('เปิดการแจ้งเตือนบนเครื่องนี้'), findsOneWidget);
    // A reason, not just a button -- the whole point of priming.
    expect(find.textContaining('ถูกใจ'), findsOneWidget);
    expect(find.byKey(const Key('push_permission_enable_button')),
        findsOneWidget);
    expect(find.byKey(const Key('push_permission_dismiss_button')),
        findsOneWidget);

    // Crucially: showing the card must not itself have asked the OS.
    expect(service.requestCalls, 0);
  });

  testWidgets(
      'the OS prompt is only reached by tapping the enable button, and a '
      'grant registers this device', (tester) async {
    service.currentState = PushPermissionState.notDetermined;
    service.requestResult = PushPermissionState.granted;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(service.requestCalls, 0);

    await tester.tap(find.byKey(const Key('push_permission_enable_button')));
    await tester.pumpAndSettle();

    expect(service.requestCalls, 1);
    // Granted -> the ask is gone, and the person is told it worked.
    expect(find.byKey(const Key('push_permission_ask')), findsNothing);
    expect(find.text('เปิดการแจ้งเตือนแล้ว'), findsOneWidget);
  });

  testWidgets('"ไม่ใช่ตอนนี้" hides the card without asking the OS',
      (tester) async {
    service.currentState = PushPermissionState.notDetermined;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('push_permission_dismiss_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('push_permission_ask')), findsNothing);
    expect(service.requestCalls, 0);
  });

  testWidgets(
      'a refusal is stated once and never re-asked -- the prompt cannot be '
      'shown again, so the card points at system settings instead',
      (tester) async {
    service.currentState = PushPermissionState.denied;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('push_permission_denied')), findsOneWidget);
    // No button at all: tapping one would call requestPermission(),
    // which every platform silently ignores after a refusal.
    expect(find.byKey(const Key('push_permission_enable_button')), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('การตั้งค่าของระบบ'), findsOneWidget);
    // ...and it says in-app notifications still work, so the note is not
    // read as "notifications are broken".
    expect(find.textContaining('ในแอปยังแสดง'), findsOneWidget);
  });

  testWidgets('renders nothing at all once permission is granted',
      (tester) async {
    service.currentState = PushPermissionState.granted;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('push_permission_ask')), findsNothing);
    expect(find.byKey(const Key('push_permission_denied')), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets(
      'renders nothing when push is unsupported -- never offers what the '
      'build cannot honour', (tester) async {
    // No Firebase config at all, or a web build with no VAPID key.
    service.currentState = PushPermissionState.unsupported;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('push_permission_ask')), findsNothing);
    expect(find.byKey(const Key('push_permission_denied')), findsNothing);
    expect(service.requestCalls, 0);
  });
}
