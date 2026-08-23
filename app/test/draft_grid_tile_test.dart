import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop_draft.dart';
import 'package:wyn/features/drop/presentation/widgets/draft_grid_tile.dart';
import 'package:wyn/features/drop/presentation/widgets/poll_placeholder_tile.dart';

DropDraft _imageDraft() => DropDraft(
      id: 'd1',
      imageUrl: 'https://example.com/draft.jpg',
      caption: 'แคปชัน',
      updatedAt: DateTime(2026, 1, 1),
    );

DropDraft _pollDraft() => DropDraft(
      id: 'd2',
      caption: 'คำถาม',
      pollOptions: const ['A', 'B'],
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('an image draft shows the image, a poll draft shows the '
      'placeholder', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            DraftGridTile(draft: _imageDraft(), onTap: () {}, onDelete: () {}),
            DraftGridTile(draft: _pollDraft(), onTap: () {}, onDelete: () {}),
          ],
        ),
      ),
    ));
    tester.takeException();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(PollPlaceholderTile), findsOneWidget);
  });

  testWidgets('tapping calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DraftGridTile(
          draft: _pollDraft(),
          onTap: () => tapped = true,
          onDelete: () {},
        ),
      ),
    ));

    await tester.tap(find.byType(DraftGridTile));
    expect(tapped, isTrue);
  });

  testWidgets('long-press shows a confirm dialog; confirming calls onDelete',
      (tester) async {
    var deleted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DraftGridTile(
          draft: _pollDraft(),
          onTap: () {},
          onDelete: () => deleted = true,
        ),
      ),
    ));

    await tester.longPress(find.byType(DraftGridTile));
    await tester.pumpAndSettle();

    expect(find.text('ลบร่างนี้?'), findsOneWidget);
    expect(deleted, isFalse);

    await tester.tap(find.widgetWithText(TextButton, 'ลบ'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });

  testWidgets('long-press then cancel does not call onDelete',
      (tester) async {
    var deleted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DraftGridTile(
          draft: _pollDraft(),
          onTap: () {},
          onDelete: () => deleted = true,
        ),
      ),
    ));

    await tester.longPress(find.byType(DraftGridTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
  });
}
