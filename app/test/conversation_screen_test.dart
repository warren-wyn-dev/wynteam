import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/core/design/wyn_colors.dart';
import 'package:wyn/features/block/data/block_relationship.dart';
import 'package:wyn/features/chat/data/chat_message.dart';
import 'package:wyn/features/chat/data/pinned_message.dart';
import 'package:wyn/features/chat/presentation/conversation_screen.dart';
import 'package:wyn/features/moderation/data/moderation_status.dart';
import 'package:wyn/features/profile/presentation/widgets/avatar_circle.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_block_repository.dart';
import 'support/recording_chat_repository.dart';
import 'support/recording_moderation_repository.dart';
import 'support/recording_presence_repository.dart';

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
    String? imageUrl,
    String? replyToMessageId,
    DateTime? deletedAt,
    bool viewOnce = false,
    DateTime? viewedAt,
    DateTime? editedAt,
    String? replyPreviewText,
    String? replyPreviewImageUrl,
    DateTime? replyPreviewDeletedAt,
  }) => ChatMessage(
    id: id,
    conversationId: 'c1',
    senderId: senderId,
    createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
    text: text,
    imageUrl: imageUrl,
    replyToMessageId: replyToMessageId,
    deletedAt: deletedAt,
    viewOnce: viewOnce,
    viewedAt: viewedAt,
    editedAt: editedAt,
    replyPreviewText: replyPreviewText,
    replyPreviewImageUrl: replyPreviewImageUrl,
    replyPreviewDeletedAt: replyPreviewDeletedAt,
  );

  // presenceRepository always defaults to a Recording fake -- a real
  // PresenceRepository's subscribeTypingChannel/startGlobalPresence
  // attempt a real WebSocket handshake against this suite's placeholder
  // Supabase project, which leaves a pending realtime_client Timer
  // behind and fails flutter_test's own `!timersPending` invariant at
  // teardown.
  Widget buildScreen({RecordingPresenceRepository? presenceRepository}) =>
      MaterialApp(
        home: ConversationScreen(
          chatRepository: chatRepo,
          conversationId: 'c1',
          otherUserId: 'other',
          otherUsername: 'namfah',
          otherDisplayName: 'น้ำฝน',
          blockRepository: blockRepo,
          moderationRepository: moderationRepo,
          presenceRepository:
              presenceRepository ?? RecordingPresenceRepository(),
        ),
      );

  testWidgets('empty state shows a start-conversation prompt', (tester) async {
    chatRepo.messagesByConversation = const {};
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('เริ่มบทสนทนากับ'), findsOneWidget);
  });

  testWidgets('WYN-122: chat lockdown shows the closed-for-maintenance message '
      'instead of the message list or composer, and never fetches messages', (
    tester,
  ) async {
    chatRepo.isChatAllowedResult = false;
    chatRepo.messagesByConversation = {
      'c1': [message(text: 'ข้อความเก่าที่ไม่ควรเห็น')],
    };

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ระบบแชทปิดปรับปรุงชั่วคราว'), findsOneWidget);
    expect(find.text('ข้อความเก่าที่ไม่ควรเห็น'), findsNothing);
    expect(find.textContaining('เริ่มบทสนทนากับ'), findsNothing);
    // Composer's TextField must be gone too, not just the message list.
    expect(find.byType(TextField), findsNothing);
    expect(chatRepo.isChatAllowedCalls, ['other']);
    expect(chatRepo.markConversationReadCalls, 0);
  });

  testWidgets('WYN-122 regression: chat allowed (the common case) still loads '
      'messages exactly as before', (tester) async {
    chatRepo.isChatAllowedResult = true;
    chatRepo.messagesByConversation = {
      'c1': [message(text: 'สวัสดีจ้า')],
    };

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('สวัสดีจ้า'), findsOneWidget);
    expect(find.text('ระบบแชทปิดปรับปรุงชั่วคราว'), findsNothing);
    expect(chatRepo.markConversationReadCalls, 1);
  });

  testWidgets(
    'loads and shows existing messages, and marks the conversation read',
    (tester) async {
      chatRepo.messagesByConversation = {
        'c1': [message(text: 'สวัสดีจ้า')],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('สวัสดีจ้า'), findsOneWidget);
      expect(chatRepo.markConversationReadCalls, greaterThanOrEqualTo(1));
      expect(chatRepo.lastMarkConversationReadId, 'c1');
    },
  );

  testWidgets(
    'sending a text message calls sendMessage and shows the sent bubble',
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
    },
  );

  testWidgets(
    'replying to a message shows the quote bar and sends with replyToMessageId',
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
    },
  );

  testWidgets(
    'long-pressing a message that is itself a reply offers no "ตอบกลับ" option',
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
    },
  );

  // Founder feedback: tapping a reply quote used to scroll to
  // `index * 72.0` -- a fixed-height guess that drifts off target the
  // moment the bubbles in between aren't a plain one-line text message.
  // Every filler here is a 160x160 image bubble specifically so the old
  // guess (sized for ordinary text rows) undershoots by a wide, obvious
  // margin rather than coincidentally landing close by luck.
  testWidgets(
    'tapping a reply quote scrolls to the actual original message, not '
    'a fixed-height guess',
    (tester) async {
      final fillers = List.generate(
        25,
        (i) => message(
          id: 'filler-${i + 1}',
          text: null,
          imageUrl: 'c1/filler-${i + 1}.jpg',
        ),
      );
      chatRepo.signedUrlResult =
          'https://example.supabase.co/signed/filler.jpg';
      chatRepo.messagesByConversation = {
        'c1': [
          message(
            id: 'reply',
            text: 'ตอบกลับ',
            replyToMessageId: 'target',
            replyPreviewText: 'ตัวอย่างข้อความอ้างอิง',
          ),
          ...fillers,
          message(id: 'target', text: 'ข้อความต้นฉบับที่อยู่ไกลมาก'),
        ],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      // The filler messages' fake signed image URLs 404 in a test --
      // harmless NetworkImageLoadException noise, same convention as
      // bookmarks_screen_test.dart's own takeException() calls.
      tester.takeException();

      // Far enough away that it isn't built at all yet -- proves this
      // actually scrolled there, not that it was already on screen.
      expect(find.text('ข้อความต้นฉบับที่อยู่ไกลมาก'), findsNothing);

      await tester.tap(find.byKey(const Key('reply_quote_reply')));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('ข้อความต้นฉบับที่อยู่ไกลมาก'), findsOneWidget);
    },
  );

  testWidgets(
    'reply with no hydrated preview does not render an empty quote shell',
    (tester) async {
      chatRepo.messagesByConversation = {
        'c1': [
          message(
            id: 'reply-without-preview',
            text: 'ตอบกลับ',
            replyToMessageId: 'target',
          ),
        ],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('ตอบกลับ'), findsOneWidget);
      expect(
        find.byKey(const Key('reply_quote_reply-without-preview')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'deleting my own message calls deleteMessage and shows the deleted placeholder',
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
    },
  );

  // Regression: ChatRepository.deleteMessage now needs the message's
  // imageUrl (not just its id) to also clean up the underlying
  // chat-media storage object -- delete_message() itself only ever
  // nulled the DB reference, leaving the file orphaned forever. This
  // proves ConversationScreen still passes the *whole* message through
  // after that signature change, not just `message.id`.
  testWidgets('deleting my own image message passes the full message (with its '
      'imageUrl) to deleteMessage', (tester) async {
    chatRepo.messagesByConversation = {
      'c1': [
        message(
          id: 'm1',
          senderId: 'me',
          text: null,
          imageUrl: 'c1/me-123.jpg',
        ),
      ],
    };
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const Key('chat_image_m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ').last);
    await tester.pumpAndSettle();

    expect(chatRepo.deleteMessageCalls, 1);
    expect(chatRepo.lastDeletedMessage?.id, 'm1');
    expect(chatRepo.lastDeletedMessage?.imageUrl, 'c1/me-123.jpg');
  });

  // Founder feedback: an ordinary (not View Once) chat photo used to
  // render a fixed gray placeholder icon forever -- the real image was
  // only ever fetched once the recipient tapped it open full-screen.
  group('Chat photo thumbnails (Founder feedback)', () {
    testWidgets('renders the actual photo inline, not a placeholder icon', (
      tester,
    ) async {
      chatRepo.messagesByConversation = {
        'c1': [message(id: 'm1', text: null, imageUrl: 'c1/other-1.jpg')],
      };
      chatRepo.signedUrlResult =
          'https://example.supabase.co/signed/other-1.jpg';
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      // The signed URL 404s in a test -- harmless NetworkImageLoadException
      // noise, same convention as bookmarks_screen_test.dart's own
      // takeException() calls (the errorBuilder inside NetworkThumbnail
      // keeps this from affecting layout).
      tester.takeException();

      expect(find.byKey(const Key('chat_image_m1')), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      // NetworkThumbnail decodes at a bounded size via `cacheWidth`,
      // which wraps the underlying NetworkImage in a ResizeImage.
      final resized = image.image as ResizeImage;
      expect(
        (resized.imageProvider as NetworkImage).url,
        chatRepo.signedUrlResult,
      );
    });

    testWidgets('a photo whose signed URL fails to mint (e.g. the object was '
        'already deleted) shows a broken-image icon, not a silent hole', (
      tester,
    ) async {
      chatRepo.messagesByConversation = {
        'c1': [message(id: 'm1', text: null, imageUrl: 'c1/gone.jpg')],
      };
      chatRepo.signedUrlResult = null;
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets(
      'a new incoming message does not re-fetch the signed URL for an '
      'already-rendered photo further down the list',
      (tester) async {
        chatRepo.messagesByConversation = {
          'c1': [message(id: 'm1', text: null, imageUrl: 'c1/other-1.jpg')],
        };
        chatRepo.signedUrlResult =
            'https://example.supabase.co/signed/other-1.jpg';
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();
        tester.takeException();
        expect(chatRepo.imageSignedUrlCalls, 1);

        // New messages are inserted at the front (see ConversationScreen's
        // own reverse:true list) -- this shifts m1's bubble down a slot.
        // Without ConversationScreen's own signed-URL cache, that shift
        // alone (not just a second image message) would trigger a second
        // fetch for the exact same path.
        chatRepo.emitConversationMessage(
          message(id: 'm2', senderId: 'other', text: 'ข้อความใหม่'),
        );
        await tester.pumpAndSettle();
        tester.takeException();

        expect(chatRepo.imageSignedUrlCalls, 1);
      },
    );
  });

  // Founder feedback -- View Once chat photos.
  group('View Once (Founder feedback)', () {
    testWidgets('the recipient sees a tappable "แตะเพื่อดู" placeholder for an '
        'unopened photo, and the sender never does', (tester) async {
      chatRepo.messagesByConversation = {
        'c1': [
          message(
            id: 'm1',
            senderId: 'other',
            text: null,
            imageUrl: 'c1/other-1.jpg',
            viewOnce: true,
          ),
        ],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('แตะเพื่อดู'), findsOneWidget);
      expect(find.text('ส่งแล้ว รอเปิดดู'), findsNothing);
    });

    testWidgets(
      'the sender sees a non-tappable "ส่งแล้ว รอเปิดดู" placeholder for '
      'their own unopened photo',
      (tester) async {
        chatRepo.messagesByConversation = {
          'c1': [
            message(
              id: 'm1',
              senderId: 'me',
              text: null,
              imageUrl: 'c1/me-1.jpg',
              viewOnce: true,
            ),
          ],
        };
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.text('ส่งแล้ว รอเปิดดู'), findsOneWidget);
        expect(find.text('แตะเพื่อดู'), findsNothing);
      },
    );

    testWidgets('an opened photo (imageUrl already cleared) shows "เปิดดูแล้ว" '
        'for both sender and recipient, never tappable', (tester) async {
      chatRepo.messagesByConversation = {
        'c1': [
          message(
            id: 'm1',
            senderId: 'other',
            text: null,
            imageUrl: null,
            viewOnce: true,
            viewedAt: DateTime.now(),
          ),
        ],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('เปิดดูแล้ว'), findsOneWidget);
      expect(find.text('แตะเพื่อดู'), findsNothing);
    });

    testWidgets(
      'the recipient tapping the placeholder marks it viewed, opens the '
      'signed image, and expires it once the viewer closes',
      (tester) async {
        chatRepo.messagesByConversation = {
          'c1': [
            message(
              id: 'm1',
              senderId: 'other',
              text: null,
              imageUrl: 'c1/other-1.jpg',
              viewOnce: true,
            ),
          ],
        };
        chatRepo.signedUrlResult =
            'https://example.supabase.co/signed/other-1.jpg';
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('แตะเพื่อดู'));
        // Not pumpAndSettle() -- ViewOnceImageViewer's own countdown Timer
        // keeps scheduling frames for its full duration (8s default), so
        // pumpAndSettle would sit here until it auto-pops on its own
        // (that path is covered in isolation by
        // view_once_image_viewer_test.dart). A couple of bounded pumps,
        // well short of the first 1s tick, is enough to let the
        // markViewOnceViewed -> imageSignedUrl -> Navigator.push chain
        // (no real delay in any of those, just ordinary async gaps) run
        // and the push transition settle.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(chatRepo.markViewOnceViewedCalls, 1);
        expect(chatRepo.lastMarkViewOnceViewedId, 'm1');
        // The viewer is open -- popped directly here (the close button) to
        // prove *this* screen expires the message on close, same as a
        // natural timeout would.
        expect(find.byKey(const Key('view_once_close_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('view_once_close_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(chatRepo.expireViewOnceMessageCalls, 1);
        expect(chatRepo.lastExpiredViewOnceMessage?.id, 'm1');
        // Back on the conversation screen, the bubble already reflects
        // "opened" -- this screen updates its local state right after
        // expireViewOnceMessage succeeds, not only once a realtime echo
        // (if any) arrives.
        expect(find.text('เปิดดูแล้ว'), findsOneWidget);
      },
    );

    testWidgets(
      'reopening a message whose earlier view never finished (viewedAt '
      'already set, imageUrl still present) does not call '
      'markViewOnceViewed again',
      (tester) async {
        chatRepo.messagesByConversation = {
          'c1': [
            message(
              id: 'm1',
              senderId: 'other',
              text: null,
              imageUrl: 'c1/other-1.jpg',
              viewOnce: true,
              viewedAt: DateTime.now().subtract(const Duration(minutes: 1)),
            ),
          ],
        };
        chatRepo.signedUrlResult =
            'https://example.supabase.co/signed/other-1.jpg';
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Still tappable/resumable -- see _buildViewOnceThumbnail's own
        // doc comment on why an interrupted-countdown message must not be
        // stuck forever. Bounded pumps, not pumpAndSettle() -- see the
        // identical comment on the test above.
        await tester.tap(find.text('แตะเพื่อดู'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(chatRepo.markViewOnceViewedCalls, 0);
        expect(find.byKey(const Key('view_once_close_button')), findsOneWidget);

        // Close it -- leaving ViewOnceImageViewer's own countdown Timer
        // pending past the end of this test would trip flutter_test's
        // "!timersPending" invariant, same class of issue this project's
        // own Recording* repositories are already careful to avoid.
        await tester.tap(find.byKey(const Key('view_once_close_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      },
    );

    testWidgets(
      'a realtime UPDATE flips the sender\'s own bubble from "waiting" to '
      '"opened" live',
      (tester) async {
        chatRepo.messagesByConversation = {
          'c1': [
            message(
              id: 'm1',
              senderId: 'me',
              text: null,
              imageUrl: 'c1/me-1.jpg',
              viewOnce: true,
            ),
          ],
        };
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();
        expect(find.text('ส่งแล้ว รอเปิดดู'), findsOneWidget);

        chatRepo.emitConversationMessageUpdate(
          message(
            id: 'm1',
            senderId: 'me',
            text: null,
            imageUrl: null,
            viewOnce: true,
            viewedAt: DateTime.now(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('เปิดดูแล้ว'), findsOneWidget);
        expect(find.text('ส่งแล้ว รอเปิดดู'), findsNothing);
      },
    );
  });

  testWidgets(
    'WYN-084: opening the keyboard does not push the composer up by a second '
    'keyboard-height (no double bottom-inset compensation)',
    (tester) async {
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
    },
  );

  testWidgets(
    'blocked either way hides the composer with an explanatory message',
    (tester) async {
      blockRepo.blockRelationshipResult = BlockRelationship.blockedByMe;
      chatRepo.messagesByConversation = const {'c1': []};
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text('คุณไม่สามารถส่งข้อความถึงผู้ใช้นี้ได้'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets(
    'a Restrict in effect shows RestrictionBanner instead of the composer',
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
      expect(
        find.textContaining('คุณถูกจำกัดการโพสต์ชั่วคราว'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Suspended hides the composer with an explanatory message', (
    tester,
  ) async {
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

  testWidgets(
    'a realtime message from the other side appears and marks the conversation read',
    (tester) async {
      chatRepo.messagesByConversation = const {'c1': []};
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final callsBefore = chatRepo.markConversationReadCalls;
      chatRepo.emitConversationMessage(
        message(id: 'm-live', text: 'ข้อความสด'),
      );
      await tester.pumpAndSettle();

      expect(find.text('ข้อความสด'), findsOneWidget);
      expect(chatRepo.markConversationReadCalls, greaterThan(callsBefore));
    },
  );

  testWidgets('a realtime echo of my own message is not duplicated', (
    tester,
  ) async {
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
    chatRepo.emitConversationMessage(
      message(id: 'm-dup', senderId: 'me', text: 'ข้อความซ้ำ'),
    );
    await tester.pumpAndSettle();

    expect(find.text('ข้อความซ้ำ'), findsOneWidget);
  });

  group('Chat Screen Message Grouping & Bubble Behavior spec: avatar '
      'grouping and date separators', () {
    testWidgets(
      'a consecutive run of "them" messages shows the avatar only once, '
      'on the newest (bottom-most on screen) bubble of the group -- '
      'grouping rule: same sender within 60s, same day',
      (tester) async {
        final now = DateTime.now();
        chatRepo.messagesByConversation = {
          // Newest first, matching what a real fetch returns.
          'c1': [
            ChatMessage(
              id: 'm3',
              conversationId: 'c1',
              senderId: 'other',
              createdAt: now,
              text: 'ข้อความที่ 3',
            ),
            ChatMessage(
              id: 'm2',
              conversationId: 'c1',
              senderId: 'other',
              createdAt: now.subtract(const Duration(seconds: 30)),
              text: 'ข้อความที่ 2',
            ),
            ChatMessage(
              id: 'm1',
              conversationId: 'c1',
              senderId: 'me',
              createdAt: now.subtract(const Duration(minutes: 1)),
              text: 'ข้อความที่ 1',
            ),
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
      },
    );

    // Fixed, distinctly-past date (not "today"/"yesterday" relative to
    // whenever this test happens to run) so the separator label always
    // takes _dateLabel's "D <Thai month>" fallback branch -- deterministic
    // regardless of wall-clock time or a midnight-crossing test run.
    final anchor = DateTime(2020, 6, 15, 12);

    testWidgets(
      'no date separator between two same-day messages -- only one at '
      'the very start of the loaded history, even hours apart (spec: '
      'date-only, not a 30-minute time gap)',
      (tester) async {
        chatRepo.messagesByConversation = {
          'c1': [
            ChatMessage(
              id: 'm2',
              conversationId: 'c1',
              senderId: 'other',
              createdAt: anchor,
              text: 'ข้อความล่าสุด',
            ),
            ChatMessage(
              id: 'm1',
              conversationId: 'c1',
              senderId: 'other',
              createdAt: anchor.subtract(const Duration(hours: 2)),
              text: 'ข้อความก่อนหน้า',
            ),
          ],
        };
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Same calendar day despite the 2-hour gap -- only the
        // start-of-history separator, date-only, no time.
        expect(find.text('15 มิถุนายน'), findsOneWidget);
      },
    );

    testWidgets('a message on a different calendar day gets its own date '
        'separator', (tester) async {
      chatRepo.messagesByConversation = {
        'c1': [
          ChatMessage(
            id: 'm2',
            conversationId: 'c1',
            senderId: 'other',
            createdAt: anchor,
            text: 'ข้อความใหม่',
          ),
          ChatMessage(
            id: 'm1',
            conversationId: 'c1',
            senderId: 'other',
            createdAt: anchor.subtract(const Duration(days: 1)),
            text: 'ข้อความเก่า',
          ),
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
    testWidgets('as the recipient (not requestedBy): messages readable, composer replaced '
        'with Accept/Delete/Block/Report', (tester) async {
      chatRepo.conversationMetaResult = (
        status: 'pending',
        requestedBy: 'other',
        otherUserLastReadAt: null,
      );
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

    testWidgets(
      'tapping ยอมรับ accepts the request and the composer becomes normal',
      (tester) async {
        chatRepo.conversationMetaResult = (
          status: 'pending',
          requestedBy: 'other',
          otherUserLastReadAt: null,
        );
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
      },
    );

    testWidgets(
      'tapping ลบ confirms then deletes the request and pops the screen',
      (tester) async {
        chatRepo.conversationMetaResult = (
          status: 'pending',
          requestedBy: 'other',
          otherUserLastReadAt: null,
        );
        chatRepo.messagesByConversation = {
          'c1': [message()],
        };
        await tester.pumpWidget(
          MaterialApp(
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
                          presenceRepository: RecordingPresenceRepository(),
                        ),
                      ),
                    ),
                    child: const Text('เปิดคำขอ'),
                  ),
                ),
              ),
            ),
          ),
        );
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
      },
    );

    testWidgets(
      'tapping บล็อก blocks the sender and switches to the blocked message',
      (tester) async {
        chatRepo.conversationMetaResult = (
          status: 'pending',
          requestedBy: 'other',
          otherUserLastReadAt: null,
        );
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
        expect(
          find.text('คุณไม่สามารถส่งข้อความถึงผู้ใช้นี้ได้'),
          findsOneWidget,
        );
      },
    );

    testWidgets('tapping รายงาน opens the report sheet targeting the user', (
      tester,
    ) async {
      chatRepo.conversationMetaResult = (
        status: 'pending',
        requestedBy: 'other',
        otherUserLastReadAt: null,
      );
      chatRepo.messagesByConversation = {
        'c1': [message()],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('รายงาน'));
      await tester.pumpAndSettle();

      expect(find.text('รายงานผู้ใช้นี้'), findsOneWidget);
    });

    testWidgets(
      'as the requester (requestedBy == me): composer stays normal with an '
      'awaiting-response label',
      (tester) async {
        chatRepo.conversationMetaResult = (
          status: 'pending',
          requestedBy: 'me',
          otherUserLastReadAt: null,
        );
        chatRepo.messagesByConversation = {
          'c1': [message()],
        };
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('รอการตอบรับ'), findsOneWidget);
        expect(find.text('ยอมรับ'), findsNothing);
      },
    );
  });

  group('Delivery/read receipt (spec section 7)', () {
    testWidgets('sending shows a pending bubble with the sending indicator; it '
        'flips to a plain sent checkmark once the send resolves', (
      tester,
    ) async {
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
      await tester
          .pump(); // Optimistic insert lands; sendMessage is still gated.

      // The composer clears immediately (optimistic, not on success) --
      // keeps the TextField's content, focus, and keyboard undisturbed
      // for typing the next message -- so only the new pending bubble
      // shows this text now, not also the (already-emptied) TextField.
      expect(find.text('กำลังส่ง'), findsOneWidget);
      expect(find.byIcon(Icons.fiber_manual_record), findsOneWidget);
      expect(find.text('ส่งแล้ว'), findsNothing);

      chatRepo.sendMessageGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fiber_manual_record), findsNothing);
      // A spelled-out label, not an icon -- see "อ่านแล้ว" below.
      final sentLabel = tester.widget<Text>(find.text('ส่งแล้ว'));
      expect(sentLabel.style?.color, WynColors.faint);
    });

    testWidgets(
      'the last outgoing bubble flips from sent to read when the other '
      "participant's last-read timestamp moves past it (realtime "
      'conversation-meta update)',
      (tester) async {
        final sentAt = DateTime.now();
        chatRepo.messagesByConversation = {
          'c1': [
            ChatMessage(
              id: 'm1',
              conversationId: 'c1',
              senderId: 'me',
              createdAt: sentAt,
              text: 'อ่านหรือยัง',
            ),
          ],
        };
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Sent (not yet read).
        expect(find.text('ส่งแล้ว'), findsOneWidget);
        expect(find.text('อ่านแล้ว'), findsNothing);
        final sentLabel = tester.widget<Text>(find.text('ส่งแล้ว'));
        expect(sentLabel.style?.color, WynColors.faint);

        chatRepo.emitConversationMetaUpdate((
          status: 'active',
          requestedBy: null,
          otherUserLastReadAt: sentAt.add(const Duration(seconds: 1)),
        ));
        await tester.pumpAndSettle();

        // Read.
        expect(find.text('ส่งแล้ว'), findsNothing);
        final readLabel = tester.widget<Text>(find.text('อ่านแล้ว'));
        expect(readLabel.style?.color, WynColors.graphite);
      },
    );
  });

  testWidgets('tapping a bubble reveals its time label for ~2 seconds, then it '
      'auto-dismisses (spec section 6)', (tester) async {
    final sentAt = DateTime(2020, 6, 15, 18, 44);
    chatRepo.messagesByConversation = {
      'c1': [
        ChatMessage(
          id: 'm1',
          conversationId: 'c1',
          senderId: 'me',
          createdAt: sentAt,
          text: 'แตะดูเวลา',
        ),
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

  group('WYN-138: Edit + Pin Message', () {
    testWidgets('editing my own text message updates the bubble optimistically '
        'and shows the "แก้ไขแล้ว" label', (tester) async {
      chatRepo.messagesByConversation = {
        'c1': [message(id: 'm1', senderId: 'me', text: 'ข้อความเดิม')],
      };
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('ข้อความเดิม'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('แก้ไข'));
      await tester.pumpAndSettle();

      expect(find.text('กำลังแก้ไขข้อความ'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'ข้อความเดิม');

      await tester.enterText(find.byType(TextField), 'ข้อความใหม่');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(chatRepo.editMessageCalls, 1);
      expect(chatRepo.lastEditMessageId, 'm1');
      expect(chatRepo.lastEditMessageText, 'ข้อความใหม่');
      expect(find.text('ข้อความใหม่'), findsOneWidget);
      expect(find.text('แก้ไขแล้ว'), findsOneWidget);
      expect(find.text('กำลังแก้ไขข้อความ'), findsNothing);
    });

    testWidgets('editing offers no option for an image message or for another '
        "person's message", (tester) async {
      chatRepo.messagesByConversation = {
        'c1': [
          message(
            id: 'm1',
            senderId: 'me',
            text: null,
            imageUrl: 'c1/me-1.jpg',
          ),
          message(id: 'm2', senderId: 'other', text: 'ข้อความของอีกฝ่าย'),
        ],
      };
      chatRepo.signedUrlResult = 'https://example.supabase.co/signed/me-1.jpg';
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      tester.takeException(); // fake signed image URL 404s -- harmless.

      await tester.longPress(find.byKey(const Key('chat_image_m1')));
      await tester.pumpAndSettle();
      expect(find.text('แก้ไข'), findsNothing);
      // "ปักหมุดข้อความ" still available -- pin has no such restriction.
      expect(find.text('ปักหมุดข้อความ'), findsOneWidget);
      await tester.tapAt(
        const Offset(10, 10),
      ); // dismiss via the sheet's barrier
      await tester.pumpAndSettle();

      await tester.longPress(find.text('ข้อความของอีกฝ่าย'));
      await tester.pumpAndSettle();
      expect(find.text('แก้ไข'), findsNothing);
    });

    testWidgets(
      'an edit failure keeps the composer in edit mode with the typed '
      'text intact, and restores the original bubble',
      (tester) async {
        chatRepo.messagesByConversation = {
          'c1': [message(id: 'm1', senderId: 'me', text: 'ข้อความเดิม')],
        };
        chatRepo.editMessageError = Exception('boom');
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        await tester.longPress(find.text('ข้อความเดิม'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('แก้ไข'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'ข้อความใหม่');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();

        expect(
          find.text('แก้ไขข้อความไม่สำเร็จ ลองใหม่อีกครั้ง'),
          findsOneWidget,
        );
        expect(find.text('ข้อความเดิม'), findsOneWidget);
        expect(find.text('กำลังแก้ไขข้อความ'), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller?.text, 'ข้อความใหม่');
      },
    );

    testWidgets(
      'pinning a message shows the pinned bar; the pinned bottom sheet '
      'unpins it and jumps to the original message',
      (tester) async {
        chatRepo.messagesByConversation = {
          'c1': [message(id: 'm1', senderId: 'other', text: 'ปักหมุดฉัน')],
        };
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pinned_bar')), findsNothing);

        // RecordingChatRepository is a stub -- pinMessage() doesn't derive
        // what a later fetchPinnedMessages() returns, so this simulates
        // what the backend will return once queried after the pin
        // actually succeeds.
        chatRepo.pinnedMessagesResult = [
          PinnedMessage(
            messageId: 'm1',
            pinnedAt: DateTime.now(),
            pinnedBy: 'me',
            senderId: 'other',
            text: 'ปักหมุดฉัน',
          ),
        ];

        await tester.longPress(find.text('ปักหมุดฉัน'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ปักหมุดข้อความ'));
        await tester.pumpAndSettle();

        expect(chatRepo.pinMessageCalls, 1);
        expect(chatRepo.lastPinMessageId, 'm1');
        expect(find.byKey(const Key('pinned_bar')), findsOneWidget);

        await tester.tap(find.byKey(const Key('pinned_bar')));
        await tester.pumpAndSettle();

        expect(find.text('ข้อความที่ปักหมุด'), findsOneWidget);
        expect(find.text('เลิกปักหมุด'), findsOneWidget);

        chatRepo.pinnedMessagesResult = const [];
        await tester.tap(find.text('เลิกปักหมุด'));
        await tester.pumpAndSettle();

        expect(chatRepo.unpinMessageCalls, 1);
        expect(chatRepo.lastUnpinMessageId, 'm1');
        expect(find.byKey(const Key('pinned_bar')), findsNothing);
      },
    );

    testWidgets('pinning past the 3-message cap surfaces the RPC error as a '
        'SnackBar, not a crash', (tester) async {
      chatRepo.messagesByConversation = {
        'c1': [message(id: 'm1', senderId: 'other', text: 'ข้อความที่ 4')],
      };
      chatRepo.pinMessageError = Exception(
        'At most 3 pinned messages allowed per conversation',
      );
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('ข้อความที่ 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ปักหมุดข้อความ'));
      await tester.pumpAndSettle();

      expect(
        find.text('ปักหมุดได้สูงสุด 3 ข้อความต่อบทสนทนา ยกเลิกอันเก่าก่อน'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pinned_bar')), findsNothing);
    });

    testWidgets(
      'regression: a realtime UPDATE (e.g. an edit) does not blank out '
      "an existing reply quote's preview",
      (tester) async {
        chatRepo.messagesByConversation = {
          'c1': [
            message(
              id: 'm2',
              senderId: 'other',
              text: 'ข้อความตอบกลับเดิม',
              replyToMessageId: 'm1',
              replyPreviewText: 'ข้อความต้นฉบับ',
            ),
          ],
        };
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.textContaining('ข้อความต้นฉบับ'), findsOneWidget);

        // A raw postgres_changes UPDATE payload carries no reply_to embed
        // -- simulated here by leaving replyPreviewText null, exactly what
        // ChatMessage.fromMap(payload.newRecord) would produce for real.
        chatRepo.emitConversationMessageUpdate(
          message(
            id: 'm2',
            senderId: 'other',
            text: 'ข้อความตอบกลับที่แก้ไขแล้ว',
            replyToMessageId: 'm1',
            editedAt: DateTime.now(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ข้อความตอบกลับที่แก้ไขแล้ว'), findsOneWidget);
        expect(find.textContaining('ข้อความต้นฉบับ'), findsOneWidget);
        expect(find.text('แก้ไขแล้ว'), findsOneWidget);
      },
    );
  });

  group('WYN-139: DM Presence -- Typing + Online/Last Seen', () {
    testWidgets('the other participant typing shows "กำลังพิมพ์..." live', (
      tester,
    ) async {
      chatRepo.messagesByConversation = {
        'c1': [message(id: 'm1', text: 'สวัสดี')],
      };
      final presenceRepository = RecordingPresenceRepository();
      await tester.pumpWidget(
        buildScreen(presenceRepository: presenceRepository),
      );
      await tester.pumpAndSettle();

      expect(find.text('กำลังพิมพ์...'), findsNothing);

      presenceRepository.setOtherTyping('other', typing: true);
      await tester.pump();

      expect(find.text('กำลังพิมพ์...'), findsOneWidget);

      // Safety-net timer (design doc: 3s) auto-clears it even with no
      // explicit `typing: false` event.
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('กำลังพิมพ์...'), findsNothing);
    });

    testWidgets('reciprocal-ok + currently online shows the '
        'green dot + "ออนไลน์", taking priority over last seen', (
      tester,
    ) async {
      chatRepo.messagesByConversation = {
        'c1': [message(id: 'm1', text: 'สวัสดี')],
      };
      final presenceRepository = RecordingPresenceRepository()
        ..partnerPresenceResult = (
          showOnline: true,
          lastSeenAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );
      presenceRepository.setOnline('other', online: true);

      await tester.pumpWidget(
        buildScreen(presenceRepository: presenceRepository),
      );
      await tester.pumpAndSettle();

      expect(find.text('ออนไลน์'), findsOneWidget);
      expect(find.textContaining('ใช้งานล่าสุด'), findsNothing);
    });

    testWidgets('reciprocal-ok + not currently online shows '
        '"ใช้งานล่าสุด ..." from last_seen_at', (tester) async {
      chatRepo.messagesByConversation = {
        'c1': [message(id: 'm1', text: 'สวัสดี')],
      };
      final presenceRepository = RecordingPresenceRepository()
        ..partnerPresenceResult = (
          showOnline: true,
          lastSeenAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );
      // Deliberately not marked online.

      await tester.pumpWidget(
        buildScreen(presenceRepository: presenceRepository),
      );
      await tester.pumpAndSettle();

      expect(find.text('ออนไลน์'), findsNothing);
      expect(find.textContaining('ใช้งานล่าสุด'), findsOneWidget);
    });

    testWidgets('reciprocal check failed (either side has '
        'privacy off) shows no subtitle at all, even if actually online', (
      tester,
    ) async {
      chatRepo.messagesByConversation = {
        'c1': [message(id: 'm1', text: 'สวัสดี')],
      };
      final presenceRepository = RecordingPresenceRepository()
        ..partnerPresenceResult = (showOnline: false, lastSeenAt: null);
      presenceRepository.setOnline('other', online: true);

      await tester.pumpWidget(
        buildScreen(presenceRepository: presenceRepository),
      );
      await tester.pumpAndSettle();

      expect(find.text('ออนไลน์'), findsNothing);
      expect(find.textContaining('ใช้งานล่าสุด'), findsNothing);
    });

    testWidgets(
      'typing my own text broadcasts setTyping(true) once (debounced), '
      'and sending clears it immediately',
      (tester) async {
        chatRepo.messagesByConversation = const {'c1': []};
        chatRepo.sendMessageResult = ChatMessage(
          id: 'm-sent',
          conversationId: 'c1',
          senderId: 'me',
          createdAt: DateTime.now(),
          text: 'ข้อความ',
        );
        final presenceRepository = RecordingPresenceRepository();
        await tester.pumpWidget(
          buildScreen(presenceRepository: presenceRepository),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'ข');
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'ข้อความ');
        await tester.pump();

        // Debounced -- only the first false->true transition calls
        // setTyping, not every keystroke.
        expect(presenceRepository.setTypingCalls, 1);
        expect(presenceRepository.lastSetTyping, isTrue);

        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        expect(presenceRepository.setTypingCalls, 2);
        expect(presenceRepository.lastSetTyping, isFalse);
      },
    );

    testWidgets('typing my own text then going idle for 3s clears it '
        'automatically', (tester) async {
      chatRepo.messagesByConversation = const {'c1': []};
      final presenceRepository = RecordingPresenceRepository();
      await tester.pumpWidget(
        buildScreen(presenceRepository: presenceRepository),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ข้อความ');
      await tester.pump();

      expect(presenceRepository.setTypingCalls, 1);
      expect(presenceRepository.lastSetTyping, isTrue);

      await tester.pump(const Duration(seconds: 4));

      expect(presenceRepository.setTypingCalls, 2);
      expect(presenceRepository.lastSetTyping, isFalse);
    });
  });
}
