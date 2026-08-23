import 'shared_content_type.dart';

/// One row of `public.messages` (WYN-031), as seen by a conversation
/// participant. A soft-deleted message ([deletedAt] non-null) always
/// has null [text]/[imageUrl]/[sharedContentType]/[sharedContentId] --
/// see `delete_message()` in supabase/schema.sql, which nulls the
/// content directly rather than setting a flag, so there's no way to
/// accidentally read the old content back through this model.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.createdAt,
    this.text,
    this.imageUrl,
    this.replyToMessageId,
    this.deletedAt,
    this.replyPreviewText,
    this.replyPreviewImageUrl,
    this.replyPreviewDeletedAt,
    this.sharedContentType,
    this.sharedContentId,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final DateTime createdAt;

  final String? text;
  final String? imageUrl;
  final String? replyToMessageId;
  final DateTime? deletedAt;

  /// WYN-033: set only for a "shared" message (Drop/Profile/Club).
  /// Deliberately not joined/denormalized -- see the class doc comment
  /// on `ChatRepository` for why the referenced content is resolved
  /// through the normal Drop/Club/Profile repositories instead.
  final SharedContentType? sharedContentType;
  final String? sharedContentId;

  bool get isDeleted => deletedAt != null;

  /// The replied-to message's own content, embedded at fetch time so
  /// the reply quote can render without a second round-trip. Null when
  /// this message isn't a reply. Follows the same "content is null
  /// once deleted" rule as the top-level message.
  final String? replyPreviewText;
  final String? replyPreviewImageUrl;
  final DateTime? replyPreviewDeletedAt;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final reply = map['reply_to'] as Map<String, dynamic>?;
    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      text: map['text'] as String?,
      imageUrl: map['image_url'] as String?,
      replyToMessageId: map['reply_to_message_id'] as String?,
      deletedAt: map['deleted_at'] == null ? null : DateTime.parse(map['deleted_at'] as String),
      replyPreviewText: reply?['text'] as String?,
      replyPreviewImageUrl: reply?['image_url'] as String?,
      replyPreviewDeletedAt: reply?['deleted_at'] == null
          ? null
          : DateTime.parse(reply!['deleted_at'] as String),
      sharedContentType: map['shared_content_type'] == null
          ? null
          : sharedContentTypeFromWireValue(map['shared_content_type'] as String),
      sharedContentId: map['shared_content_id'] as String?,
    );
  }
}
