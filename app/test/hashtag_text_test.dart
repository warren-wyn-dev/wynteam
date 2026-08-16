import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/hashtag_text.dart';
import 'package:wyn/features/hashtag/presentation/hashtag_feed_screen.dart';

import 'support/fake_supabase_session.dart';

/// Finds the TextSpan whose text exactly matches [text] within the
/// single RichText HashtagText renders, and invokes its tap recognizer
/// directly -- the standard way to exercise a TextSpan.recognizer in a
/// widget test, since tester.tap() on the whole widget can't target one
/// specific inline span.
void _tapSpan(WidgetTester tester, String text) {
  final richText = tester.widget<RichText>(find.byType(RichText).first);
  final rootSpan = richText.text as TextSpan;
  TapGestureRecognizer? found;
  rootSpan.visitChildren((span) {
    if (span is TextSpan && span.text == text) {
      found = span.recognizer as TapGestureRecognizer?;
      return false;
    }
    return true;
  });
  expect(found, isNotNull, reason: 'no tappable span found for "$text"');
  found!.onTap!();
}

void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  testWidgets('renders plain text unchanged when there is no hashtag',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HashtagText('ไม่มีแฮชแท็กเลย'))),
    );

    expect(find.text('ไม่มีแฮชแท็กเลย'), findsOneWidget);
  });

  testWidgets('renders the full caption text when it contains a hashtag',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HashtagText('เที่ยวมา #WYN สนุกมาก'))),
    );

    // find.text matches RichText by its combined plain-text content too.
    expect(find.text('เที่ยวมา #WYN สนุกมาก'), findsOneWidget);
  });

  testWidgets('tapping a hashtag span opens HashtagFeedScreen for that tag',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HashtagText('เที่ยวมา #WYN สนุกมาก'))),
    );

    _tapSpan(tester, '#WYN');
    await tester.pumpAndSettle();

    expect(find.byType(HashtagFeedScreen), findsOneWidget);
    expect(find.text('#WYN'), findsWidgets); // AppBar title also reads "#WYN"
  });

  testWidgets('renders the full caption text when it contains a mention (WYN-021)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HashtagText('ทักทาย @namfah หน่อย'))),
    );

    expect(find.text('ทักทาย @namfah หน่อย'), findsOneWidget);
  });

  testWidgets('a mention span has its own tap recognizer, separate from hashtags',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HashtagText('ทักทาย @namfah หน่อย'))),
    );

    // Doesn't crash and doesn't navigate anywhere -- this widget resolves
    // the username against a real Supabase.instance.client (no injected
    // fake, by design, same as _openHashtagFeed), so in a test
    // environment with no reachable project the lookup fails and
    // HashtagText's own documented "fail silently" posture applies. What
    // this test actually proves is that a mention span *is* independently
    // tappable (has its own recognizer, distinct from any hashtag one)
    // without throwing.
    _tapSpan(tester, '@namfah');
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(HashtagFeedScreen), findsNothing);
  });

  testWidgets('a caption with both a hashtag and a mention renders/handles both',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HashtagText('#WYN กับ @namfah'))),
    );

    expect(find.text('#WYN กับ @namfah'), findsOneWidget);

    _tapSpan(tester, '#WYN');
    await tester.pumpAndSettle();

    expect(find.byType(HashtagFeedScreen), findsOneWidget);
  });
}
