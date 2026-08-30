import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/data/home_top_reply.dart';
import 'package:wyn/features/home/presentation/widgets/top_reply_preview.dart';

/// WYNOSHomeSpec.md 4.10.
void main() {
  testWidgets('shows the replier name and comment text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TopReplyPreview(
          reply: const HomeTopReply(
            authorUsername: 'zen',
            authorDisplayName: 'Zen',
            text: 'สวยมากกก',
          ),
          onTap: () {},
        ),
      ),
    ));

    expect(find.textContaining('Zen'), findsOneWidget);
    expect(find.textContaining('สวยมากกก'), findsOneWidget);
  });

  testWidgets('tapping it calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TopReplyPreview(
          reply: const HomeTopReply(authorUsername: 'zen', text: 'เจ๋ง'),
          onTap: () => tapped = true,
        ),
      ),
    ));

    await tester.tap(find.byType(TopReplyPreview));
    expect(tapped, isTrue);
  });
}
