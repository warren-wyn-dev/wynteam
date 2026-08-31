import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/data/home_liker.dart';
import 'package:wyn/features/home/presentation/widgets/liked_by_row.dart';

/// WYNOSHomeSpec.md 4.8 -- stacked mini-avatars + "ถูกใจโดย ..." text.
void main() {
  testWidgets('renders nothing when there are no likers', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: LikedByRow(likedBy: [], totalLikeCount: 0),
      ),
    ));

    expect(find.byType(LikedByRow), findsOneWidget);
    expect(tester.getSize(find.byType(LikedByRow)), Size.zero);
  });

  testWidgets('shows the first liker\'s name with no "และอีก" suffix '
      'when the count exactly matches the shown likers', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: LikedByRow(
          likedBy: [
            HomeLiker(id: 'u1', username: 'warren', displayName: 'Warren'),
            HomeLiker(id: 'u2', username: 'zen', displayName: 'Zen'),
          ],
          totalLikeCount: 2,
        ),
      ),
    ));

    expect(find.textContaining('Warren'), findsOneWidget);
    expect(find.textContaining('และอีก'), findsNothing);
  });

  testWidgets('appends "และอีก N คน" when more people liked than are shown',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: LikedByRow(
          likedBy: [
            HomeLiker(id: 'u1', username: 'warren', displayName: 'Warren'),
            HomeLiker(id: 'u2', username: 'zen', displayName: 'Zen'),
            HomeLiker(id: 'u3', username: 'som', displayName: 'Som'),
          ],
          totalLikeCount: 10,
        ),
      ),
    ));

    expect(find.textContaining('และอีก 7 คน'), findsOneWidget);
  });

  testWidgets('caps the stacked avatars at 3 even with more likers passed in',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: LikedByRow(
          likedBy: [
            HomeLiker(id: 'u1', username: 'a', displayName: 'A'),
            HomeLiker(id: 'u2', username: 'b', displayName: 'B'),
            HomeLiker(id: 'u3', username: 'c', displayName: 'C'),
            HomeLiker(id: 'u4', username: 'd', displayName: 'D'),
          ],
          totalLikeCount: 4,
        ),
      ),
    ));

    // 4 likers passed in, but only the first 3 get a mini-avatar --
    // each renders its fallback-initial letter as Text.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsNothing);
  });
}
