import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wyn/core/web/home_screen_platform.dart';
import 'package:wyn/features/home/presentation/widgets/add_to_home_screen_banner.dart';
import 'package:wyn/features/home/presentation/widgets/add_to_home_screen_sheet.dart';
import 'package:wyn/features/home/presentation/widgets/home_explainer_banner.dart';

/// WYN-107, Screen 1.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

const _bannerText =
    'เพิ่ม WYNOS ไว้ที่หน้าจอหลัก เข้าเร็วขึ้นเหมือนเปิดแอปจริง · แตะเพื่อดูวิธี';

/// A banner that's already eligible on every platform/standalone check --
/// the tests below layer HomeExplainerBanner-dismissed/snooze state on
/// top of this via SharedPreferences.setMockInitialValues.
AddToHomeScreenBanner _eligibleBanner({DateTime Function() now = DateTime.now}) =>
    AddToHomeScreenBanner(
      isWeb: true,
      isStandalone: () => false,
      platformKind: () => WebPlatformKind.iosSafari,
      now: now,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('hidden until HomeExplainerBanner has been dismissed',
      (tester) async {
    // HomeExplainerBanner.prefsKey isn't set yet -- still showing itself.
    await tester.pumpWidget(_wrap(_eligibleBanner()));
    await tester.pumpAndSettle();

    expect(find.text(_bannerText), findsNothing);
  });

  testWidgets(
      'visible once HomeExplainerBanner is dismissed, eligible platform, no snooze',
      (tester) async {
    SharedPreferences.setMockInitialValues({HomeExplainerBanner.prefsKey: true});

    await tester.pumpWidget(_wrap(_eligibleBanner()));
    await tester.pumpAndSettle();

    expect(find.text(_bannerText), findsOneWidget);
  });

  testWidgets('hidden when not running on web', (tester) async {
    SharedPreferences.setMockInitialValues({HomeExplainerBanner.prefsKey: true});

    await tester.pumpWidget(_wrap(AddToHomeScreenBanner(
      isWeb: false,
      isStandalone: () => false,
      platformKind: () => WebPlatformKind.iosSafari,
    )));
    await tester.pumpAndSettle();

    expect(find.text(_bannerText), findsNothing);
  });

  testWidgets('hidden once already running standalone', (tester) async {
    SharedPreferences.setMockInitialValues({HomeExplainerBanner.prefsKey: true});

    await tester.pumpWidget(_wrap(AddToHomeScreenBanner(
      isWeb: true,
      isStandalone: () => true,
      platformKind: () => WebPlatformKind.iosSafari,
    )));
    await tester.pumpAndSettle();

    expect(find.text(_bannerText), findsNothing);
  });

  testWidgets('hidden when the platform is neither iOS Safari nor Android '
      'Chrome (fail-closed)', (tester) async {
    SharedPreferences.setMockInitialValues({HomeExplainerBanner.prefsKey: true});

    await tester.pumpWidget(_wrap(AddToHomeScreenBanner(
      isWeb: true,
      isStandalone: () => false,
      platformKind: () => WebPlatformKind.desktopOrOther,
    )));
    await tester.pumpAndSettle();

    expect(find.text(_bannerText), findsNothing);
  });

  testWidgets(
      'tapping X hides it immediately and writes lastSnoozedAt (an epoch-'
      'millis int, not a boolean dismissed flag)', (tester) async {
    SharedPreferences.setMockInitialValues({HomeExplainerBanner.prefsKey: true});
    final fixedNow = DateTime(2026, 9, 3, 12);

    await tester.pumpWidget(_wrap(_eligibleBanner(now: () => fixedNow)));
    await tester.pumpAndSettle();
    expect(find.text(_bannerText), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text(_bannerText), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(AddToHomeScreenBanner.snoozedAtPrefsKey),
      fixedNow.millisecondsSinceEpoch,
    );
  });

  testWidgets('stays hidden while still within kSnoozeDuration of the last '
      'snooze', (tester) async {
    final snoozedAt = DateTime(2026, 9, 1);
    SharedPreferences.setMockInitialValues({
      HomeExplainerBanner.prefsKey: true,
      AddToHomeScreenBanner.snoozedAtPrefsKey: snoozedAt.millisecondsSinceEpoch,
    });
    // 2 days later -- well inside the 7-day snooze window.
    final now = snoozedAt.add(const Duration(days: 2));

    await tester.pumpWidget(_wrap(_eligibleBanner(now: () => now)));
    await tester.pumpAndSettle();

    expect(find.text(_bannerText), findsNothing);
  });

  testWidgets(
      'reappears once kSnoozeDuration has fully elapsed since the last '
      'snooze', (tester) async {
    final snoozedAt = DateTime(2026, 9, 1);
    SharedPreferences.setMockInitialValues({
      HomeExplainerBanner.prefsKey: true,
      AddToHomeScreenBanner.snoozedAtPrefsKey: snoozedAt.millisecondsSinceEpoch,
    });
    final now = snoozedAt.add(AddToHomeScreenBanner.kSnoozeDuration);

    await tester.pumpWidget(_wrap(_eligibleBanner(now: () => now)));
    await tester.pumpAndSettle();

    expect(find.text(_bannerText), findsOneWidget);
  });

  testWidgets(
      'tapping the banner body (not X) opens the sheet without touching '
      'snooze state', (tester) async {
    SharedPreferences.setMockInitialValues({HomeExplainerBanner.prefsKey: true});

    await tester.pumpWidget(_wrap(_eligibleBanner()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_bannerText));
    await tester.pumpAndSettle();

    expect(find.byType(AddToHomeScreenSheet), findsOneWidget);
    // The banner tap never writes shared_preferences at all -- design
    // doc: "ไม่ snooze banner ทันทีตอนแตะ".
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AddToHomeScreenBanner.snoozedAtPrefsKey), isNull);
  });

  testWidgets('opens the iOS Safari step content when detected as iOS Safari',
      (tester) async {
    SharedPreferences.setMockInitialValues({HomeExplainerBanner.prefsKey: true});

    await tester.pumpWidget(_wrap(AddToHomeScreenBanner(
      isWeb: true,
      isStandalone: () => false,
      platformKind: () => WebPlatformKind.iosSafari,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_bannerText));
    await tester.pumpAndSettle();

    expect(find.textContaining('แชร์'), findsOneWidget);
    expect(find.textContaining('จุดสามจุด'), findsNothing);
  });

  testWidgets(
      'opens the Android Chrome step content when detected as Android Chrome',
      (tester) async {
    SharedPreferences.setMockInitialValues({HomeExplainerBanner.prefsKey: true});

    await tester.pumpWidget(_wrap(AddToHomeScreenBanner(
      isWeb: true,
      isStandalone: () => false,
      platformKind: () => WebPlatformKind.androidChrome,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_bannerText));
    await tester.pumpAndSettle();

    expect(find.textContaining('จุดสามจุด'), findsOneWidget);
    expect(find.textContaining('แชร์'), findsNothing);
  });
}
