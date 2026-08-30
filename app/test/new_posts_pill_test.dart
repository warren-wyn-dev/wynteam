import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/presentation/widgets/new_posts_pill.dart';

/// WYNOSHomeSpec.md 4.4.
void main() {
  testWidgets('shows the icon and "มีโพสต์ใหม่ {N} โพสต์" text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NewPostsPill(count: 5, onTap: () {}),
      ),
    ));

    expect(find.text('มีโพสต์ใหม่ 5 โพสต์'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  testWidgets('tapping it calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NewPostsPill(count: 1, onTap: () => tapped = true),
      ),
    ));

    await tester.tap(find.byType(NewPostsPill));
    expect(tapped, isTrue);
  });
}
