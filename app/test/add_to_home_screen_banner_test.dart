import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wyn/core/pwa/pwa_install_hint.dart';
import 'package:wyn/features/home/presentation/widgets/add_to_home_screen_banner.dart';

/// Founder feedback: users didn't know WYNOS (the Flutter Web build)
/// could be added to their home screen like a real app icon at all.
///
/// `isWeb`/`guidance`/`isRunningAsInstalledApp` are always passed
/// explicitly here -- `flutter test` runs on the VM target, where the
/// real `kIsWeb`/`PwaInstallHint` reads this widget defaults to would
/// always resolve to "hide" (`kIsWeb` is compile-time false off the web
/// target), leaving every other branch permanently unreachable without
/// them. See the widget's own doc comment on why the overrides exist.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows iOS-specific instructions on iOS', (tester) async {
    await tester.pumpWidget(_wrap(const AddToHomeScreenBanner(
      isWeb: true,
      guidance: AddToHomeScreenGuidance.ios,
      isRunningAsInstalledApp: false,
    )));
    await tester.pumpAndSettle();

    expect(find.text('เพิ่ม WYNOS ไปหน้าจอโฮม'), findsOneWidget);
    expect(find.textContaining('Safari'), findsOneWidget);
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
  });

  testWidgets('shows Android-specific instructions on Android', (tester) async {
    await tester.pumpWidget(_wrap(const AddToHomeScreenBanner(
      isWeb: true,
      guidance: AddToHomeScreenGuidance.android,
      isRunningAsInstalledApp: false,
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('ติดตั้งแอป'), findsOneWidget);
    expect(find.byIcon(Icons.install_mobile), findsOneWidget);
    // Not iOS's instructions.
    expect(find.textContaining('Safari'), findsNothing);
  });

  testWidgets('renders nothing at all on a native (non-web) build',
      (tester) async {
    await tester.pumpWidget(_wrap(const AddToHomeScreenBanner(
      isWeb: false,
      guidance: AddToHomeScreenGuidance.ios,
      isRunningAsInstalledApp: false,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_to_home_screen_banner')), findsNothing);
  });

  testWidgets(
      'renders nothing on a desktop browser (guidance placed on neither '
      'platform)', (tester) async {
    await tester.pumpWidget(_wrap(const AddToHomeScreenBanner(
      isWeb: true,
      guidance: AddToHomeScreenGuidance.unsupported,
      isRunningAsInstalledApp: false,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_to_home_screen_banner')), findsNothing);
  });

  testWidgets(
      'renders nothing once the visitor already opened the installed app',
      (tester) async {
    await tester.pumpWidget(_wrap(const AddToHomeScreenBanner(
      isWeb: true,
      guidance: AddToHomeScreenGuidance.ios,
      isRunningAsInstalledApp: true,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_to_home_screen_banner')), findsNothing);
  });

  testWidgets('stays hidden if the pref is already set', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'add_to_home_screen_banner_dismissed': true});

    await tester.pumpWidget(_wrap(const AddToHomeScreenBanner(
      isWeb: true,
      guidance: AddToHomeScreenGuidance.ios,
      isRunningAsInstalledApp: false,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_to_home_screen_banner')), findsNothing);
  });

  testWidgets('tapping the dismiss button hides it and persists the pref',
      (tester) async {
    await tester.pumpWidget(_wrap(const AddToHomeScreenBanner(
      isWeb: true,
      guidance: AddToHomeScreenGuidance.ios,
      isRunningAsInstalledApp: false,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_to_home_screen_banner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_to_home_screen_dismiss_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_to_home_screen_banner')), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('add_to_home_screen_banner_dismissed'), isTrue);
  });

  testWidgets(
      'the dismiss button meets the 44px touch target minimum (WCAG 2.5.5)',
      (tester) async {
    await tester.pumpWidget(_wrap(const AddToHomeScreenBanner(
      isWeb: true,
      guidance: AddToHomeScreenGuidance.ios,
      isRunningAsInstalledApp: false,
    )));
    await tester.pumpAndSettle();

    final closeButtonSize = tester.getSize(
      find.ancestor(
        of: find.byKey(const Key('add_to_home_screen_dismiss_button')),
        matching: find.byType(ConstrainedBox),
      ).first,
    );
    expect(closeButtonSize.width, greaterThanOrEqualTo(44));
    expect(closeButtonSize.height, greaterThanOrEqualTo(44));
  });
}
