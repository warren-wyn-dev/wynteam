import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wyn/features/home/presentation/widgets/add_to_home_screen_banner.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // shouldOfferAddToHomeScreen() resolves to the non-web stub (always
  // false) under `flutter test`'s VM runner -- the real web check
  // (`(display-mode: standalone)`) only compiles into a web build at all
  // (see add_to_home_screen_support_web.dart), so this is the one thing
  // this test environment can actually exercise: the banner staying
  // hidden regardless of the dismissed pref, rather than showing on a
  // platform where "add to home screen" makes no sense.
  testWidgets('renders nothing on a non-web test build (web-only banner)',
      (tester) async {
    await tester.pumpWidget(_wrap(const AddToHomeScreenBanner()));
    await tester.pumpAndSettle();

    expect(
      find.text('เพิ่ม WYNOS ไว้ที่หน้าจอหลัก เปิดแอปได้ไวขึ้น'),
      findsNothing,
    );
    expect(find.byIcon(Icons.add_to_home_screen), findsNothing);
  });
}
