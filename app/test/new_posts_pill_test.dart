import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/presentation/widgets/new_posts_pill.dart';

/// WYNOSHomeSpec.md 4.4.
void main() {
  // WYN-091 (Wynos V1.0.0 Beta2 Phase 2, item 13): the visible text is a
  // constant "มีโพสต์ใหม่" now, with no count -- Founder explicitly
  // asked for the number to be dropped from what's shown on screen.
  testWidgets('shows the icon and constant "มีโพสต์ใหม่" text (no count)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NewPostsPill(count: 5, onTap: () {}),
      ),
    ));

    expect(find.text('มีโพสต์ใหม่'), findsOneWidget);
    expect(find.text('มีโพสต์ใหม่ 5 โพสต์'), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  // Accessibility (WYN-091 design spec): the count is dropped only from
  // the *visible* text -- screen reader users still get the precise
  // number via the Semantics label.
  testWidgets('Semantics label still carries the count for screen readers',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NewPostsPill(count: 5, onTap: () {}),
      ),
    ));

    expect(
      find.bySemanticsLabel('มีโพสต์ใหม่ 5 โพสต์ กดเพื่อโหลด'),
      findsOneWidget,
    );
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
