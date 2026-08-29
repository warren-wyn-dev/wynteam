// Temporary debug-only isolation test -- bisecting a Flutter-internal
// semantics assertion ('!semantics.parentDataDirty') that hangs
// flutter test whenever HomeFeedScreen mounts a HomeDropCard, even
// with zero interaction. Mounts HomeDropCard directly (no
// HomeFeedScreen, no filter tabs, no banner, no SharedPreferences)
// to find out whether the card itself is the trigger or whether it's
// something in HomeFeedScreen's own surrounding chrome. Delete once
// the real root cause is found and fixed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';

void main() {
  testWidgets('isolated HomeDropCard mounts and settles without crashing',
      (tester) async {
    await initFakeSupabaseSession(userId: 'me');

    final item = HomeFeedItem(
      id: 'iso-1',
      contentType: HomeContentType.drop,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      createdAt: DateTime.now(),
      caption: 'แคปชัน',
      imageUrl: 'https://example.supabase.co/drops/iso-1.jpg',
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
      viewCount: 0,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeDropCard(
          item: item,
          onTap: () {},
          onToggleLike: () {},
          onToggleSave: () {},
          onOpenProfile: () {},
          onToggleRedrop: () {},
          onQuoteRedrop: () {},
          dropRepository: RecordingDropRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('แคปชัน'), findsOneWidget);
  });
}
