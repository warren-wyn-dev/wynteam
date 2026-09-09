import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/design/wyn_theme.dart';
import 'package:wyn/features/home/data/home_liker.dart';
import 'package:wyn/features/home/data/home_top_reply.dart';
import 'package:wyn/features/home/presentation/widgets/liked_by_row.dart';
import 'package:wyn/features/home/presentation/widgets/top_reply_preview.dart';

Widget _scaledApp({required double textScale, required Widget child}) {
  return MaterialApp(
    theme: WynTheme.light,
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: const Size(390, 844),
        textScaler: TextScaler.linear(textScale),
      ),
      child: appChild!,
    ),
    home: Scaffold(
      body: SizedBox(width: 390, child: child),
    ),
  );
}

Text _textWithPlainSpan(WidgetTester tester, String expected) {
  return tester.widget<Text>(
    find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.textSpan?.toPlainText() == expected,
    ),
  );
}

void main() {
  const liker = HomeLiker(
    id: 'liker-1',
    username: 'namfah',
    displayName: 'น้ำฟ้า 👋🏽',
  );

  const reply = HomeTopReply(
    authorUsername: 'mali',
    authorDisplayName: 'มะลิ 🥹',
    text: 'ชอบโพสต์นี้มาก 👨‍👩‍👧‍👦 🇹🇭',
  );

  test('theme keeps the looped Thai family in the fallback chain', () {
    expect(
      WynTheme.light.textTheme.bodyLarge?.fontFamilyFallback,
      contains('WYNThaiLooped'),
    );
    expect(
      WynTheme.dark.textTheme.labelSmall?.fontFamilyFallback,
      contains('WYNThaiLooped'),
    );
  });

  testWidgets('liked-by metadata uses the shared labelSmall token',
      (tester) async {
    await tester.pumpWidget(
      _scaledApp(
        textScale: 1,
        child: const LikedByRow(
          likedBy: [liker],
          totalLikeCount: 3,
        ),
      ),
    );

    final text = _textWithPlainSpan(tester, 'ถูกใจโดย น้ำฟ้า 👋🏽 และอีก 2 คน');
    expect(text.textSpan?.style?.fontSize, 13);
    expect(tester.takeException(), isNull);
  });

  testWidgets('top reply preview uses the shared bodyMedium token',
      (tester) async {
    await tester.pumpWidget(
      _scaledApp(
        textScale: 1,
        child: TopReplyPreview(reply: reply, onTap: () {}),
      ),
    );

    final text = _textWithPlainSpan(
      tester,
      'มะลิ 🥹 ชอบโพสต์นี้มาก 👨‍👩‍👧‍👦 🇹🇭',
    );
    expect(text.textSpan?.style?.fontSize, 15);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.3, 1.5, 2.0]) {
    testWidgets('home metadata survives iOS-style text scaling at $scale',
        (tester) async {
      await tester.pumpWidget(
        _scaledApp(
          textScale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LikedByRow(
                likedBy: [liker],
                totalLikeCount: 3,
              ),
              TopReplyPreview(reply: reply, onTap: () {}),
            ],
          ),
        ),
      );

      expect(find.textContaining('น้ำฟ้า'), findsOneWidget);
      expect(find.textContaining('มะลิ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
