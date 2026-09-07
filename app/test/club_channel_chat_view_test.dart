import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club_channel_message.dart';
import 'package:wyn/features/club/data/club_member.dart';
import 'package:wyn/features/club/presentation/widgets/club_channel_chat_view.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_channel_chat_repository.dart';
import 'support/recording_club_repository.dart';

/// Regression tests for WYN-128's Club Group Chat view. Mirrors
/// ConversationScreen's own test posture wherever the shape matches --
/// see .wyn/tasks/backlog/WYN-128-club-group-chat.md.
void main() {
  ClubChannelMessage message({
    required String id,
    required String authorId,
    String authorUsername = 'namfah',
    String content = 'สวัสดี',
    String? replyToMessageId,
  }) =>
      ClubChannelMessage(
        id: id,
        channelId: 'channel-1',
        authorId: authorId,
        authorUsername: authorUsername,
        createdAt: DateTime.now(),
        content: content,
        replyToMessageId: replyToMessageId,
      );

  late RecordingClubChannelChatRepository repo;
  late RecordingClubRepository clubRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'viewer');
  });

  setUp(() {
    repo = RecordingClubChannelChatRepository();
    clubRepo = RecordingClubRepository();
  });

  Future<void> pumpView(
    WidgetTester tester, {
    ClubMemberRole? myRole = ClubMemberRole.member,
    VoidCallback? onBanned,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClubChannelChatView(
            repository: repo,
            clubRepository: clubRepo,
            clubId: 'club-1',
            channelId: 'channel-1',
            channelName: 'ทั่วไป',
            myRole: myRole,
            onBanned: onBanned,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an empty-state invitation when the room has no messages yet',
      (tester) async {
    await pumpView(tester);

    expect(find.text('ยังไม่มีใครพิมพ์เลย'), findsOneWidget);
  });

  testWidgets('shows every message, with a sender-name label only on incoming ones',
      (tester) async {
    repo.messagesByChannel = {
      'channel-1': [
        message(id: 'm2', authorId: 'namfah-id', content: 'ทักทาย'),
        message(id: 'm1', authorId: 'viewer', authorUsername: 'viewer', content: 'สวัสดีครับ'),
      ],
    };
    await pumpView(tester);

    expect(find.text('ทักทาย'), findsOneWidget);
    expect(find.text('สวัสดีครับ'), findsOneWidget);
    // WYN-128's own addition vs. 1:1 chat -- incoming bubbles carry the
    // sender's name; the viewer's own never do.
    expect(find.text('@namfah'), findsOneWidget);
    expect(find.text('@viewer'), findsNothing);
  });

  testWidgets('marks the channel read and subscribes to realtime updates on open',
      (tester) async {
    await pumpView(tester);

    expect(repo.markChannelReadCalls, 1);
    expect(repo.lastMarkChannelReadChannelId, 'channel-1');
  });

  testWidgets('sending a message calls sendMessage and shows the bubble immediately',
      (tester) async {
    await pumpView(tester);

    await tester.enterText(find.byType(TextField), 'ทดสอบข้อความ');
    await tester.pump();
    await tester.tap(find.byTooltip('ส่งข้อความ'));
    await tester.pumpAndSettle();

    expect(repo.sendMessageCalls, 1);
    expect(repo.lastSendMessageContent, 'ทดสอบข้อความ');
    expect(repo.lastSendMessageChannelId, 'channel-1');
    expect(find.text('ทดสอบข้อความ'), findsOneWidget);
  });

  testWidgets('replying to a message shows the reply preview bar and sends '
      'with replyToMessageId', (tester) async {
    repo.messagesByChannel = {
      'channel-1': [message(id: 'm1', authorId: 'namfah-id', content: 'ข้อความต้นทาง')],
    };
    await pumpView(tester);

    await tester.longPress(find.text('ข้อความต้นทาง'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตอบกลับ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ตอบกลับ namfah'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ตอบนะ');
    await tester.pump();
    await tester.tap(find.byTooltip('ส่งข้อความ'));
    await tester.pumpAndSettle();

    expect(repo.lastSendMessageReplyToId, 'm1');
  });

  testWidgets('a realtime message from someone else appears without a reload',
      (tester) async {
    await pumpView(tester);
    expect(find.text('ข้อความใหม่'), findsNothing);

    repo.emitMessage(message(id: 'm-live', authorId: 'namfah-id', content: 'ข้อความใหม่'));
    await tester.pump();

    expect(find.text('ข้อความใหม่'), findsOneWidget);
  });

  testWidgets('shows the live online-member count from presence sync', (tester) async {
    await pumpView(tester);
    expect(find.text('0 คนออนไลน์ในห้องนี้'), findsOneWidget);

    repo.emitPresenceCount(3);
    await tester.pump();

    expect(find.text('3 คนออนไลน์ในห้องนี้'), findsOneWidget);
  });

  group('Deleting messages', () {
    testWidgets('the author can delete their own message', (tester) async {
      repo.messagesByChannel = {
        'channel-1': [message(id: 'm1', authorId: 'viewer', authorUsername: 'viewer')],
      };
      await pumpView(tester);

      await tester.longPress(find.text('สวัสดี'));
      await tester.pumpAndSettle();
      expect(find.text('ลบข้อความ'), findsOneWidget);

      await tester.tap(find.text('ลบข้อความ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();

      expect(repo.deleteMessageCalls, 1);
      expect(repo.lastDeleteMessageId, 'm1');
      expect(find.text('สวัสดี'), findsNothing);
    });

    testWidgets('a plain Member never sees "ลบข้อความ" on someone else\'s message',
        (tester) async {
      repo.messagesByChannel = {
        'channel-1': [message(id: 'm1', authorId: 'namfah-id')],
      };
      await pumpView(tester, myRole: ClubMemberRole.member);

      await tester.longPress(find.text('สวัสดี'));
      await tester.pumpAndSettle();

      expect(find.text('ตอบกลับ'), findsOneWidget);
      expect(find.text('ลบข้อความ'), findsNothing);
    });

    testWidgets('a Moderator can delete someone else\'s message (moderation)',
        (tester) async {
      repo.messagesByChannel = {
        'channel-1': [message(id: 'm1', authorId: 'namfah-id')],
      };
      await pumpView(tester, myRole: ClubMemberRole.moderator);

      await tester.longPress(find.text('สวัสดี'));
      await tester.pumpAndSettle();

      expect(find.text('ลบข้อความ'), findsOneWidget);
    });
  });

  group('Reporting messages (WYN-128 fast-follow -- '
      '.wyn/tasks/bugs/WYN-128-group-chat-missing-report-action.md)', () {
    testWidgets('shows "รายงานข้อความ" on someone else\'s message', (tester) async {
      repo.messagesByChannel = {
        'channel-1': [message(id: 'm1', authorId: 'namfah-id')],
      };
      await pumpView(tester);

      await tester.longPress(find.text('สวัสดี'));
      await tester.pumpAndSettle();

      expect(find.text('รายงานข้อความ'), findsOneWidget);
    });

    testWidgets('never shows "รายงานข้อความ" on your own message', (tester) async {
      repo.messagesByChannel = {
        'channel-1': [message(id: 'm1', authorId: 'viewer', authorUsername: 'viewer')],
      };
      await pumpView(tester);

      await tester.longPress(find.text('สวัสดี'));
      await tester.pumpAndSettle();

      expect(find.text('รายงานข้อความ'), findsNothing);
    });
  });

  group('Ban/removal while viewing (Design States)', () {
    testWidgets('calls onBanned when this user\'s own membership is removed/banned',
        (tester) async {
      var banned = false;
      await pumpView(tester, onBanned: () => banned = true);

      clubRepo.emitBannedOrRemoved();
      await tester.pump();

      expect(banned, isTrue);
    });
  });
}
