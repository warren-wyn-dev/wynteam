import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/notification/data/notification_settings.dart';
import 'package:wyn/features/notification/presentation/notification_settings_screen.dart';

import 'support/recording_notification_settings_repository.dart';

void main() {
  late RecordingNotificationSettingsRepository repository;

  setUp(() {
    repository = RecordingNotificationSettingsRepository();
  });

  testWidgets('shows all 6 categories, each initialized from fetchSettings',
      (tester) async {
    repository.fetchSettingsResult = const NotificationSettings(
      likes: false,
      comments: true,
      follows: false,
      messages: true,
      club: false,
      system: true,
    );

    await tester.pumpWidget(MaterialApp(
      home: NotificationSettingsScreen(
        notificationSettingsRepository: repository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ถูกใจและ ReDrop'), findsOneWidget);
    expect(find.text('คอมเมนต์และการกล่าวถึง'), findsOneWidget);
    expect(find.text('การติดตาม'), findsOneWidget);
    expect(find.text('ข้อความ'), findsOneWidget);
    expect(find.text('Club'), findsOneWidget);
    expect(find.text('ประกาศจากระบบ'), findsOneWidget);

    final switches =
        tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    expect(switches.length, 6);
    expect(switches.map((s) => s.value).toList(), [
      false, // likes
      true, // comments
      false, // follows
      true, // messages
      false, // club
      true, // system
    ]);
  });

  testWidgets(
      'fetchSettings failing fails open -- every switch shows enabled, not disabled',
      (tester) async {
    repository.fetchSettingsError = Exception('network error');

    await tester.pumpWidget(MaterialApp(
      home: NotificationSettingsScreen(
        notificationSettingsRepository: repository,
      ),
    ));
    await tester.pumpAndSettle();

    final switches =
        tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    expect(switches.length, 6);
    expect(switches.every((s) => s.value == true), isTrue);
    expect(find.text('โหลดค่าปัจจุบันไม่สำเร็จ ลองรีเฟรชหน้านี้ใหม่'),
        findsOneWidget);
  });

  testWidgets('flipping the Likes toggle calls updateCategory(likes, false)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NotificationSettingsScreen(
        notificationSettingsRepository: repository,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ถูกใจและ ReDrop'));
    await tester.pumpAndSettle();

    expect(repository.updateCategoryCalls, [(NotificationCategory.likes, false)]);
    final toggle = tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'ถูกใจและ ReDrop'));
    expect(toggle.value, isFalse);
  });

  testWidgets('a failed save reverts the toggle and shows an error',
      (tester) async {
    repository.updateCategoryError = Exception('network error');

    await tester.pumpWidget(MaterialApp(
      home: NotificationSettingsScreen(
        notificationSettingsRepository: repository,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Club'));
    await tester.pumpAndSettle();

    final toggle = tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Club'));
    expect(toggle.value, isTrue);
    expect(find.text('เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
  });

  testWidgets(
      'toggling one category does not disable the other switches while saving',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NotificationSettingsScreen(
        notificationSettingsRepository: repository,
      ),
    ));
    await tester.pumpAndSettle();

    // Tap without settling -- while the "likes" save is in flight, the
    // "Club" switch must still be enabled (not disabled as a side
    // effect of an unrelated category's save).
    await tester.tap(find.text('ถูกใจและ ReDrop'));
    await tester.pump();

    final clubToggle = tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Club'));
    expect(clubToggle.onChanged, isNotNull);

    await tester.pumpAndSettle();
  });
}
