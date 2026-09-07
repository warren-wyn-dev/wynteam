import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_channel.dart';
import 'package:wyn/features/club/data/club_member.dart';
import 'package:wyn/features/club/presentation/widgets/club_chat_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_channel_chat_repository.dart';
import 'support/recording_club_repository.dart';

/// Regression tests for the "แชท" top-level Club tab -- extracted from
/// club_posts_tab_test.dart's old "Channels (WYN-127)"/"Group Chat toggle
/// (WYN-128)" groups once the Founder's tab-restructuring decision
/// (2026-09-07) split Chat out of the Posts tab into its own top-level
/// tab (see .wyn/tasks/backlog/WYN-127-club-channels.md,
/// WYN-128-club-group-chat.md). Only ever reached for a developer
/// account -- ClubPage's own `showChat` gate -- so this widget itself
/// doesn't re-check that; `club_page_test.dart` covers the gate.
void main() {
  final club = Club(
    id: 'club-1',
    name: 'Test Club',
    privacy: ClubPrivacy.public,
    ownerId: 'owner-1',
    createdAt: DateTime.now(),
    memberCount: 4,
  );

  ClubChannel channel({required String id, required String name}) => ClubChannel(
        id: id,
        clubId: club.id,
        name: name,
        createdBy: 'owner-1',
        createdAt: DateTime.now(),
      );

  late RecordingClubRepository singleGeneralChannelRepo;
  late RecordingClubRepository twoChannelsRepo;
  late RecordingClubRepository ownerSingleChannelRepo;
  late RecordingClubChannelChatRepository defaultChatRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'viewer');
  });

  setUp(() {
    singleGeneralChannelRepo = RecordingClubRepository(
      club: club,
      channels: [channel(id: 'c-general', name: 'ทั่วไป')],
    );
    twoChannelsRepo = RecordingClubRepository(
      club: club,
      channels: [
        channel(id: 'c-general', name: 'ทั่วไป'),
        channel(id: 'c-announce', name: 'ประกาศ'),
      ],
    );
    ownerSingleChannelRepo = RecordingClubRepository(
      club: club,
      channels: [channel(id: 'c-general', name: 'ทั่วไป')],
    );
    // Never let ClubChatTab fall back to a real ClubChannelChatRepository
    // in a test -- its unread-badge subscription would call the real
    // Supabase Realtime client's `.subscribe()`, which leaves a pending
    // Timer flutter_test fails the test over (see
    // RecordingClubChannelChatRepository's own doc comment).
    defaultChatRepo = RecordingClubChannelChatRepository();
  });

  Future<void> pumpTab(
    WidgetTester tester, {
    required ClubMemberRole? myRole,
    RecordingClubRepository? clubRepository,
    RecordingClubChannelChatRepository? clubChannelChatRepository,
    VoidCallback? onBanned,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClubChatTab(
            clubRepository: clubRepository ?? singleGeneralChannelRepo,
            clubChannelChatRepository: clubChannelChatRepository ?? defaultChatRepo,
            club: club,
            myRole: myRole,
            onBanned: onBanned,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the "ทั่วไป" (oldest) channel and shows its chat room',
      (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.member, clubRepository: singleGeneralChannelRepo);

    expect(find.text('#ทั่วไป'), findsOneWidget);
    expect(find.text('ยังไม่มีใครพิมพ์เลย'), findsOneWidget);
  });

  testWidgets('tapping another channel chip switches to its chat room', (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.member, clubRepository: twoChannelsRepo);

    await tester.tap(find.text('#ประกาศ'));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีใครพิมพ์เลย'), findsOneWidget);
  });

  testWidgets('a plain Member never sees the "+ ห้องใหม่" chip', (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.member, clubRepository: singleGeneralChannelRepo);

    expect(find.byKey(const Key('club_channel_new_chip')), findsNothing);
  });

  testWidgets('an Owner sees the "+ ห้องใหม่" chip and creating a channel selects it',
      (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.owner, clubRepository: ownerSingleChannelRepo);

    expect(find.byKey(const Key('club_channel_new_chip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('club_channel_new_chip')));
    await tester.pumpAndSettle();
    // Scoped to the dialog -- the chat room behind it has its own
    // message-compose TextField, so a bare find.byType(TextField) would
    // match 2 widgets.
    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'ถามตอบ',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'บันทึก'));
    await tester.pumpAndSettle();

    expect(ownerSingleChannelRepo.createChannelCalls, 1);
    expect(find.text('#ถามตอบ'), findsOneWidget);
  });

  testWidgets('an Owner cannot delete the last remaining channel', (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.owner, clubRepository: ownerSingleChannelRepo);

    await tester.longPress(find.text('#ทั่วไป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบห้อง'));
    await tester.pumpAndSettle();

    // No confirmation dialog even opened -- refused outright client-side.
    expect(find.text('ลบห้อง #ทั่วไป?'), findsNothing);
    expect(find.text('ต้องมีอย่างน้อย 1 ห้องเสมอ ลบห้องสุดท้ายไม่ได้'), findsOneWidget);
    expect(ownerSingleChannelRepo.deleteChannelCalls, 0);
  });

  testWidgets('shows an unread dot on a channel chip with unread messages, and '
      'switching to it marks the channel read, clearing the dot', (tester) async {
    final chatRepo = RecordingClubChannelChatRepository()
      ..unreadCounts = {'c-announce': 2};
    await pumpTab(
      tester,
      myRole: ClubMemberRole.member,
      clubRepository: twoChannelsRepo,
      clubChannelChatRepository: chatRepo,
    );

    // The dot itself has no text to assert on directly -- assert via the
    // chip's semantics label, which includes "มีข้อความใหม่" only when
    // hasUnread is true (see ClubChannelSwitcher's _ChannelChip).
    expect(find.bySemanticsLabel('#ประกาศ มีข้อความใหม่'), findsOneWidget);

    await tester.tap(find.text('#ประกาศ'));
    await tester.pumpAndSettle();

    // ClubChannelChatView.markChannelRead's own call fires on mount for
    // whichever channel is showing (including the first, "c-general", at
    // initial pump) -- assert the *latest* call targeted the
    // just-switched-to channel, not an exact cumulative count.
    expect(chatRepo.lastMarkChannelReadChannelId, 'c-announce');
    expect(find.bySemanticsLabel('#ประกาศ มีข้อความใหม่'), findsNothing);
  });
}
