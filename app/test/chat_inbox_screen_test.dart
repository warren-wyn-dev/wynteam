import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/chat/data/chat_message.dart';
import 'package:wyn/features/chat/data/conversation.dart';
import 'package:wyn/features/chat/presentation/chat_inbox_screen.dart';
import 'package:wyn/features/chat/presentation/conversation_screen.dart';
import 'package:wyn/features/chat/presentation/message_request_list_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_chat_repository.dart';

void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  late RecordingChatRepository chatRepo;

  setUp(() {
    chatRepo = RecordingChatRepository();
  });

  Conversation conversation({
    String id = 'c1',
    String? lastMessageText = 'สวัสดี',
    String? lastMessageSenderId = 'other',
    String? lastMessageDeletedAt,
    DateTime? myLastReadAt,
  }) =>
      Conversation.fromMap({
        'conversation_id': id,
        'status': 'active',
        'conversation_created_at': '2026-08-01T00:00:00Z',
        'other_user_id': 'other',
        'other_username': 'namfah',
        'other_display_name': 'น้ำฝน',
        'other_avatar_url': null,
        'last_message_text': lastMessageText,
        'last_message_image_url': null,
        'last_message_deleted_at': lastMessageDeletedAt,
        'last_message_at': '2026-08-22T10:00:00Z',
        'last_message_sender_id': lastMessageSenderId,
        'my_last_read_at': myLastReadAt?.toIso8601String(),
      });

  Widget buildScreen() => MaterialApp(
        home: ChatInboxScreen(chatRepository: chatRepo),
      );

  testWidgets('empty state shows the no-conversations message, not a crash', (tester) async {
    chatRepo.inboxPages = const [[]];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีบทสนทนา'), findsOneWidget);
  });

  testWidgets('shows the other participant, preview text, and an unread indicator', (tester) async {
    chatRepo.inboxPages = [
      [conversation()],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('น้ำฝน'), findsOneWidget);
    expect(find.text('สวัสดี'), findsOneWidget);
  });

  testWidgets('shows "ข้อความถูกลบ" preview for a soft-deleted last message', (tester) async {
    chatRepo.inboxPages = [
      [conversation(lastMessageDeletedAt: '2026-08-22T10:00:30Z')],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ข้อความถูกลบ'), findsOneWidget);
  });

  testWidgets('tapping a row opens ConversationScreen for that conversation', (tester) async {
    chatRepo.inboxPages = [
      [conversation()],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('น้ำฝน'));
    await tester.pumpAndSettle();

    expect(find.byType(ConversationScreen), findsOneWidget);
  });

  testWidgets('long-press opens the mute/unmute sheet and toggling it calls the repository',
      (tester) async {
    chatRepo.inboxPages = [
      [conversation()],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('น้ำฝน'));
    await tester.pumpAndSettle();

    expect(find.text('ปิดแจ้งเตือนบทสนทนานี้'), findsOneWidget);
    await tester.tap(find.text('ปิดแจ้งเตือนบทสนทนานี้'));
    await tester.pumpAndSettle();

    expect(chatRepo.muteCalls, 1);
  });

  testWidgets('a realtime message arriving reloads the inbox', (tester) async {
    chatRepo.inboxPages = [
      const [],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีบทสนทนา'), findsOneWidget);

    chatRepo.inboxPages = [
      [conversation()],
    ];
    chatRepo.emitMyMessage(ChatMessage(
      id: 'm-realtime',
      conversationId: 'c1',
      senderId: 'other',
      createdAt: DateTime.now(),
      text: 'hi',
    ));
    await tester.pumpAndSettle();

    expect(find.text('น้ำฝน'), findsOneWidget);
  });

  group('"ทั้งหมด" / "ยังไม่อ่าน" tabs (12-chat.tsx)', () {
    testWidgets('defaults to "ทั้งหมด", showing both read and unread rows',
        (tester) async {
      chatRepo.inboxPages = [
        [
          conversation(id: 'c1'),
          conversation(
            id: 'c2',
            myLastReadAt: DateTime.parse('2026-08-22T11:00:00Z'),
          ),
        ],
      ];
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('น้ำฝน'), findsNWidgets(2));
    });

    testWidgets('switching to "ยังไม่อ่าน" filters out already-read rows',
        (tester) async {
      chatRepo.inboxPages = [
        [
          conversation(id: 'unread', lastMessageText: 'ยังไม่อ่านนะ'),
          conversation(
            id: 'read',
            lastMessageText: 'อ่านแล้ว',
            // Read after the last message arrived -- not unread.
            myLastReadAt: DateTime.parse('2026-08-22T11:00:00Z'),
          ),
        ],
      ];
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่อ่านนะ'), findsOneWidget);
      expect(find.text('อ่านแล้ว'), findsOneWidget);

      await tester.tap(find.text('ยังไม่อ่าน'));
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่อ่านนะ'), findsOneWidget);
      expect(find.text('อ่านแล้ว'), findsNothing);
    });

    testWidgets(
        '"ยังไม่อ่าน" with nothing unread shows its own empty message',
        (tester) async {
      chatRepo.inboxPages = [
        [
          conversation(myLastReadAt: DateTime.parse('2026-08-22T11:00:00Z')),
        ],
      ];
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('ยังไม่อ่าน'));
      await tester.pumpAndSettle();

      expect(find.text('ไม่มีบทสนทนาที่ยังไม่อ่าน'), findsOneWidget);
    });
  });

  group('Message Requests banner (WYN-032)', () {
    testWidgets('hidden when there are no pending requests', (tester) async {
      chatRepo.inboxPages = const [[]];
      chatRepo.pendingMessageRequestCount = 0;
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('คำขอข้อความ'), findsNothing);
    });

    testWidgets('shows the pending count and opens MessageRequestListScreen on tap',
        (tester) async {
      chatRepo.inboxPages = const [[]];
      chatRepo.pendingMessageRequestCount = 3;
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('คำขอข้อความ (3)'), findsOneWidget);

      await tester.tap(find.text('คำขอข้อความ (3)'));
      await tester.pumpAndSettle();

      expect(find.byType(MessageRequestListScreen), findsOneWidget);
    });
  });
}
