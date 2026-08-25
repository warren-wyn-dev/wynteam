import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wyn/features/profile/presentation/widgets/privacy_notice_banner.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the message the first time (no stored pref yet)',
      (tester) async {
    await tester.pumpWidget(_wrap(const PrivacyNoticeBanner(
      prefsKey: 'seen_test_notice',
      message: 'ข้อความทดสอบ',
    )));
    await tester.pumpAndSettle();

    expect(find.text('ข้อความทดสอบ'), findsOneWidget);
  });

  testWidgets('stays hidden if the pref is already set', (tester) async {
    SharedPreferences.setMockInitialValues({'seen_test_notice': true});

    await tester.pumpWidget(_wrap(const PrivacyNoticeBanner(
      prefsKey: 'seen_test_notice',
      message: 'ข้อความทดสอบ',
    )));
    await tester.pumpAndSettle();

    expect(find.text('ข้อความทดสอบ'), findsNothing);
  });

  testWidgets('tapping X hides it and persists the pref', (tester) async {
    await tester.pumpWidget(_wrap(const PrivacyNoticeBanner(
      prefsKey: 'seen_test_notice',
      message: 'ข้อความทดสอบ',
    )));
    await tester.pumpAndSettle();
    expect(find.text('ข้อความทดสอบ'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('ข้อความทดสอบ'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('seen_test_notice'), isTrue);
  });
}
