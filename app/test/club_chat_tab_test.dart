import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_channel.dart';
import 'package:wyn/features/club/data/club_channel_message.dart';
import 'package:wyn/features/club/data/club_member.dart';
import 'package:wyn/features/club/presentation/widgets/club_chat_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_channel_chat_repository.dart';
import 'support/recording_club_repository.dart';

/// Regression tests for the "แชท" top-level Club tab -- now a **channel
/// list** (WYN-133): tapping a row navigates to a full-screen room
/// instead of swapping content inline under a chip bar (see
/// .wyn/docs/design/wyn-133-club-chat-channel-navigation.md). Extends the
/// original WYN-127/128 coverage (extracted from club_posts_tab_test.dart
/// when Chat became its own top-level tab, see that file's history) with
/// WYN-133's own requirement 7 (channel categories). Only ever reached
/// for a developer account -- ClubPage's own `showChat` gate -- so this
/// widget itself doesn't re-check that; `club_page_test.dart` covers the
/// gate.
void main() {
  final club = Club(
    id: 'club-1',
    name: 'Test Club',
    privacy: ClubPrivacy.public,
    ownerId: 'owner-1',
    createdAt: DateTime.now(),
    memberCount: 4,
  );

  ClubChannel channel({required String id, required String name, String? categoryId}) =>
      ClubChannel(
        id: id,
        clubId: club.id,
        name: name,
        createdBy: 'owner-1',
        createdAt: DateTime.now(),
        categoryId: categoryId,
      );

  ClubChannelCategory category({required String id, required String name}) => ClubChannelCategory(
        id: id,
        clubId: club.id,
        name: name,
        createdBy: 'owner-1',
        createdAt: DateTime.now(),
      );

  late RecordingClubRepository singleGeneralChannelRepo;
  late RecordingClubRepository twoChannelsRepo;
  late RecordingClubRepository ownerSingleChannelRepo;
  late RecordingClubRepository groupedChannelsRepo;
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
    groupedChannelsRepo = RecordingClubRepository(
      club: club,
      categories: [category(id: 'cat-feedback', name: 'ฟีดแบ็กแอป')],
      channels: [
        channel(id: 'c-general', name: 'ทั่วไป'),
        channel(id: 'c-bugs', name: 'บั๊กรีพอร์ต', categoryId: 'cat-feedback'),
      ],
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

  testWidgets('shows the channel list -- no room open, every channel is a row',
      (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.member, clubRepository: twoChannelsRepo);

    expect(find.text('#ทั่วไป'), findsOneWidget);
    expect(find.text('#ประกาศ'), findsOneWidget);
    expect(find.text('ยังไม่มีใครพิมพ์เลย'), findsNothing);
  });

  testWidgets('tapping a channel row navigates to its own full-screen room with an AppBar',
      (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.member, clubRepository: singleGeneralChannelRepo);

    await tester.tap(find.text('#ทั่วไป'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '#ทั่วไป'), findsOneWidget);
    expect(find.text('ยังไม่มีใครพิมพ์เลย'), findsOneWidget);
  });

  testWidgets('the back button on the room returns to the channel list', (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.member, clubRepository: twoChannelsRepo);

    await tester.tap(find.text('#ประกาศ'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '#ประกาศ'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('#ทั่วไป'), findsOneWidget);
    expect(find.text('#ประกาศ'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('a plain Member never sees the "+" add button', (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.member, clubRepository: singleGeneralChannelRepo);

    expect(find.byKey(const Key('club_chat_add_button')), findsNothing);
  });

  testWidgets('an Owner creates a new channel via the "+" menu', (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.owner, clubRepository: ownerSingleChannelRepo);

    expect(find.byKey(const Key('club_chat_add_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('club_chat_add_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ห้องใหม่'));
    await tester.pumpAndSettle();

    // Scoped to the dialog -- more than one TextField could exist once a
    // room is open elsewhere in the tree.
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

  testWidgets('an Owner creates a new category via the "+" menu', (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.owner, clubRepository: ownerSingleChannelRepo);

    await tester.tap(find.byKey(const Key('club_chat_add_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('กลุ่มใหม่'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ทั่วไป');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'บันทึก'));
    await tester.pumpAndSettle();

    expect(ownerSingleChannelRepo.createChannelCategoryCalls, 1);
    expect(find.text('ทั่วไป'), findsWidgets);
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

  testWidgets('an Owner deletes a category and its channel survives, uncategorized',
      (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.owner, clubRepository: groupedChannelsRepo);

    expect(find.text('ฟีดแบ็กแอป'), findsOneWidget);
    expect(find.text('#บั๊กรีพอร์ต'), findsOneWidget);

    await tester.longPress(find.text('ฟีดแบ็กแอป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบกลุ่ม'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ลบกลุ่ม'));
    await tester.pumpAndSettle();

    expect(groupedChannelsRepo.deleteChannelCategoryCalls, 1);
    expect(find.text('ฟีดแบ็กแอป'), findsNothing);
    // The channel that was in the deleted category is still there.
    expect(find.text('#บั๊กรีพอร์ต'), findsOneWidget);
  });

  testWidgets('a Club with no categories renders a flat list -- no category headers at all',
      (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.member, clubRepository: twoChannelsRepo);

    expect(find.text('ไม่มีกลุ่ม'), findsNothing);
  });

  testWidgets('an Owner moves a channel into a category via the manage sheet', (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.owner, clubRepository: groupedChannelsRepo);

    await tester.longPress(find.text('#ทั่วไป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ย้ายไปกลุ่มอื่น'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ฟีดแบ็กแอป').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'บันทึก'));
    await tester.pumpAndSettle();

    expect(groupedChannelsRepo.renameChannelCalls, 1);
    expect(groupedChannelsRepo.renameChannelCategoryIdArgs, ['cat-feedback']);
  });

  testWidgets('a live message on a channel that is NOT open bumps its unread dot',
      (tester) async {
    final chatRepo = RecordingClubChannelChatRepository();
    await pumpTab(
      tester,
      myRole: ClubMemberRole.member,
      clubRepository: twoChannelsRepo,
      clubChannelChatRepository: chatRepo,
    );

    expect(find.bySemanticsLabel('#ทั่วไป มีข้อความใหม่'), findsNothing);

    // Every channel gets its own live subscription while the Channel
    // List is on screen (a Postgres realtime filter can only match one
    // column, so `ClubChatTab` subscribes once per channel rather than
    // once for the whole Club) -- a message on c-general must bump its
    // dot even though no room is open at all.
    chatRepo.emitUnreadMessage(ClubChannelMessage(
      id: 'm1',
      channelId: 'c-general',
      authorId: 'someone-else',
      authorUsername: 'someone',
      createdAt: DateTime.now(),
      content: 'hi',
    ));
    await tester.pump();

    expect(find.bySemanticsLabel('#ทั่วไป มีข้อความใหม่'), findsOneWidget);
  });

  testWidgets('returning from a room re-syncs unread counts, clearing the visited channel\'s dot',
      (tester) async {
    final chatRepo = RecordingClubChannelChatRepository()..unreadCounts = {'c-announce': 2};
    await pumpTab(
      tester,
      myRole: ClubMemberRole.member,
      clubRepository: twoChannelsRepo,
      clubChannelChatRepository: chatRepo,
    );

    // The dot itself has no text to assert on directly -- assert via the
    // row's semantics label, which includes "มีข้อความใหม่" only when
    // hasUnread is true.
    expect(find.bySemanticsLabel('#ประกาศ มีข้อความใหม่'), findsOneWidget);

    await tester.tap(find.text('#ประกาศ'));
    await tester.pumpAndSettle();
    expect(chatRepo.lastMarkChannelReadChannelId, 'c-announce');

    // Simulates the server-side effect of that markChannelRead call --
    // this fake doesn't wire fetchUnreadCounts to markChannelRead
    // automatically, so this stands in for "the server now agrees it's
    // read" ahead of ClubChatTab re-fetching on pop.
    chatRepo.unreadCounts = {};

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('#ประกาศ มีข้อความใหม่'), findsNothing);
  });
}
