import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/chat/data/message_request.dart';
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

  MessageRequest request({
    String conversationId = 'c1',
    String? lastMessageText = 'สวัสดีครับ',
  }) =>
      MessageRequest.fromMap({
        'conversation_id': conversationId,
        'conversation_created_at': '2026-08-22T09:00:00Z',
        'other_user_id': 'other',
        'other_username': 'namfah',
        'other_display_name': 'น้ำฝน',
        'other_avatar_url': null,
        'last_message_text': lastMessageText,
        'last_message_image_url': null,
        'last_message_at': '2026-08-22T09:00:00Z',
      });

  Widget buildScreen() => MaterialApp(
        home: MessageRequestListScreen(chatRepository: chatRepo),
      );

  testWidgets('empty state shows the no-requests message, not a crash', (tester) async {
    chatRepo.messageRequestPages = const [[]];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีคำขอข้อความ'), findsOneWidget);
  });

  testWidgets('shows the sender and the latest message preview', (tester) async {
    chatRepo.messageRequestPages = [
      [request()],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('น้ำฝน'), findsOneWidget);
    expect(find.text('สวัสดีครับ'), findsOneWidget);
  });

  testWidgets('shows an image placeholder preview when the latest message is an image',
      (tester) async {
    chatRepo.messageRequestPages = [
      [
        MessageRequest.fromMap({
          'conversation_id': 'c1',
          'conversation_created_at': '2026-08-22T09:00:00Z',
          'other_user_id': 'other',
          'other_username': 'namfah',
          'other_display_name': 'น้ำฝน',
          'other_avatar_url': null,
          'last_message_text': null,
          'last_message_image_url': 'c1/photo.jpg',
          'last_message_at': '2026-08-22T09:00:00Z',
        }),
      ],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('📷 รูปภาพ'), findsOneWidget);
  });

  testWidgets('tapping a row opens ConversationScreen for that conversation', (tester) async {
    chatRepo.messageRequestPages = [
      [request()],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('น้ำฝน'));
    await tester.pumpAndSettle();

    final screen = tester.widget<ConversationScreen>(find.byType(ConversationScreen));
    expect(screen.conversationId, 'c1');
    expect(screen.otherUserId, 'other');
  });
}
