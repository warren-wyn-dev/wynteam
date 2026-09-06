import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/presentation/invite_to_club_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_chat_repository.dart';
import 'support/recording_follow_repository.dart';

/// WYN-115: `InviteToClubScreen` lets a club member invite people from
/// their own Followers *and* Following, merged and de-duplicated
/// (Founder decision, 2026-09-06 -- see
/// .wyn/tasks/active/WYN-115-invite-followers-to-club.md), sending each
/// invite through the existing WYN-033 share-to-chat mechanism.
void main() {
  late RecordingFollowRepository followRepository;
  late RecordingChatRepository chatRepository;

  Profile profile(String id, {String? displayName}) => Profile(
        id: id,
        username: id,
        displayName: displayName,
      );

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    followRepository = RecordingFollowRepository();
    chatRepository = RecordingChatRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InviteToClubScreen(
          followRepository: followRepository,
          chatRepository: chatRepository,
          clubId: 'club-1',
          clubName: 'ชมรมถ่ายภาพเชียงใหม่',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the club name in the preview line', (tester) async {
    followRepository.followers.add(profile('a', displayName: 'Ann'));
    await pumpScreen(tester);

    expect(find.textContaining('ชมรมถ่ายภาพเชียงใหม่'), findsOneWidget);
  });

  testWidgets('merges Followers and Following, de-duplicating anyone in both',
      (tester) async {
    followRepository.followers
      ..add(profile('a', displayName: 'Ann'))
      ..add(profile('shared', displayName: 'Both'));
    followRepository.following
      ..add(profile('b', displayName: 'Bee'))
      ..add(profile('shared', displayName: 'Both'));

    await pumpScreen(tester);

    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Bee'), findsOneWidget);
    expect(find.text('Both'), findsOneWidget);
    // 3 unique rows, not 4 -- "shared" from both lists collapses to one.
    expect(find.textContaining('@'), findsNWidgets(3));
  });

  testWidgets('empty state points at the other share options instead of a dead end',
      (tester) async {
    await pumpScreen(tester);

    expect(
      find.text('คุณยังไม่มีผู้ติดตามให้เชิญตอนนี้ — ลองแชร์ลิงก์ผ่านช่องทางอื่นดูก่อนได้'),
      findsOneWidget,
    );
  });

  testWidgets('search filters the already-loaded list client-side',
      (tester) async {
    followRepository.followers
      ..add(profile('ann', displayName: 'Ann'))
      ..add(profile('bee', displayName: 'Bee'));

    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'ann');
    await tester.pumpAndSettle();

    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Bee'), findsNothing);
  });

  testWidgets(
      'tapping เชิญ goes idle -> sending -> เชิญแล้ว, and stays on screen',
      (tester) async {
    followRepository.followers.add(profile('a', displayName: 'Ann'));
    chatRepository.sendMessageGate = Completer<void>();
    await pumpScreen(tester);

    expect(find.text('เชิญ'), findsOneWidget);

    await tester.tap(find.text('เชิญ'));
    await tester.pump();

    // Sending: button becomes a spinner, no "เชิญ"/"เชิญแล้ว" label showing.
    expect(find.text('เชิญ'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    chatRepository.sendMessageGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('เชิญแล้ว'), findsOneWidget);
    expect(chatRepository.getOrCreateConversationCalls, ['a']);
    expect(chatRepository.sendMessageCalls, 1);
    expect(chatRepository.lastSendMessageSharedContentType?.name, 'club');
    expect(chatRepository.lastSendMessageSharedContentId, 'club-1');
    // The screen itself never pops -- inviting more than one person in
    // one visit is the whole point (unlike ShareToChatScreen, which
    // pops back after a single send).
    expect(find.byType(InviteToClubScreen), findsOneWidget);
  });

  testWidgets('a failed invite reverts to เชิญ and shows an error SnackBar',
      (tester) async {
    followRepository.followers.add(profile('a', displayName: 'Ann'));
    chatRepository.getOrCreateConversationError = Exception('network');
    await pumpScreen(tester);

    await tester.tap(find.text('เชิญ'));
    await tester.pumpAndSettle();

    expect(find.text('เชิญ'), findsOneWidget);
    expect(find.text('เชิญไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
  });
}
