import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wyn/features/home/presentation/widgets/home_explainer_banner.dart';

/// WYNOSHomeSpec.md item 1.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the message the first time (no stored pref yet)',
      (tester) async {
    await tester.pumpWidget(_wrap(const HomeExplainerBanner()));
    await tester.pumpAndSettle();

    expect(find.text('ดู → แชร์ → ค้นพบ → ซื้อ'), findsOneWidget);
    expect(
      find.text('WYNOS คือพื้นที่โซเชียลที่ต่อยอดจากสิ่งที่คุณชอบเห็น'),
      findsOneWidget,
    );
  });

  testWidgets('stays hidden if the pref is already set', (tester) async {
    SharedPreferences.setMockInitialValues({'home_explainer_banner_dismissed': true});

    await tester.pumpWidget(_wrap(const HomeExplainerBanner()));
    await tester.pumpAndSettle();

    expect(find.text('ดู → แชร์ → ค้นพบ → ซื้อ'), findsNothing);
  });

  testWidgets('tapping X hides it and persists the pref', (tester) async {
    await tester.pumpWidget(_wrap(const HomeExplainerBanner()));
    await tester.pumpAndSettle();
    expect(find.text('ดู → แชร์ → ค้นพบ → ซื้อ'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('ดู → แชร์ → ค้นพบ → ซื้อ'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('home_explainer_banner_dismissed'), isTrue);
  });
}
