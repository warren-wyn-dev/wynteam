import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/chat/data/conversation.dart';
import 'package:wyn/features/chat/data/shared_content_type.dart';
import 'package:wyn/features/chat/presentation/share_to_chat_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_chat_repository.dart';
import 'support/recording_profile_repository.dart';

void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  late RecordingChatRepository chatRepo;
  late RecordingProfileRepository profileRepo;

  setUp(() {
    chatRepo = RecordingChatRepository();
    profileRepo = RecordingProfileRepository(searchResults: const [
      Profile(id: 'stranger', username: 'stranger', displayName: 'คนแปลกหน้า'),
    ]);
  });

  Conversation conversation({String id = 'c1'}) => Conversation.fromMap({
        'conversation_id': id,
        'status': 'active',
        'conversation_created_at': '2026-08-01T00:00:00Z',
        'other_user_id': 'other',
        'other_username': 'namfah',
        'other_display_name': 'น้ำฝน',
        'other_avatar_url': null,
        'last_message_text': null,
        'last_message_image_url': null,
        'last_message_deleted_at': null,
        'last_message_at': null,
        'last_message_sender_id': null,
        'my_last_read_at': null,
      });

  // ShareToChatScreen calls Navigator.pop() on a successful send, so it
  // needs a real route beneath it (MaterialApp(home: ...) alone gives it
  // none, which either no-ops the pop or disrupts the follow-up
  // ScaffoldMessenger call) -- same fix as
  // conversation_screen_test.dart's Delete-request test: push it from a
  // placeholder screen instead of rendering it directly as `home`.
  Widget buildScreen() => MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ShareToChatScreen(
                      chatRepository: chatRepo,
                      profileRepository: profileRepo,
                      sharedContentType: SharedContentType.drop,
                      sharedContentId: 'drop-1',
                      previewLabel: 'แชร์ Drop',
                    ),
                  ),
                ),
                child: const Text('เปิด'),
              ),
            ),
          ),
        ),
      );

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the preview label at the top', (tester) async {
    chatRepo.inboxPages = const [[]];
    await openScreen(tester);

    expect(find.text('แชร์ Drop'), findsOneWidget);
  });

  testWidgets('empty state prompts to search when there are no conversations',
      (tester) async {
    chatRepo.inboxPages = const [[]];
    await openScreen(tester);

    expect(find.textContaining('ยังไม่มีบทสนทนา'), findsOneWidget);
  });

  testWidgets('shows existing conversations by default', (tester) async {
    chatRepo.inboxPages = [
      [conversation()],
    ];
    await openScreen(tester);

    expect(find.text('น้ำฝน'), findsOneWidget);
  });

  testWidgets('tapping an existing conversation sends immediately and pops with a '
      'confirmation snackbar', (tester) async {
    chatRepo.inboxPages = [
      [conversation()],
    ];
    await openScreen(tester);

    await tester.tap(find.text('น้ำฝน'));
    await tester.pumpAndSettle();

    expect(chatRepo.sendMessageCalls, 1);
    expect(chatRepo.lastSendMessageSharedContentType, SharedContentType.drop);
    expect(chatRepo.lastSendMessageSharedContentId, 'drop-1');
    expect(find.byType(ShareToChatScreen), findsNothing);
    expect(find.text('แชร์แล้ว'), findsOneWidget);
  });

  testWidgets('typing a search query shows search results instead of conversations',
      (tester) async {
    chatRepo.inboxPages = [
      [conversation()],
    ];
    await openScreen(tester);

    await tester.enterText(find.byType(TextField), 'stranger');
    await tester.pumpAndSettle();

    expect(find.text('คนแปลกหน้า'), findsOneWidget);
    expect(find.text('น้ำฝน'), findsNothing);
  });

  testWidgets('tapping a search result starts a conversation then sends',
      (tester) async {
    chatRepo.inboxPages = const [[]];
    chatRepo.getOrCreateConversationResult = 'new-conversation';
    await openScreen(tester);

    await tester.enterText(find.byType(TextField), 'stranger');
    await tester.pumpAndSettle();
    await tester.tap(find.text('คนแปลกหน้า'));
    await tester.pumpAndSettle();

    expect(chatRepo.sendMessageCalls, 1);
    expect(chatRepo.lastSendMessageSharedContentType, SharedContentType.drop);
    expect(find.byType(ShareToChatScreen), findsNothing);
    expect(find.text('แชร์แล้ว'), findsOneWidget);
  });

  testWidgets('a send failure shows an error snackbar and stays on screen',
      (tester) async {
    chatRepo.inboxPages = [
      [conversation()],
    ];
    chatRepo.sendMessageError = Exception('boom');
    await openScreen(tester);

    await tester.tap(find.text('น้ำฝน'));
    await tester.pumpAndSettle();

    expect(find.byType(ShareToChatScreen), findsOneWidget);
    expect(find.text('แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
  });
}
