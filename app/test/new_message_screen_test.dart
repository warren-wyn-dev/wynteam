import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/chat/presentation/conversation_screen.dart';
import 'package:wyn/features/chat/presentation/new_message_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_chat_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_profile_repository.dart';

/// 17-new-message.tsx -- a person picker reached from Chat Inbox's pencil
/// icon. Default list is "ติดตามอยู่" (following); the search box is
/// wired to real search (ProfileRepository.searchProfiles), not just a
/// filter over the following list -- see the screen's own doc comment.
void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  late RecordingChatRepository chatRepo;
  late RecordingFollowRepository followRepo;
  late RecordingProfileRepository profileRepo;

  setUp(() {
    chatRepo = RecordingChatRepository();
    followRepo = RecordingFollowRepository(
      // Not `const` -- these lists are mutated in place by individual
      // tests below (a const list literal would be unmodifiable).
      following: [
        const Profile(id: 'u1', username: 'namfah', displayName: 'น้ำฝน'),
      ],
    );
    profileRepo = RecordingProfileRepository();
  });

  Widget buildScreen() => MaterialApp(
        home: NewMessageScreen(
          chatRepository: chatRepo,
          profileRepository: profileRepo,
          followRepository: followRepo,
        ),
      );

  testWidgets('defaults to showing the "ติดตามอยู่" (following) list',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ติดตามอยู่'), findsOneWidget);
    expect(find.text('น้ำฝน'), findsOneWidget);
    expect(find.text('@namfah'), findsOneWidget);
  });

  testWidgets('shows an empty message when following no one', (tester) async {
    // Mutate the already-constructed repository's list in place --
    // never re-construct a RecordingXRepository inside a testWidgets
    // body (its SupabaseClient's GoTrue auto-refresh Timer would leak
    // into this test's FakeAsync zone). See PATTERNS.md.
    followRepo.following.clear();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(
      find.text('คุณยังไม่ได้ติดตามใครเลย ลองค้นหาคนที่อยากคุยด้วยดูสิ'),
      findsOneWidget,
    );
  });

  testWidgets(
      'typing 2+ characters searches all users via ProfileRepository, not '
      'just people already followed', (tester) async {
    profileRepo.searchResults.add(
      const Profile(id: 'u2', username: 'ploy', displayName: 'พลอย'),
    );
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pl');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(profileRepo.searchProfilesQueryArgs, ['pl']);
    expect(find.text('พลอย'), findsOneWidget);
    // Following list content ("น้ำฝน") no longer shown while searching.
    expect(find.text('น้ำฝน'), findsNothing);
  });

  testWidgets(
      'search results never include the current user themselves',
      (tester) async {
    profileRepo.searchResults.addAll(const [
      Profile(id: 'me', username: 'myself'),
      Profile(id: 'u2', username: 'ploy'),
    ]);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pl');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('@myself'), findsNothing);
    expect(find.text('@ploy'), findsOneWidget);
  });

  testWidgets(
      'tapping a person calls getOrCreateConversation and opens '
      'ConversationScreen', (tester) async {
    chatRepo.getOrCreateConversationResult = 'c-new';
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('น้ำฝน'));
    await tester.pumpAndSettle();

    expect(chatRepo.getOrCreateConversationCalls, ['u1']);
    expect(find.byType(ConversationScreen), findsOneWidget);
    expect(find.byType(NewMessageScreen), findsNothing);
  });

  testWidgets('a failed getOrCreateConversation shows an error and stays',
      (tester) async {
    chatRepo.getOrCreateConversationError = Exception('network error');
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('น้ำฝน'));
    await tester.pumpAndSettle();

    expect(find.text('เริ่มบทสนทนาไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.byType(NewMessageScreen), findsOneWidget);
  });
}
