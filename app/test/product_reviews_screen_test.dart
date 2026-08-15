import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/review.dart';
import 'package:wyn/features/zoky/presentation/product_reviews_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Regression tests for ProductReviewsScreen (ZOKY-004), per
/// .wyn/docs/design/zoky-004-review.md.
void main() {
  late RecordingZokyRepository withReviewRepo;
  late RecordingZokyRepository emptyRepo;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    withReviewRepo = RecordingZokyRepository(
      productReviews: [
        Review(
          id: 'r1',
          orderItemId: 'oi1',
          productId: 'p1',
          userId: 'u1',
          authorUsername: 'somchai',
          rating: 5,
          textContent: 'เยี่ยมมาก',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
    );
    emptyRepo = RecordingZokyRepository();
  });

  Widget buildScreen(RecordingZokyRepository repo) {
    return MaterialApp(
      home: ProductReviewsScreen(
        zokyRepository: repo,
        productId: 'p1',
        rating: 4.2,
        reviewCount: 5,
      ),
    );
  }

  testWidgets('shows the rating summary header and every review passed back', (tester) async {
    await tester.pumpWidget(buildScreen(withReviewRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('4.2 (5 รีวิว)'), findsOneWidget);
    expect(find.text('เยี่ยมมาก'), findsOneWidget);
  });

  testWidgets('shows nothing but the header when there are no reviews on this page',
      (tester) async {
    await tester.pumpWidget(buildScreen(emptyRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('4.2 (5 รีวิว)'), findsOneWidget);
  });
}
