import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/core/design/wyn_colors.dart';
import 'package:wyn/features/block/data/block_relationship.dart';
import 'package:wyn/features/chat/data/chat_message.dart';
import 'package:wyn/features/chat/presentation/conversation_screen.dart';
import 'package:wyn/features/moderation/data/moderation_status.dart';
import 'package:wyn/features/profile/presentation/widgets/avatar_circle.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_block_repository.dart';
import 'support/recording_chat_repository.dart';
import 'support/recording_moderation_repository.dart';

void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  late RecordingChatRepository chatRepo;
  late RecordingBlockRepository blockRepo;
  late RecordingModerationRepository moderationRepo;

  setUp(() {
    chatRepo = RecordingChatRepository();
    blockRepo = RecordingBlockRepository();
    moderationRepo = RecordingModerationRepository();
  });

  ChatMessage message({
    String id = 'm1',
    String senderId = 'other',
    String? text = 'สวัสดี',
    String? replyToMessageId,
    DateTime? deletedAt,
  }) =>
      ChatMessage(
        id: id,
        conversationId: 'c1',
        senderId: senderId,
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
        text: text,
        replyToMessageId: replyToMessageId,
        deletedAt: deletedAt,
      );

  Widget buildScreen() => MaterialApp(
        home: ConversationScreen(
          chatRepository: chatRepo,
          conversationId: 'c1',
          otherUserId: 'other',
          otherUsername: 'namfah',
          otherDisplayName: 'น้ำฝน',
          blockRepository: blockRepo,
          moderationRepository: moderationRepo,
        ),
      );

  testWidgets('empty state shows a start-conversation prompt', (tester) async {
    chatRepo.messagesByConversation = const {};
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('เริ่มบทสนทนากับ'), findsOneWidget);
  });

  testWidgets('loads and shows existing messages, and marks the conversation read',
      (tester) async {
    chatRepo.messagesByConversation = {
      'c1': [message(text: 'สวัสดีจ้า')],
    };
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('สวัสดีจ้า'), findsOneWidget);
    expect(chatRepo.markConversationReadCalls, greaterThanOrEqualTo(1));
    expect(chatRepo.lastMarkConversationReadId, 'c1');
  });

  testWidgets('sending a text message calls sendMessage and shows the sent bubble',
      (tester) async {
    chatRepo.messagesByConversation = const {'c1': []};
    chatRepo.sendMessageResult = ChatMessage(
      id: 'm-sent',
      conversationId: 'c1',
      senderId: 'me',
      createdAt: DateTime.now(),
      text: 'ข้อความใหม่',
    );
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ข้อความใหม่');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(chatRepo.sendMessageCalls, 1);
    expect(chatRepo.lastSendMessageText, 'ข้อความใหม่');
    expect(find.text('ข้อความใหม่'), findsOneWidget);
  });

  testWidgets('replying to a message shows the quote bar and sends with replyToMessageId',
      (tester) async {
    chatRepo.messagesByConversation = {
      'c1': [message(id: 'm1', text: 'ข้อความต้นทาง')],
    };
    chatRepo.sendMessageResult = ChatMessage(
      id: 'm-reply',
      conversationId: 'c1',
      senderId: 'me',
      createdAt: DateTime.now(),
      text: 'ตอบกลับ',
      replyToMessageId: 'm1',
    );
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('ข้อความต้นทาง'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตอบกลับ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ตอบกลับ: ข้อความต้นทาง'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ตอบกลับ');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(chatRepo.lastSendMessageReplyToId, 'm1');
  });

  testWidgets('long-pressing a message that is itself a reply offers no "ตอบกลับ" option',
      (tester) async {
    chatRepo.messagesByConversation = {
      'c1': [
        message(id: 'm2', text: 'ข้อความตอบกลับ', replyToMessageId: 'm1'),
      ],
    };
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('ข้อความตอบกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('ตอบกลับ'), findsNothing);
  });

  testWidgets('deleting my own message calls deleteMessage and shows the deleted placeholder',
      (tester) async {
    chatRepo.messagesByConversation = {
      'c1': [message(id: 'm1', senderId: 'me', text: 'ลบข้อความนี้')],
    };
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('ลบข้อความนี้'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    // ConfirmDeleteDialog's own confirm button.
    await tester.tap(find.text('ลบ').last);
    await tester.pumpAndSettle();

    expect(chatRepo.deleteMessageCalls, 1);
    expect(chatRepo.lastDeleteMessageId, 'm1');
    expect(find.text('ข้อความนี้ถูกลบ'), findsOneWidget);
  });

  testWidgets(
      'WYN-084: opening the keyboard does not push the composer up by a second '
      'keyboard-height (no double bottom-inset compensation)', (tester) async {
    chatRepo.messagesByConversation = const {'c1': []};
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    const keyboardHeight = 300.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
    await tester.pumpAndSettle();

    // Scaffold's own resizeToAvoidBottomInset (default true) already
    // shrinks the body by keyboardHeight, so the composer's TextField
    // should sit right above the keyboard -- screenHeight - keyboardHeight
    // -- not pushed up by a *second* keyboardHeight's worth on top of
    // that (the old bug: a redundant Padding(bottom: viewInsets.bottom)
    // wrapped around the composer double-compensated).
    final textFieldBottom = tester.getBottomLeft(find.byType(TextField)).dy;
    expect(textFieldBottom, lessThanOrEqualTo(844 - keyboardHeight));
    expect(textFieldBottom, greaterThan(844 - keyboardHeight - 200));
  });

  testWidgets('blocked either way hides the composer with an explanatory message',
      (tester) async {
    blockRepo.blockRelationshipResult = BlockRelationship.blockedByMe;
    chatRepo.messagesByConversation = const {'c1': []};
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('คุณไม่สามารถส่งข้อความถึงผู้ใช้นี้ได้'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a Restrict in effect shows RestrictionBanner instead of the composer',
      (tester) async {
    moderationRepo.myStatus = ModerationStatus(
      isRestricted: true,
      restrictReason: 'สแปม',
      restrictExpiresAt: DateTime.now().add(const Duration(days: 1)),
      isSuspended: false,
      isBanned: false,
    );
    chatRepo.messagesByConversation = const {'c1': []};
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('คุณถูกจำกัดการโพสต์ชั่วคราว'), findsOneWidget);
  });

  testWidgets('Suspended hides the composer with an explanatory message', (tester) async {
    moderationRepo.myStatus = const ModerationStatus(
      isRestricted: false,
      isSuspended: true,
      isBanned: false,
    );
    chatRepo.messagesByConversation = const {'c1': []};
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('บัญชีของคุณถูกระงับ'), findsOneWidget);
  });

  testWidgets('a realtime message from the other side appears and marks the conversation read',
      (tester) async {
    chatRepo.messagesByConversation = const {'c1': []};
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final callsBefore = chatRepo.markConversationReadCalls;
    chatRepo.emitConversationMessage(message(id: 'm-live', text: 'ข้อความสด'));
    await tester.pumpAndSettle();

    expect(find.text('ข้อความสด'), findsOneWidget);
    expect(chatRepo.markConversationReadCalls, greaterThan(callsBefore));
  });

  testWidgets('a realtime echo of my own message is not duplicated', (tester) async {
    chatRepo.messagesByConversation = const {'c1': []};
    chatRepo.sendMessageResult = ChatMessage(
      id: 'm-dup',
      conversationId: 'c1',
      senderId: 'me',
      createdAt: DateTime.now(),
      text: 'ข้อความซ้ำ',
    );
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ข้อความซ้ำ');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // The realtime echo of the exact same id must not create a second bubble.
    chatRepo.emitConversationMessage(message(id: 'm-dup', senderId: 'me', text: 'ข้อความซ้ำ'));
    await tester.pumpAndSettle();

    expect(find.text('ข้อความซ้ำ'), findsOneWidget);
  });

  group('Chat Screen Message Grouping & Bubble Behavior spec: avatar '
      'grouping and date separators', () {
    testWidgets(
        'a consecutive run of "them" messages shows the avatar only once, '
        'on the newest (bottom-most on screen) bubble of the group -- '
        'grouping rule: same sender within 60s, same day', (tester) async {
      final now = DateTime.now();
      chatRepo.messagesByConversation = {
        // Newest first, matching what a real fetch returns.
        'c1': [
          ChatMessage(
              id: 'm3',
              conversationId: 'c1',
              senderId: 'other',
              createdAt: now,
              text: 'ข้อความที่ 3'),
          ChatMessage(
              id: 'm2',
              conversationId: 'c1',
              senderId: 'other',
              createdAt: now.subtract(const Duration(seconds: 30)),
              text: 'ข้อความที่ 2'),
          ChatMessage(
              id: 'm1',
              conversationId: 'c1',
              senderId: 'me',
              createdAt: now.subtract(const Duration(minutes: 1)),
              text: 'ข้อความที่ 1'),
        ],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('ข้อความที่ 1'), findsOneWidget);
      expect(find.text('ข้อความที่ 2'), findsOneWidget);
      expect(find.text('ข้อความที่ 3'), findsOneWidget);

      // Bubble avatars use radius 15 -- distinct from the AppBar's own
      // identity avatar (radius 14) and the empty-state avatar (radius
      // 40), so this count only reflects bubbles.
      final bubbleAvatars = find.byWidgetPredicate(
        (widget) => widget is AvatarCircle && widget.radius == 15,
      );
      expect(bubbleAvatars, findsOneWidget);

      // It sits beside the newest bubble of the "other" run (m3, closer
      // to the composer) rather than the run's oldest bubble (m2).
      final avatarY = tester.getCenter(bubbleAvatars).dy;
      final m3Y = tester.getCenter(find.text('ข้อความที่ 3')).dy;
      final m2Y = tester.getCenter(find.text('ข้อความที่ 2')).dy;
      expect((avatarY - m3Y).abs(), lessThan((avatarY - m2Y).abs()));
    });

    // Fixed, distinctly-past date (not "today"/"yesterday" relative to
    // whenever this test happens to run) so the separator label always
    // takes _dateLabel's "D <Thai month>" fallback branch -- deterministic
    // regardless of wall-clock time or a midnight-crossing test run.
    final anchor = DateTime(2020, 6, 15, 12);

    testWidgets(
        'no date separator between two same-day messages -- only one at '
        'the very start of the loaded history, even hours apart (spec: '
        'date-only, not a 30-minute time gap)', (tester) async {
      chatRepo.messagesByConversation = {
        'c1': [
          ChatMessage(
              id: 'm2',
              conversationId: 'c1',
              senderId: 'other',
              createdAt: anchor,
              text: 'ข้อความล่าสุด'),
          ChatMessage(
              id: 'm1',
              conversationId: 'c1',
              senderId: 'other',
              createdAt: anchor.subtract(const Duration(hours: 2)),
              text: 'ข้อความก่อนหน้า'),
        ],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Same calendar day despite the 2-hour gap -- only the
      // start-of-history separator, date-only, no time.
      expect(find.text('15 มิถุนายน'), findsOneWidget);
    });

    testWidgets('a message on a different calendar day gets its own date '
        'separator', (tester) async {
      chatRepo.messagesByConversation = {
        'c1': [
          ChatMessage(
              id: 'm2',
              conversationId: 'c1',
              senderId: 'other',
              createdAt: anchor,
              text: 'ข้อความใหม่'),
          ChatMessage(
              id: 'm1',
              conversationId: 'c1',
              senderId: 'other',
              createdAt: anchor.subtract(const Duration(days: 1)),
              text: 'ข้อความเก่า'),
        ],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // The day boundary between the 2 messages, and the very start of
      // history (the older message), each get their own separator.
      expect(find.text('15 มิถุนายน'), findsOneWidget);
      expect(find.text('14 มิถุนายน'), findsOneWidget);
    });
  });

  group('Message Request (WYN-032)', () {
    testWidgets(
        'as the recipient (not requestedBy): messages readable, composer replaced '
        'with Accept/Delete/Block/Report', (tester) async {
      chatRepo.conversationMetaResult = (status: 'pending', requestedBy: 'other', otherUserLastReadAt: null);
      chatRepo.messagesByConversation = {
        'c1': [message(text: 'อยากรู้จักครับ')],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('อยากรู้จักครับ'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('ต้องการส่งข้อความถึงคุณ'), findsOneWidget);
      expect(find.text('ยอมรับ'), findsOneWidget);
      expect(find.text('ลบ'), findsOneWidget);
      expect(find.text('บล็อก'), findsOneWidget);
      expect(find.text('รายงาน'), findsOneWidget);
    });

    testWidgets('tapping ยอมรับ accepts the request and the composer becomes normal',
        (tester) async {
      chatRepo.conversationMetaResult = (status: 'pending', requestedBy: 'other', otherUserLastReadAt: null);
      chatRepo.messagesByConversation = {
        'c1': [message()],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('ยอมรับ'));
      await tester.pumpAndSettle();

      expect(chatRepo.acceptMessageRequestCalls, 1);
      expect(chatRepo.lastAcceptMessageRequestId, 'c1');
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('tapping ลบ confirms then deletes the request and pops the screen',
        (tester) async {
      chatRepo.conversationMetaResult = (status: 'pending', requestedBy: 'other', otherUserLastReadAt: null);
      chatRepo.messagesByConversation = {
        'c1': [message()],
      };
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ConversationScreen(
                      chatRepository: chatRepo,
                      conversationId: 'c1',
                      otherUserId: 'other',
                      otherUsername: 'namfah',
                      otherDisplayName: 'น้ำฝน',
                      blockRepository: blockRepo,
                      moderationRepository: moderationRepo,
                    ),
                  ),
                ),
                child: const Text('เปิดคำขอ'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('เปิดคำขอ'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ลบ').first);
      await tester.pumpAndSettle();
      // The confirm dialog's own "ลบ" button.
      await tester.tap(find.text('ลบ').last);
      await tester.pumpAndSettle();

      expect(chatRepo.deleteMessageRequestCalls, 1);
      expect(chatRepo.lastDeleteMessageRequestId, 'c1');
      expect(find.text('เปิดคำขอ'), findsOneWidget);
    });

    testWidgets('tapping บล็อก blocks the sender and switches to the blocked message',
        (tester) async {
      chatRepo.conversationMetaResult = (status: 'pending', requestedBy: 'other', otherUserLastReadAt: null);
      chatRepo.messagesByConversation = {
        'c1': [message()],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('บล็อก'));
      await tester.pumpAndSettle();
      // confirmBlock's own confirm button.
      await tester.tap(find.text('บล็อก').last);
      await tester.pumpAndSettle();

      expect(blockRepo.blockUserCalls, 1);
      expect(find.text('คุณไม่สามารถส่งข้อความถึงผู้ใช้นี้ได้'), findsOneWidget);
    });

    testWidgets('tapping รายงาน opens the report sheet targeting the user', (tester) async {
      chatRepo.conversationMetaResult = (status: 'pending', requestedBy: 'other', otherUserLastReadAt: null);
      chatRepo.messagesByConversation = {
        'c1': [message()],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('รายงาน'));
      await tester.pumpAndSettle();

      expect(find.text('รายงานผู้ใช้นี้'), findsOneWidget);
    });

    testWidgets('as the requester (requestedBy == me): composer stays normal with an '
        'awaiting-response label', (tester) async {
      chatRepo.conversationMetaResult = (status: 'pending', requestedBy: 'me', otherUserLastReadAt: null);
      chatRepo.messagesByConversation = {
        'c1': [message()],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('รอการตอบรับ'), findsOneWidget);
      expect(find.text('ยอมรับ'), findsNothing);
    });
  });

  group('Delivery/read receipt (spec section 7)', () {
    testWidgets(
        'sending shows a pending bubble with the sending indicator; it '
        'flips to a plain sent checkmark once the send resolves',
        (tester) async {
      chatRepo.messagesByConversation = const {'c1': []};
      chatRepo.sendMessageGate = Completer<void>();
      chatRepo.sendMessageResult = ChatMessage(
        id: 'm-sent',
        conversationId: 'c1',
        senderId: 'me',
        createdAt: DateTime.now(),
        text: 'กำลังส่ง',
      );
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'กำลังส่ง');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(); // Optimistic insert lands; sendMessage is still gated.

      // The composer clears immediately (optimistic, not on success) --
      // keeps the TextField's content, focus, and keyboard undisturbed
      // for typing the next message -- so only the new pending bubble
      // shows this text now, not also the (already-emptied) TextField.
      expect(find.text('กำลังส่ง'), findsOneWidget);
      expect(find.byIcon(Icons.fiber_manual_record), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      chatRepo.sendMessageGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fiber_manual_record), findsNothing);
      final checkIcon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(checkIcon.color, WynColors.faint);
    });

    testWidgets(
        'the last outgoing bubble flips from sent to read when the other '
        "participant's last-read timestamp moves past it (realtime "
        'conversation-meta update)', (tester) async {
      final sentAt = DateTime.now();
      chatRepo.messagesByConversation = {
        'c1': [
          ChatMessage(
              id: 'm1',
              conversationId: 'c1',
              senderId: 'me',
              createdAt: sentAt,
              text: 'อ่านหรือยัง'),
        ],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      var checkIcon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(checkIcon.color, WynColors.faint);

      chatRepo.emitConversationMetaUpdate((
        status: 'active',
        requestedBy: null,
        otherUserLastReadAt: sentAt.add(const Duration(seconds: 1)),
      ));
      await tester.pumpAndSettle();

      checkIcon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(checkIcon.color, WynColors.sapphire);
    });
  });

  testWidgets(
      'tapping a bubble reveals its time label for ~2 seconds, then it '
      'auto-dismisses (spec section 6)', (tester) async {
    final sentAt = DateTime(2020, 6, 15, 18, 44);
    chatRepo.messagesByConversation = {
      'c1': [
        ChatMessage(
            id: 'm1', conversationId: 'c1', senderId: 'me', createdAt: sentAt, text: 'แตะดูเวลา'),
      ],
    };
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('18:44'), findsNothing);

    await tester.tap(find.text('แตะดูเวลา'));
    await tester.pump();

    expect(find.text('18:44'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));

    expect(find.text('18:44'), findsNothing);
  });
}
