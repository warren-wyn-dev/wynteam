import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/widgets/drop_image_viewer.dart';

import 'support/recording_drop_repository.dart';

/// 20-image-viewer.tsx's like/share/save action row under the dots.
/// DropImageViewer keeps its own local like/save state (a separate
/// pushed route from DropDetailScreen) -- see the widget's own doc
/// comment for why -- so this exercises that toggle+revert logic
/// directly, the same way drop_detail_screen_test.dart exercises
/// DropDetailScreen's own copy of it.
void main() {
  // Constructed in setUp, not inline inside a testWidgets body -- see
  // drop_image_gallery_test.dart's own doc comment on why (avoids
  // tripping flutter_test's `!timersPending` invariant).
  late RecordingDropRepository dropRepo;

  setUp(() {
    dropRepo = RecordingDropRepository();
  });

  Drop drop({bool likedByMe = false, bool savedByMe = false}) => Drop(
        id: 'd1',
        authorId: 'someone-else',
        authorUsername: 'namfah',
        imageUrl: 'https://example.supabase.co/drops/d1_0.jpg',
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: likedByMe,
        savedByMe: savedByMe,
      );

  Widget buildViewer({
    required Drop drop,
    required ValueChanged<Drop> onDropChanged,
  }) =>
      MaterialApp(
        home: DropImageViewer(
          drop: drop,
          imageUrls: [drop.imageUrl!],
          dropRepository: dropRepo,
          onDropChanged: onDropChanged,
        ),
      );

  testWidgets('shows the like/share/save action row with real drop state',
      (tester) async {
    await tester.pumpWidget(buildViewer(drop: drop(), onDropChanged: (_) {}));
    tester.takeException();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.send_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('an already-liked/saved Drop shows the filled icons',
      (tester) async {
    await tester.pumpWidget(buildViewer(
      drop: drop(likedByMe: true, savedByMe: true),
      onDropChanged: (_) {},
    ));
    tester.takeException();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets(
      'tapping the heart toggles the icon, calls toggleLike, and reports '
      'the updated Drop via onDropChanged', (tester) async {
    Drop? reported;
    await tester.pumpWidget(buildViewer(
      drop: drop(),
      onDropChanged: (updated) => reported = updated,
    ));
    tester.takeException();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(dropRepo.toggleLikeCalls, 1);
    expect(dropRepo.toggleLikeCurrentlyLikedArgs, [false]);
    expect(reported?.likedByMe, isTrue);
  });

  testWidgets('a failed toggleLike reverts the icon and reports the revert',
      (tester) async {
    dropRepo.toggleLikeError = Exception('network');
    final reports = <bool>[];
    await tester.pumpWidget(buildViewer(
      drop: drop(),
      onDropChanged: (updated) => reports.add(updated.likedByMe),
    ));
    tester.takeException();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(reports, [true, false]);
  });

  testWidgets(
      'tapping the bookmark toggles the icon, calls toggleSave, and '
      'reports the updated Drop via onDropChanged', (tester) async {
    Drop? reported;
    await tester.pumpWidget(buildViewer(
      drop: drop(),
      onDropChanged: (updated) => reported = updated,
    ));
    tester.takeException();

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(dropRepo.toggleSaveCalls, 1);
    expect(reported?.savedByMe, isTrue);
  });
}
