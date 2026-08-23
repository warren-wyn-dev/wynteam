import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/chat/data/chat_message.dart';
import 'package:wyn/features/chat/data/conversation.dart';

void main() {
  group('Conversation.fromMap', () {
    Map<String, dynamic> baseMap({
      String? lastMessageAt,
      String? lastMessageSenderId,
      String? myLastReadAt,
      String? lastMessageDeletedAt,
    }) =>
        {
          'conversation_id': 'c1',
          'status': 'active',
          'conversation_created_at': '2026-08-01T00:00:00Z',
          'other_user_id': 'u2',
          'other_username': 'namfah',
          'other_display_name': 'น้ำฝน',
          'other_avatar_url': 'https://example.com/avatar.jpg',
          'last_message_text': 'สวัสดี',
          'last_message_image_url': null,
          'last_message_deleted_at': lastMessageDeletedAt,
          'last_message_at': lastMessageAt,
          'last_message_sender_id': lastMessageSenderId,
          'my_last_read_at': myLastReadAt,
        };

    test('parses every field', () {
      final conversation = Conversation.fromMap(baseMap(
        lastMessageAt: '2026-08-22T10:00:00Z',
        lastMessageSenderId: 'u2',
        myLastReadAt: '2026-08-22T09:00:00Z',
      ));

      expect(conversation.id, 'c1');
      expect(conversation.otherUsername, 'namfah');
      expect(conversation.otherDisplayName, 'น้ำฝน');
      expect(conversation.lastMessageText, 'สวัสดี');
      expect(conversation.lastMessageAt, DateTime.parse('2026-08-22T10:00:00Z'));
      expect(conversation.myLastReadAt, DateTime.parse('2026-08-22T09:00:00Z'));
    });

    test('sortKey falls back to conversation createdAt when there is no message yet', () {
      final conversation = Conversation.fromMap(baseMap());
      expect(conversation.sortKey, DateTime.parse('2026-08-01T00:00:00Z'));
    });

    test('sortKey uses lastMessageAt once a message exists', () {
      final conversation = Conversation.fromMap(baseMap(lastMessageAt: '2026-08-22T10:00:00Z'));
      expect(conversation.sortKey, DateTime.parse('2026-08-22T10:00:00Z'));
    });

    group('isUnread', () {
      test('false when there is no message yet', () {
        final conversation = Conversation.fromMap(baseMap());
        expect(conversation.isUnread('me'), isFalse);
      });

      test('false when the last message is my own', () {
        final conversation = Conversation.fromMap(baseMap(
          lastMessageAt: '2026-08-22T10:00:00Z',
          lastMessageSenderId: 'me',
          myLastReadAt: '2026-08-22T09:00:00Z',
        ));
        expect(conversation.isUnread('me'), isFalse);
      });

      test('true when the other side sent after my last read', () {
        final conversation = Conversation.fromMap(baseMap(
          lastMessageAt: '2026-08-22T10:00:00Z',
          lastMessageSenderId: 'u2',
          myLastReadAt: '2026-08-22T09:00:00Z',
        ));
        expect(conversation.isUnread('me'), isTrue);
      });

      test('false when the other side sent before my last read', () {
        final conversation = Conversation.fromMap(baseMap(
          lastMessageAt: '2026-08-22T08:00:00Z',
          lastMessageSenderId: 'u2',
          myLastReadAt: '2026-08-22T09:00:00Z',
        ));
        expect(conversation.isUnread('me'), isFalse);
      });

      test('true when never read at all (myLastReadAt null) but a message exists', () {
        final conversation = Conversation.fromMap(baseMap(
          lastMessageAt: '2026-08-22T10:00:00Z',
          lastMessageSenderId: 'u2',
        ));
        expect(conversation.isUnread('me'), isTrue);
      });
    });
  });

  group('ChatMessage.fromMap', () {
    test('parses a plain message with no reply', () {
      final message = ChatMessage.fromMap({
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'text': 'hello',
        'image_url': null,
        'reply_to_message_id': null,
        'deleted_at': null,
        'created_at': '2026-08-22T10:00:00Z',
      });

      expect(message.id, 'm1');
      expect(message.text, 'hello');
      expect(message.isDeleted, isFalse);
      expect(message.replyPreviewText, isNull);
    });

    test('a soft-deleted message has null text/image and a non-null deletedAt', () {
      final message = ChatMessage.fromMap({
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'text': null,
        'image_url': null,
        'reply_to_message_id': null,
        'deleted_at': '2026-08-22T10:05:00Z',
        'created_at': '2026-08-22T10:00:00Z',
      });

      expect(message.isDeleted, isTrue);
      expect(message.text, isNull);
      expect(message.imageUrl, isNull);
    });

    test('parses the reply_to embed when this message is a reply', () {
      final message = ChatMessage.fromMap({
        'id': 'm2',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'text': 'ตอบกลับ',
        'image_url': null,
        'reply_to_message_id': 'm1',
        'deleted_at': null,
        'created_at': '2026-08-22T10:01:00Z',
        'reply_to': {
          'text': 'ข้อความต้นทาง',
          'image_url': null,
          'deleted_at': null,
        },
      });

      expect(message.replyToMessageId, 'm1');
      expect(message.replyPreviewText, 'ข้อความต้นทาง');
      expect(message.replyPreviewDeletedAt, isNull);
    });

    test('a reply to a since-deleted message has a null preview text but a non-null preview deletedAt', () {
      final message = ChatMessage.fromMap({
        'id': 'm2',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'text': 'ตอบกลับ',
        'image_url': null,
        'reply_to_message_id': 'm1',
        'deleted_at': null,
        'created_at': '2026-08-22T10:01:00Z',
        'reply_to': {
          'text': null,
          'image_url': null,
          'deleted_at': '2026-08-22T10:00:30Z',
        },
      });

      expect(message.replyPreviewText, isNull);
      expect(message.replyPreviewDeletedAt, isNotNull);
    });

    test('missing reply_to key entirely (e.g. a raw realtime payload) does not crash', () {
      final message = ChatMessage.fromMap({
        'id': 'm2',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'text': 'ตอบกลับ',
        'image_url': null,
        'reply_to_message_id': 'm1',
        'deleted_at': null,
        'created_at': '2026-08-22T10:01:00Z',
      });

      expect(message.replyPreviewText, isNull);
      expect(message.replyPreviewDeletedAt, isNull);
    });
  });
}
