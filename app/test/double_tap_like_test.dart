import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/double_tap_like.dart';

void main() {
  Widget buildTarget({
    required VoidCallback onLike,
    required bool alreadyLiked,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: DoubleTapLike(
            onLike: onLike,
            alreadyLiked: alreadyLiked,
            // Must actually paint something -- an empty SizedBox never
            // hit-tests true on its own (RenderProxyBox.hitTestSelf
            // defaults to false with no child/paint of its own), so the
            // wrapping GestureDetector's default HitTestBehavior.deferToChild
            // would never receive a tap at all. Every real caller passes a
            // real Image/HashtagText here, which always paints.
            child: Container(width: 200, height: 200, color: Colors.blue),
          ),
        ),
      );

  testWidgets(
      'a double tap on an unliked post calls onLike once and shows the '
      'heart animation (WYNOS V1.0.0 Beta requirement 4)', (tester) async {
    var likeCalls = 0;
    await tester.pumpWidget(
      buildTarget(onLike: () => likeCalls++, alreadyLiked: false),
    );

    expect(find.byKey(const Key('double_tap_heart')), findsNothing);

    final center = tester.getCenter(find.byType(DoubleTapLike));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump();

    expect(likeCalls, 1);
    expect(find.byKey(const Key('double_tap_heart')), findsOneWidget);

    // Let the heart's animation run to completion before the test ends
    // -- otherwise its still-ticking AnimationController trips flutter_test's
    // "no pending timers at teardown" invariant check.
    await tester.pumpAndSettle();
  });

  testWidgets(
      'a double tap on an already-liked post shows the heart animation '
      'again but never calls onLike a second time (no duplicate Like)',
      (tester) async {
    var likeCalls = 0;
    await tester.pumpWidget(
      buildTarget(onLike: () => likeCalls++, alreadyLiked: true),
    );

    final center = tester.getCenter(find.byType(DoubleTapLike));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump();

    expect(likeCalls, 0);
    expect(find.byKey(const Key('double_tap_heart')), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('the heart fades out and disappears after the animation ends',
      (tester) async {
    await tester.pumpWidget(
      buildTarget(onLike: () {}, alreadyLiked: true),
    );

    final center = tester.getCenter(find.byType(DoubleTapLike));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump();
    expect(find.byKey(const Key('double_tap_heart')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('double_tap_heart')), findsNothing);
  });

  testWidgets('a single tap alone never calls onLike', (tester) async {
    var likeCalls = 0;
    await tester.pumpWidget(
      buildTarget(onLike: () => likeCalls++, alreadyLiked: false),
    );

    await tester.tap(find.byType(DoubleTapLike));
    // Long enough to fall outside the double-tap window without ever
    // resolving a 2nd tap.
    await tester.pump(const Duration(milliseconds: 500));

    expect(likeCalls, 0);
    expect(find.byKey(const Key('double_tap_heart')), findsNothing);
  });
}
