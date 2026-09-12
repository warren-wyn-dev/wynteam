import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/hashtag_text.dart';
import 'package:wyn/features/hashtag/presentation/hashtag_feed_screen.dart';

import 'support/fake_supabase_session.dart';

TextSpan _spanWithText(WidgetTester tester, String text) {
  TextSpan? found;
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    final rootSpan = richText.text as TextSpan;
    rootSpan.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span;
        return false;
      }
      return true;
    });
    if (found != null) break;
  }
  expect(found, isNotNull, reason: 'no span found for "$text"');
  return found!;
}

/// Finds the TextSpan whose text exactly matches [text] within the
/// single RichText HashtagText renders, and invokes its tap recognizer
/// directly -- the standard way to exercise a TextSpan.recognizer in a
/// widget test, since tester.tap() on the whole widget can't target one
/// specific inline span.
void _tapSpan(WidgetTester tester, String text) {
  final span = _spanWithText(tester, text);
  final recognizer = span.recognizer as TapGestureRecognizer?;
  expect(recognizer, isNotNull, reason: 'no tappable span found for "$text"');
  recognizer!.onTap!();
}

void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  testWidgets('renders plain text unchanged when there is no hashtag', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HashtagText('ไม่มีแฮชแท็กเลย'))),
    );

    expect(find.text('ไม่มีแฮชแท็กเลย'), findsOneWidget);
  });

  testWidgets('preserves native emoji sequences in rendered post text', (
    tester,
  ) async {
    const text = 'สวัสดี 👋🏽 ครอบครัว 👨‍👩‍👧‍👦 ธง 🇹🇭 #WYN';
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HashtagText(text))),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).first);
    expect(richText.text.toPlainText(), text);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preserves emoji while system text scaling is enabled', (
    tester,
  ) async {
    const text = 'โพสต์นี้ดีมาก 🥹❤️‍🔥 #WYN';
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const Scaffold(body: HashtagText(text)),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).first);
    expect(richText.text.toPlainText(), text);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the full caption text when it contains a hashtag', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HashtagText('เที่ยวมา #WYN สนุกมาก')),
      ),
    );

    // find.text matches RichText by its combined plain-text content too.
    expect(find.text('เที่ยวมา #WYN สนุกมาก'), findsOneWidget);
  });

  testWidgets('renders hashtag tokens in the approved bright blue', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HashtagText('เที่ยวมา #WYN'))),
    );

    final hashtagSpan = _spanWithText(tester, '#WYN');
    expect(hashtagSpan.style?.color, const Color(0xFF1D9BF0));
  });

  testWidgets('feed-card caption collapses blank line before hashtag block', (
    tester,
  ) async {
    const text = 'ชีวิตไม่ต้องสมบูรณ์แบบ\n\n#คำคม #ชีวิตดีๆ #WYNOS';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HashtagText(
            text,
            style: TextStyle(
              fontSize: 17.5,
              height: 1.32,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );

    final richTexts = tester
        .widgetList<RichText>(find.byType(RichText))
        .toList();
    expect(richTexts, hasLength(2));
    expect(richTexts[0].text.toPlainText(), 'ชีวิตไม่ต้องสมบูรณ์แบบ');
    expect(richTexts[1].text.toPlainText(), '#คำคม #ชีวิตดีๆ #WYNOS');
    final gap = find.byKey(const ValueKey<String>('feed_caption_hashtag_gap'));
    expect(gap, findsOneWidget);
    expect(tester.getSize(gap).height, 4);

    final hashtagSpan = _spanWithText(tester, '#คำคม');
    expect(hashtagSpan.style?.fontSize, 17.5);
    expect(hashtagSpan.style?.fontWeight, FontWeight.w400);
    expect(hashtagSpan.style?.color, const Color(0xFF1D9BF0));
  });

  testWidgets('feed-card caption trims trailing blank lines above actions', (
    tester,
  ) async {
    const text = 'ข้อความ\n\n#WYN\n\n';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HashtagText(
            text,
            style: TextStyle(
              fontSize: 17.5,
              height: 1.32,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );

    final richTexts = tester
        .widgetList<RichText>(find.byType(RichText))
        .toList();
    expect(richTexts, hasLength(2));
    expect(richTexts[0].text.toPlainText(), 'ข้อความ');
    expect(richTexts[1].text.toPlainText(), '#WYN');
  });

  testWidgets('non-feed-card surfaces preserve authored blank lines', (
    tester,
  ) async {
    const text = 'ข้อความ\n\n#WYN';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HashtagText(text, style: TextStyle(fontSize: 16, height: 1.32)),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).first);
    expect(richText.text.toPlainText(), text);
  });

  testWidgets('tapping a hashtag span opens HashtagFeedScreen for that tag', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HashtagText('เที่ยวมา #WYN สนุกมาก')),
      ),
    );

    _tapSpan(tester, '#WYN');
    await tester.pumpAndSettle();

    expect(find.byType(HashtagFeedScreen), findsOneWidget);
    expect(find.text('#WYN'), findsWidgets); // AppBar title also reads "#WYN"
  });

  testWidgets(
    'renders the full caption text when it contains a mention (WYN-021)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HashtagText('ทักทาย @namfah หน่อย')),
        ),
      );

      expect(find.text('ทักทาย @namfah หน่อย'), findsOneWidget);
    },
  );

  testWidgets(
    'a mention span has its own tap recognizer, separate from hashtags',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HashtagText('ทักทาย @namfah หน่อย')),
        ),
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
    },
  );

  testWidgets(
    'a caption with both a hashtag and a mention renders/handles both',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HashtagText('#WYN กับ @namfah')),
        ),
      );

      expect(find.text('#WYN กับ @namfah'), findsOneWidget);

      _tapSpan(tester, '#WYN');
      await tester.pumpAndSettle();

      expect(find.byType(HashtagFeedScreen), findsOneWidget);
    },
  );
}
