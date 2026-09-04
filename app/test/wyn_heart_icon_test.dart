import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/core/design/wyn_colors.dart';
import 'package:wyn/core/widgets/action_metric.dart';
import 'package:wyn/core/widgets/wyn_heart_icon.dart';

void main() {
  // WYN-108. The heart is WYN's own shape now rather than Material's --
  // the reference design always specified lucide's, the implementation
  // just reached for the icon set that was already there. Founder,
  // 2026-09-04: "รูปหัวใจ ทำสวยๆหน่อย".
  group('WynHeartIcon', () {
    testWidgets('takes exactly the size it is given', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Center(
          child: WynHeartIcon(
            filled: false,
            size: 17,
            color: WynColors.iconIdle,
          ),
        ),
      ));
      expect(tester.getSize(find.byType(WynHeartIcon)), const Size(17, 17));
    });

    testWidgets('repaints when the like state, colour or shadow changes',
        (tester) async {
      // A painter that says it never needs repainting would leave a
      // just-liked heart drawn in its old state.
      Future<CustomPainter> painterFor(Widget heart) async {
        await tester.pumpWidget(MaterialApp(home: Center(child: heart)));
        return tester
            .widget<CustomPaint>(find.descendant(
              of: find.byType(WynHeartIcon),
              matching: find.byType(CustomPaint),
            ))
            .painter!;
      }

      final idle = await painterFor(const WynHeartIcon(
          filled: false, size: 17, color: WynColors.iconIdle));
      final liked = await painterFor(const WynHeartIcon(
          filled: true, size: 17, color: WynColors.iconLikeActive));
      final shadowed = await painterFor(const WynHeartIcon(
        filled: true,
        size: 17,
        color: WynColors.iconLikeActive,
        shadows: [Shadow(blurRadius: 16)],
      ));

      expect(liked.shouldRepaint(idle), isTrue);
      expect(shadowed.shouldRepaint(liked), isTrue);
      // ...and stays quiet when nothing about it changed.
      expect(liked.shouldRepaint(liked), isFalse);
    });

    testWidgets('draws without throwing at every size the app asks for',
        (tester) async {
      // 10 in a notification badge, 13 on a grid tile, 16/17/18/19/22 in
      // the various action bars, 24 on a comment row, 72 for the
      // double-tap burst.
      for (final size in [10.0, 13.0, 16.0, 17.0, 18.0, 19.0, 22.0, 24.0, 72.0]) {
        for (final filled in [true, false]) {
          await tester.pumpWidget(MaterialApp(
            home: Center(
              child: WynHeartIcon(
                filled: filled,
                size: size,
                color: WynColors.iconIdle,
              ),
            ),
          ));
          expect(tester.takeException(), isNull, reason: 'size $size');
        }
      }
    });
  });

  group('ActionMetric keeps its pop animation on the heart', () {
    // The animation used to fire on the IconData swapping between
    // favorite and favorite_border. With a widget for a glyph that
    // comparison is meaningless, so the state it keys off is passed in
    // explicitly -- and this is the guard that it is actually wired.
    Widget metric({required bool liked}) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: ActionMetric(
                icon: WynHeartIcon(
                  filled: liked,
                  size: 17,
                  color: liked
                      ? WynColors.iconLikeActive
                      : WynColors.iconIdle,
                ),
                iconState: liked,
                count: liked ? 1 : 0,
                color: WynColors.iconIdle,
                semanticsLabel: liked ? 'ถูกใจแล้ว' : 'กดเพื่อถูกใจ',
                onTap: () {},
              ),
            ),
          ),
        );

    double heartScale(WidgetTester tester) => tester
        .widget<ScaleTransition>(find.ancestor(
          of: find.byType(WynHeartIcon),
          matching: find.byType(ScaleTransition),
        ))
        .scale
        .value;

    testWidgets('the heart pops when it becomes liked', (tester) async {
      await tester.pumpWidget(metric(liked: false));
      await tester.pumpAndSettle();
      expect(heartScale(tester), 1.0);

      await tester.pumpWidget(metric(liked: true));
      await tester.pump(const Duration(milliseconds: 20));
      // Mid-animation the heart is drawn smaller than its resting size.
      expect(heartScale(tester), lessThan(1.0));

      await tester.pumpAndSettle();
      expect(heartScale(tester), 1.0);
    });

    testWidgets('a rebuild that changes nothing does not pop', (tester) async {
      // Scrolling rebuilds cards constantly; a heart that flinched every
      // time one was rebuilt would be worse than no animation at all.
      await tester.pumpWidget(metric(liked: true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(metric(liked: true));
      await tester.pump(const Duration(milliseconds: 20));
      expect(heartScale(tester), 1.0);
    });
  });
}
