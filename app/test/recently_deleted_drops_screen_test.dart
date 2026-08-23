import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/recently_deleted_drops_screen.dart';

import 'support/recording_drop_repository.dart';

Drop _deletedDrop({
  String id = 'd1',
  String? imageUrl = 'https://example.com/d1.jpg',
  String? caption = 'แคปชัน',
}) =>
    Drop(
      id: id,
      authorId: 'u1',
      authorUsername: 'namfah',
      imageUrl: imageUrl,
      caption: caption,
      createdAt: DateTime(2026, 1, 1),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
      deletedAt: DateTime(2026, 1, 2),
    );

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  // Constructed in setUpAll, not inline per-test -- see
  // .wyn/learning/PATTERNS.md (GoTrue auto-refresh Timer leak).
  late RecordingDropRepository emptyRepo;
  late RecordingDropRepository listRepo;
  late RecordingDropRepository errorRepo;
  late RecordingDropRepository restoreRepo;
  late RecordingDropRepository restoreFailRepo;
  late RecordingDropRepository pollDraftRepo;

  setUpAll(() {
    emptyRepo = RecordingDropRepository();
    listRepo = RecordingDropRepository()
      ..deletedDropsToReturn = [_deletedDrop(id: 'd1'), _deletedDrop(id: 'd2')];
    errorRepo = RecordingDropRepository()..fetchDeletedDropsError = Exception('boom');
    restoreRepo = RecordingDropRepository()
      ..deletedDropsToReturn = [_deletedDrop(id: 'd1'), _deletedDrop(id: 'd2')];
    restoreFailRepo = RecordingDropRepository()
      ..deletedDropsToReturn = [_deletedDrop(id: 'd1')]
      ..restoreDropError = Exception('network error');
    pollDraftRepo = RecordingDropRepository()
      ..deletedDropsToReturn = [_deletedDrop(id: 'd1', imageUrl: null)];
  });

  testWidgets('shows a loading spinner, then the empty state when there '
      'are no deleted Drops', (tester) async {
    await tester.pumpWidget(_wrap(RecentlyDeletedDropsScreen(dropRepository: emptyRepo)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('ไม่มี Drop ที่ลบไว้'), findsOneWidget);
  });

  testWidgets('shows every deleted Drop returned by fetchDeletedDrops',
      (tester) async {
    await tester.pumpWidget(_wrap(RecentlyDeletedDropsScreen(dropRepository: listRepo)));
    await tester.pumpAndSettle();
    tester.takeException(); // NetworkImageLoadException -- no real network in tests.

    expect(listRepo.fetchDeletedDropsCalls, 1);
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.widgetWithText(OutlinedButton, 'กู้คืน'), findsNWidgets(2));
  });

  testWidgets('a fetch failure shows an error with a retry button',
      (tester) async {
    await tester.pumpWidget(_wrap(RecentlyDeletedDropsScreen(dropRepository: errorRepo)));
    await tester.pumpAndSettle();

    expect(find.text('โหลดรายการที่ลบไม่สำเร็จ'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'ลองใหม่'), findsOneWidget);
  });

  testWidgets('tapping กู้คืน removes the row and calls restoreDrop',
      (tester) async {
    await tester.pumpWidget(_wrap(RecentlyDeletedDropsScreen(dropRepository: restoreRepo)));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.widgetWithText(OutlinedButton, 'กู้คืน').first);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(restoreRepo.restoreDropCalls, ['d1']);
    expect(find.byType(ListTile), findsNWidgets(1));
  });

  testWidgets('a failed restore reverts the row and shows a snackbar',
      (tester) async {
    await tester.pumpWidget(_wrap(RecentlyDeletedDropsScreen(dropRepository: restoreFailRepo)));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.widgetWithText(OutlinedButton, 'กู้คืน'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('กู้คืนไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(1));
  });

  testWidgets('a poll-mode deleted Drop (no image) shows the placeholder, '
      'not a broken Image.network', (tester) async {
    await tester.pumpWidget(_wrap(RecentlyDeletedDropsScreen(dropRepository: pollDraftRepo)));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
  });
}
