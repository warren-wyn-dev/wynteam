import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/features/settings/data/notification_settings_repository.dart';
import 'package:wyn/features/settings/presentation/notification_settings_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_notification_settings_repository.dart';

void main() {
  // Constructed in setUpAll, not inline in a test body -- see
  // settings_screen_test.dart's own comment on why (the GoTrue
  // auto-refresh timer started by the SupabaseClient each Recording
  // repository wraps must not be attributed to a single test's
  // FakeAsync zone).
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  Widget buildScreen(NotificationSettingsRepository repo) {
    return MaterialApp(
      home: NotificationSettingsScreen(
        notificationSettingsRepository: repo,
      ),
    );
  }

  testWidgets('shows a loading spinner while the initial fetch is in flight',
      (tester) async {
    final completer = Completer<NotificationSettings>();
    // Directly overriding fetch isn't possible on the recording double
    // (it always resolves immediately) -- a raw NotificationSettings
    // Repository subclass makes the completer-controlled version
    // instead, mirroring RecordingZokyRepository's own
    // createOrdersOverride style but for fetch() specifically.
    final controlled = _ControlledFetchRepository(completer.future);

    await tester.pumpWidget(buildScreen(controlled));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const NotificationSettings());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'no row for the user (default NotificationSettings) shows every '
      'toggle enabled', (tester) async {
    final repo = RecordingNotificationSettingsRepository(
      settings: const NotificationSettings(),
    );

    await tester.pumpWidget(buildScreen(repo));
    await tester.pumpAndSettle();

    for (final title in [
      'ถูกใจ',
      'คอมเมนต์',
      'ผู้ติดตาม',
      'ข้อความ',
      'Club',
      'กำลังนิยม',
      'ระบบ',
    ]) {
      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, title),
      );
      expect(tile.value, isTrue, reason: '$title should default to enabled');
    }
  });

  testWidgets('reflects a partially-off row from the repository',
      (tester) async {
    final repo = RecordingNotificationSettingsRepository(
      settings: const NotificationSettings(comments: false, club: false),
    );

    await tester.pumpWidget(buildScreen(repo));
    await tester.pumpAndSettle();

    final commentsTile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'คอมเมนต์'),
    );
    expect(commentsTile.value, isFalse);

    final likesTile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'ถูกใจ'),
    );
    expect(likesTile.value, isTrue);
  });

  testWidgets(
      'tapping a toggle flips it optimistically and calls upsertCategory '
      'with the right category and value', (tester) async {
    final repo = RecordingNotificationSettingsRepository();

    await tester.pumpWidget(buildScreen(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'ผู้ติดตาม'));
    await tester.pumpAndSettle();

    expect(repo.upsertCategoryArgs, [('follows', false)]);
    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'ผู้ติดตาม'),
    );
    expect(tile.value, isFalse);
  });

  testWidgets('a failed upsert reverts the row and shows the error SnackBar',
      (tester) async {
    final repo = RecordingNotificationSettingsRepository()
      ..upsertCategoryException = Exception('network error');

    await tester.pumpWidget(buildScreen(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'ระบบ'));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'ระบบ'),
    );
    expect(tile.value, isTrue);
    expect(find.text('เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
  });

  testWidgets(
      'toggling one row while another row is still saving does NOT '
      'disable the second row (Design Rule #1)', (tester) async {
    final completer = Completer<void>();
    final repo = RecordingNotificationSettingsRepository()
      ..upsertCategoryOverride = (category, value) async {
        if (category == 'likes') await completer.future;
      };

    await tester.pumpWidget(buildScreen(repo));
    await tester.pumpAndSettle();

    // Start saving "ถูกใจ" -- its own save never resolves until the
    // completer below fires.
    await tester.tap(find.widgetWithText(SwitchListTile, 'ถูกใจ'));
    await tester.pump();

    final likesTileMidFlight = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'ถูกใจ'),
    );
    expect(likesTileMidFlight.onChanged, isNull,
        reason: 'the row currently saving must be disabled');

    final followsTileMidFlight = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'ผู้ติดตาม'),
    );
    expect(followsTileMidFlight.onChanged, isNotNull,
        reason:
            'a different row must stay interactive while "ถูกใจ" is saving');

    // Prove it's not just enabled but actually still works.
    await tester.tap(find.widgetWithText(SwitchListTile, 'ผู้ติดตาม'));
    await tester.pump();

    expect(
      repo.upsertCategoryArgs.where((a) => a.$1 == 'follows'),
      [('follows', false)],
    );

    completer.complete();
    await tester.pumpAndSettle();

    final likesTileAfter = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'ถูกใจ'),
    );
    expect(likesTileAfter.onChanged, isNotNull);
    expect(likesTileAfter.value, isFalse);
  });

  testWidgets(
      'a failed initial fetch shows the error state with a retry button',
      (tester) async {
    final repo = RecordingNotificationSettingsRepository(
      fetchException: Exception('network error'),
    );

    await tester.pumpWidget(buildScreen(repo));
    await tester.pumpAndSettle();

    expect(find.text('โหลดการตั้งค่าไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองใหม่'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);

    repo.fetchException = null;
    await tester.tap(find.text('ลองใหม่'));
    await tester.pumpAndSettle();

    expect(find.text('โหลดการตั้งค่าไม่สำเร็จ'), findsNothing);
    expect(find.byType(SwitchListTile), findsWidgets);
  });
}

/// A NotificationSettingsRepository whose [fetch] resolves whenever
/// [future] resolves -- used only by the loading-spinner test above,
/// which needs to observe the *in-progress* state, unlike every other
/// test in this file (which use RecordingNotificationSettingsRepository
/// and let fetch resolve immediately).
class _ControlledFetchRepository extends NotificationSettingsRepository {
  _ControlledFetchRepository(this.future)
      : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  final Future<NotificationSettings> future;

  @override
  Future<NotificationSettings> fetch() => future;

  @override
  Future<void> upsertCategory({
    required String category,
    required bool value,
  }) async {}
}
