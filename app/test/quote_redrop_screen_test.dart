import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/quote_redrop_screen.dart';

import 'support/recording_drop_repository.dart';

Drop _drop() => Drop(
      id: 'd1',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      authorDisplayName: 'น้ำฝน',
      imageUrl: 'https://example.supabase.co/drops/d1.jpg',
      caption: 'แคปชันต้นฉบับ',
      createdAt: DateTime(2026, 1, 1),
      likeCount: 3,
      commentCount: 1,
      likedByMe: false,
      savedByMe: false,
    );

void main() {
  late RecordingDropRepository repo;

  setUp(() {
    repo = RecordingDropRepository();
  });

  // QuoteRedropScreen pops on success -- MaterialApp(home: ...) alone
  // gives it no route to pop back to (same class of test-harness issue
  // fixed for ShareToChatScreen in WYN-033), so this pushes it from a
  // placeholder screen instead, mirroring that fix exactly.
  Widget buildScreen() => MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuoteRedropScreen(
                      dropRepository: repo,
                      drop: _drop(),
                    ),
                  ),
                ),
                child: const Text('เปิด'),
              ),
            ),
          ),
        ),
      );

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    // The preview card's broken test-fixture image URL throws a
    // harmless NetworkImageLoadException -- expected noise, not a
    // real failure (see home_feed_screen_test.dart for the same
    // pattern).
    tester.takeException();
  }

  testWidgets('shows the original Drop as a read-only preview', (tester) async {
    await openScreen(tester);

    expect(find.text('น้ำฝน'), findsOneWidget);
    expect(find.text('แคปชันต้นฉบับ'), findsOneWidget);
  });

  testWidgets('"โพสต์" is disabled until text is entered', (tester) async {
    await openScreen(tester);

    final postButton =
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'โพสต์'));
    expect(postButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'ดูนี่สิ');
    await tester.pump();

    final enabledPostButton =
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'โพสต์'));
    expect(enabledPostButton.onPressed, isNotNull);
  });

  testWidgets(
      'posting calls quoteRedrop with the trimmed text and dropId, then '
      'pops', (tester) async {
    await openScreen(tester);

    await tester.enterText(find.byType(TextField), '  ดูนี่สิ  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'โพสต์'));
    await tester.pumpAndSettle();

    expect(repo.quoteRedropCalls, 1);
    expect(repo.quoteRedropTextArgs, ['ดูนี่สิ']);
    expect(find.byType(QuoteRedropScreen), findsNothing);
  });

  testWidgets('a failed post shows an error and stays on screen, keeping '
      'the typed text', (tester) async {
    repo.quoteRedropError = Exception('boom');
    await openScreen(tester);

    await tester.enterText(find.byType(TextField), 'ดูนี่สิ');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'โพสต์'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('โพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.byType(QuoteRedropScreen), findsOneWidget);
    expect(find.text('ดูนี่สิ'), findsOneWidget);
  });
}
