import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/profile/presentation/widgets/avatar_circle.dart';

void main() {
  testWidgets('shows the first letter of fallbackText when imageUrl is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AvatarCircle(imageUrl: null, fallbackText: 'namfah'),
      ),
    ));

    expect(find.text('N'), findsOneWidget);
    expect(find.bySemanticsLabel('รูปโปรไฟล์ของ namfah'), findsOneWidget);
  });

  testWidgets('shows "?" when fallbackText is empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AvatarCircle(imageUrl: null, fallbackText: '')),
    ));

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('uses a NetworkImage instead of the letter when imageUrl is set',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AvatarCircle(
          imageUrl: 'https://example.supabase.co/avatars/u1/avatar.jpg',
          fallbackText: 'namfah',
        ),
      ),
    ));
    // The test environment has no real network access, so resolving the
    // NetworkImage throws -- expected, and irrelevant to what this test
    // checks (that the widget is wired up to load from a NetworkImage).
    tester.takeException();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<NetworkImage>());
    expect(find.text('N'), findsNothing);
  });
}
