import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/presentation/widgets/suggested_follow_list.dart';
import 'package:wyn/features/home/presentation/widgets/verified_badge.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/recording_follow_repository.dart';
import 'support/recording_follow_request_repository.dart';

/// WYNOSHomeSpec.md 4.5.
void main() {
  late RecordingFollowRepository followRepository;
  late RecordingFollowRequestRepository followRequestRepository;

  setUp(() {
    followRepository = RecordingFollowRepository();
    followRequestRepository = RecordingFollowRequestRepository();
  });

  testWidgets('always shows the headline and subtext', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SuggestedFollowList(
          fetchSuggestedUsers: () async => const [],
          followRepository: followRepository,
          followRequestRepository: followRequestRepository,
          onOpenProfile: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีอะไรให้ดูตรงนี้'), findsOneWidget);
    expect(
      find.text('ลองติดตามคนที่คุณสนใจ เพื่อเริ่มเห็นโพสต์ในหน้านี้'),
      findsOneWidget,
    );
  });

  testWidgets('renders each suggested account with name/handle/Follow button',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SuggestedFollowList(
          fetchSuggestedUsers: () async => const [
            Profile(id: 'u1', username: 'warren', displayName: 'Warren'),
            Profile(id: 'u2', username: 'zen', displayName: 'Zen'),
          ],
          followRepository: followRepository,
          followRequestRepository: followRequestRepository,
          onOpenProfile: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Warren'), findsOneWidget);
    expect(find.text('@warren'), findsOneWidget);
    expect(find.text('Zen'), findsOneWidget);
    expect(find.text('@zen'), findsOneWidget);
    expect(find.text('ติดตาม'), findsNWidgets(2));
  });

  testWidgets('shows the verified badge only for a verified account',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SuggestedFollowList(
          fetchSuggestedUsers: () async => const [
            Profile(
              id: 'u1',
              username: 'wynos',
              displayName: 'WYNOS',
              isVerified: true,
            ),
            Profile(id: 'u2', username: 'zen', displayName: 'Zen'),
          ],
          followRepository: followRepository,
          followRequestRepository: followRequestRepository,
          onOpenProfile: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(VerifiedBadge), findsOneWidget);
  });

  testWidgets('does not render the list section when the fetch fails',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SuggestedFollowList(
          fetchSuggestedUsers: () async => throw Exception('network error'),
          followRepository: followRepository,
          followRequestRepository: followRequestRepository,
          onOpenProfile: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Headline/subtext still show -- only the network-dependent list
    // silently doesn't.
    expect(find.text('ยังไม่มีอะไรให้ดูตรงนี้'), findsOneWidget);
    expect(find.text('ติดตาม'), findsNothing);
  });

  testWidgets('tapping a suggested account calls onOpenProfile', (tester) async {
    String? openedId;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SuggestedFollowList(
          fetchSuggestedUsers: () async => const [
            Profile(id: 'u1', username: 'warren', displayName: 'Warren'),
          ],
          followRepository: followRepository,
          followRequestRepository: followRequestRepository,
          onOpenProfile: (id) => openedId = id,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Warren'));
    expect(openedId, 'u1');
  });
}
