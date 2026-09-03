import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/navigation/app_navigator.dart';
import 'package:wyn/features/home/presentation/pop_single_clip_screen.dart';
import 'package:wyn/features/push/presentation/push_notification_service.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_push_token_repository.dart';

/// WYN-016: Firebase.initializeApp() is never called during `flutter
/// test` (main() never runs in a widget test), so every one of these
/// exercises the exact "Firebase not configured yet" path production
/// code hits today, before the Founder adds real config files. Every
/// public method must no-op cleanly rather than throw -- these are
/// regression tests for that contract, not (yet) for real push
/// delivery, which needs a real Firebase project to verify end-to-end.
void main() {
  late RecordingPushTokenRepository tokenRepo;

  setUpAll(() async {
    // Needed only by the WYN-102 group below (`_openFromPushData` reads
    // `Supabase.instance.client`) -- mirrors explore_clubs_screen_test.dart's
    // own setUpAll pattern. Harmless for the 2 pre-existing tests above,
    // which never touch Supabase at all.
    await initFakeSupabaseSession(userId: 'viewer');
  });

  setUp(() {
    tokenRepo = RecordingPushTokenRepository();
  });

  test('initialize() does not throw and does not touch the token '
      'repository when Firebase is not initialized', () async {
    final service = PushNotificationService(tokenRepo);

    await service.initialize();

    expect(tokenRepo.upsertCalls, 0);
  });

  test('unregisterCurrentDevice() does not throw and does not touch the '
      'token repository when Firebase is not initialized', () async {
    final service = PushNotificationService(tokenRepo);

    await service.unregisterCurrentDevice();

    expect(tokenRepo.deleteCalls, 0);
  });

  group('WYN-102: a push notification about a Pop no longer opens Pop '
      'content', () {
    // `_openFromPushData` needs a real, mounted NavigatorState/
    // ScaffoldMessengerState reachable from the app-wide keys it (and
    // `_openPop`) read -- same keys `main.dart`'s real `MaterialApp`
    // wires up, so this is the minimal widget tree that lets the
    // service's own production code path run unmodified in a test.
    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: appScaffoldMessengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );
    }

    testWidgets(
        'a like_pop push shows the "content not available" SnackBar '
        'instead of opening PopSingleClipScreen', (tester) async {
      await pumpApp(tester);
      final service = PushNotificationService(tokenRepo);

      await service.debugOpenFromPushData({
        'type': 'like_pop',
        'pop_id': 'pop1',
      });
      await tester.pump();

      expect(find.text('เนื้อหานี้ไม่พร้อมใช้งานแล้ว'), findsOneWidget);
      expect(find.byType(PopSingleClipScreen), findsNothing);
    });

    testWidgets(
        'a comment_pop push shows the "content not available" SnackBar '
        'instead of opening PopSingleClipScreen', (tester) async {
      await pumpApp(tester);
      final service = PushNotificationService(tokenRepo);

      await service.debugOpenFromPushData({
        'type': 'comment_pop',
        'pop_id': 'pop1',
      });
      await tester.pump();

      expect(find.text('เนื้อหานี้ไม่พร้อมใช้งานแล้ว'), findsOneWidget);
      expect(find.byType(PopSingleClipScreen), findsNothing);
    });
  });
}
