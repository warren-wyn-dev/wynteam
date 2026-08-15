import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/review.dart';
import 'package:wyn/features/zoky/presentation/widgets/review_form_sheet.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Regression tests for ReviewFormSheet (ZOKY-004), per
/// .wyn/docs/design/zoky-004-review.md.
void main() {
  late RecordingZokyRepository repo;
  late RecordingZokyRepository failingRepo;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    repo = RecordingZokyRepository();
    failingRepo = RecordingZokyRepository(addReviewException: Exception('network down'));
  });

  Widget buildOpener(RecordingZokyRepository zokyRepository, {Review? existingReview}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showReviewFormSheet(
              context,
              zokyRepository: zokyRepository,
              orderItemId: 'oi1',
              productId: 'p1',
              existingReview: existingReview,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester.takeException();
  }

  testWidgets('ส่งรีวิว is disabled until a star is selected', (tester) async {
    await tester.pumpWidget(buildOpener(repo));
    await openSheet(tester);

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'ส่งรีวิว'));
    expect(button.onPressed, isNull);
  });

  testWidgets('selecting a star and submitting calls addReview with the chosen rating and text',
      (tester) async {
    await tester.pumpWidget(buildOpener(repo));
    await openSheet(tester);

    // 3rd star button (index 2) selects a rating of 3.
    await tester.tap(find.byIcon(Icons.star_border).at(2));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'โอเคเลย');
    await tester.tap(find.text('ส่งรีวิว'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.lastAddReviewOrderItemId, 'oi1');
    expect(repo.lastAddReviewProductId, 'p1');
    expect(repo.lastAddReviewRating, 3);
    expect(repo.lastAddReviewTextContent, 'โอเคเลย');
    expect(find.text('บันทึกรีวิวแล้ว'), findsOneWidget);
  });

  testWidgets('submitting with an empty text field sends null textContent', (tester) async {
    await tester.pumpWidget(buildOpener(repo));
    await openSheet(tester);

    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pump();
    await tester.tap(find.text('ส่งรีวิว'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.lastAddReviewRating, 1);
    expect(repo.lastAddReviewTextContent, isNull);
  });

  testWidgets('shows an error SnackBar and keeps the sheet open when addReview fails',
      (tester) async {
    await tester.pumpWidget(buildOpener(failingRepo));
    await openSheet(tester);

    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pump();
    await tester.tap(find.text('ส่งรีวิว'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('บันทึกรีวิวไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    // Sheet stays open -- the submit button is still there.
    expect(find.text('ส่งรีวิว'), findsOneWidget);
  });

  testWidgets('editing mode pre-fills the existing rating/text and shows ลบรีวิว',
      (tester) async {
    final existing = Review(
      id: 'r1',
      orderItemId: 'oi1',
      productId: 'p1',
      userId: 'me',
      authorUsername: 'me',
      rating: 4,
      textContent: 'เดิมพันดี',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(buildOpener(repo, existingReview: existing));
    await openSheet(tester);

    expect(find.text('แก้ไขรีวิว'), findsWidgets);
    expect(find.text('เดิมพันดี'), findsOneWidget);
    expect(find.text('บันทึกการแก้ไข'), findsOneWidget);
    expect(find.text('ลบรีวิว'), findsOneWidget);

    // ส่งรีวิว should already be enabled since a rating is pre-filled.
    final button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'บันทึกการแก้ไข'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('editing and submitting calls editReview, not addReview', (tester) async {
    final existing = Review(
      id: 'r1',
      orderItemId: 'oi1',
      productId: 'p1',
      userId: 'me',
      authorUsername: 'me',
      rating: 4,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(buildOpener(repo, existingReview: existing));
    await openSheet(tester);

    // Change from 4 stars to 2 stars.
    await tester.tap(find.byIcon(Icons.star).at(1));
    await tester.pump();

    await tester.tap(find.text('บันทึกการแก้ไข'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.lastEditReviewId, 'r1');
    expect(repo.lastEditReviewRating, 2);
    expect(repo.lastAddReviewOrderItemId, isNull);
  });

  testWidgets('dismissing the delete confirmation dialog does not call deleteReview',
      (tester) async {
    final existing = Review(
      id: 'r1',
      orderItemId: 'oi1',
      productId: 'p1',
      userId: 'me',
      authorUsername: 'me',
      rating: 4,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(buildOpener(repo, existingReview: existing));
    await openSheet(tester);

    await tester.tap(find.text('ลบรีวิว'));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.lastDeleteReviewId, isNull);
  });

  testWidgets('confirming the delete dialog calls deleteReview with the review id',
      (tester) async {
    final existing = Review(
      id: 'r1',
      orderItemId: 'oi1',
      productId: 'p1',
      userId: 'me',
      authorUsername: 'me',
      rating: 4,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(buildOpener(repo, existingReview: existing));
    await openSheet(tester);

    await tester.tap(find.text('ลบรีวิว'));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.widgetWithText(TextButton, 'ลบ'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.lastDeleteReviewId, 'r1');
    expect(find.text('ลบรีวิวแล้ว'), findsOneWidget);
  });
}
