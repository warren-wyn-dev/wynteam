import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/presentation/widgets/wynos_double_tap_like.dart';

void main() {
  Widget buildTarget({
    required VoidCallback onLike,
    required bool alreadyLiked,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: WynosDoubleTapLike(
            onLike: onLike,
            alreadyLiked: alreadyLiked,
            // Must actually paint something -- see
            // double_tap_like_test.dart's identical doc comment.
            child: Container(width: 200, height: 200, color: Colors.blue),
          ),
        ),
      );

  testWidgets(
      'a double tap on an unliked post calls onLike once and shows the '
      'heart-burst (WYNOS Home reference spec 4.7)', (tester) async {
    var likeCalls = 0;
    await tester.pumpWidget(
      buildTarget(onLike: () => likeCalls++, alreadyLiked: false),
    );

    expect(find.byKey(const Key('wynos_double_tap_heart')), findsNothing);

    final center = tester.getCenter(find.byType(WynosDoubleTapLike));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump();

    expect(likeCalls, 1);
    expect(find.byKey(const Key('wynos_double_tap_heart')), findsOneWidget);

    // Let the heart's animation run to completion before the test ends --
    // otherwise its still-ticking AnimationController trips flutter_test's
    // "no pending timers at teardown" invariant check.
    await tester.pumpAndSettle();
  });

  testWidgets(
      'a double tap on an already-liked post shows the heart-burst again '
      'but never calls onLike a second time (no duplicate Like)',
      (tester) async {
    var likeCalls = 0;
    await tester.pumpWidget(
      buildTarget(onLike: () => likeCalls++, alreadyLiked: true),
    );

    final center = tester.getCenter(find.byType(WynosDoubleTapLike));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump();

    expect(likeCalls, 0);
    expect(find.byKey(const Key('wynos_double_tap_heart')), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('the heart fades out and disappears after the animation ends',
      (tester) async {
    await tester.pumpWidget(
      buildTarget(onLike: () {}, alreadyLiked: true),
    );

    final center = tester.getCenter(find.byType(WynosDoubleTapLike));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump();
    expect(find.byKey(const Key('wynos_double_tap_heart')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wynos_double_tap_heart')), findsNothing);
  });

  testWidgets('a single tap alone never calls onLike', (tester) async {
    var likeCalls = 0;
    await tester.pumpWidget(
      buildTarget(onLike: () => likeCalls++, alreadyLiked: false),
    );

    await tester.tap(find.byType(WynosDoubleTapLike));
    // Long enough to fall outside the double-tap window without ever
    // resolving a 2nd tap.
    await tester.pump(const Duration(milliseconds: 500));

    expect(likeCalls, 0);
    expect(find.byKey(const Key('wynos_double_tap_heart')), findsNothing);
  });

  testWidgets(
      'the heart-burst uses the spec\'s exact 72px size and paper color',
      (tester) async {
    await tester.pumpWidget(
      buildTarget(onLike: () {}, alreadyLiked: true),
    );

    final center = tester.getCenter(find.byType(WynosDoubleTapLike));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump();

    final icon = tester.widget<Icon>(
      find.byKey(const Key('wynos_double_tap_heart')),
    );
    expect(icon.icon, Icons.favorite);
    expect(icon.size, 72);
    expect(icon.color, const Color(0xFFFAF9F6));

    await tester.pumpAndSettle();
  });
}
