import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/presentation/widgets/verified_badge.dart';

/// WYNOSHomeSpec.md 4.9/4.6.
void main() {
  testWidgets('renders a verified icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: VerifiedBadge()),
    ));

    expect(find.byIcon(Icons.verified), findsOneWidget);
  });
}
