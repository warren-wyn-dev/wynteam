import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/navigation/app_navigator.dart';
import 'package:wyn/core/navigation/deep_link_service.dart';

/// WYN-119: before `DeepLinkService` existed, `RootShell` never read the
/// browser's URL at all, so every shared link (drop/pop/club/club-post/
/// profile) opened straight to Home no matter what path was in the
/// address bar. These tests cover the parts of `_handle` that don't need
/// a real Supabase project to reach a real conclusion -- the same
/// constraint `push_notification_service_test.dart`'s own WYN-102 group
/// documents: any branch that calls `fetchById`/`fetchProfileByUsername`
/// makes a real network call there's no fake for in this suite, so
/// exercising those happy paths needs a live/mocked backend, not
/// something this test file can prove red->green on its own. A full QA
/// pass against a real (or seeded local) Supabase project should still
/// verify drop/club/club-post/profile links resolve to the right screen
/// before this ships -- this file only proves the routing/guard logic
/// that sits in front of those calls.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
  }

  setUp(DeepLinkService.resetForTest);
  tearDown(() => DeepLinkService.debugForceHasContentPath = null);

  testWidgets(
      'a /pop/<id> link shows the "content not available" SnackBar '
      'instead of navigating (WYN-102: Pop has no access point anymore)',
      (tester) async {
    await pumpApp(tester);

    await DeepLinkService.debugHandlePath('/pop/pop1');
    await tester.pump();

    expect(find.text('เนื้อหานี้ไม่พร้อมใช้งานแล้ว'), findsOneWidget);
  });

  for (final path in ['', '/', '/club', '/club/', '/@', '/unknown/x123']) {
    testWidgets('malformed/unhandled path "$path" is a clean no-op '
        '(no navigation, no throw)', (tester) async {
      await pumpApp(tester);

      await DeepLinkService.debugHandlePath(path);
      await tester.pump();

      // Still on the bare Scaffold this test pumped -- nothing was
      // pushed on top of it.
      expect(find.byType(Scaffold), findsOneWidget);
    });
  }

  testWidgets(
      'handleInitialLink() is a no-op on the default (non-web) test '
      'target -- Uri.base there is this test runner\'s own location, '
      'not a URL under test, so it must never act on it',
      (tester) async {
    await pumpApp(tester);

    await DeepLinkService.handleInitialLink();
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('เนื้อหานี้ไม่พร้อมใช้งานแล้ว'), findsNothing);
  });

  testWidgets(
      'handleInitialLink() only ever fires once per app load, even if '
      'called again',
      (tester) async {
    await pumpApp(tester);

    await DeepLinkService.handleInitialLink();
    await DeepLinkService.handleInitialLink();
    await tester.pump();

    // Neither call could navigate anywhere on this (non-web) test
    // target -- this just proves the second call doesn't throw or
    // otherwise misbehave once the guard has already tripped.
    expect(find.byType(Scaffold), findsOneWidget);
  });

  test('hasContentPath() is false on the default (non-web) test target, '
      'even when debugForceHasContentPath is left unset', () {
    expect(DeepLinkService.hasContentPath(), isFalse);
  });

  test('hasContentPath() returns exactly what debugForceHasContentPath is '
      'forced to, bypassing the real kIsWeb/Uri.base check', () {
    DeepLinkService.debugForceHasContentPath = true;
    expect(DeepLinkService.hasContentPath(), isTrue);

    DeepLinkService.debugForceHasContentPath = false;
    expect(DeepLinkService.hasContentPath(), isFalse);
  });
}
