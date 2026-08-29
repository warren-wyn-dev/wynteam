import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/presentation/widgets/wynos_image_carousel.dart';

/// Isolation test for the still-unexplained "double-tap anywhere in the
/// carousel likes the post" failure in home_feed_screen_test.dart: mounts
/// [WynosImageCarousel] alone (no HomeDropCard, no HomeFeedScreen, no
/// network images) to find out whether the double-tap recognizer itself
/// fails to fire inside a PageView, independent of anything in the wider
/// card/screen context.
void main() {
  Widget buildTarget({
    required VoidCallback onLike,
    required bool alreadyLiked,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: WynosImageCarousel(
            imageUrls: const [
              'https://example.supabase.co/drops/a.jpg',
              'https://example.supabase.co/drops/b.jpg',
            ],
            onLike: onLike,
            alreadyLiked: alreadyLiked,
          ),
        ),
      );

  testWidgets(
      'a double tap on the first page (inside a PageView) calls onLike once',
      (tester) async {
    var likeCalls = 0;
    await tester.pumpWidget(
      buildTarget(onLike: () => likeCalls++, alreadyLiked: false),
    );
    await tester.pumpAndSettle();
    tester.takeException();

    final center = tester.getCenter(find.byType(WynosImageCarousel));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump();

    expect(likeCalls, 1);

    await tester.pumpAndSettle();
  }, semanticsEnabled: false);
}
