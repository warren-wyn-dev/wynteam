/// One row of `public.message_pins` (WYN-138) joined with its own
/// `messages` row -- see `ChatRepository.fetchPinnedMessages()`'s own
/// select for the exact shape. [text]/[imageUrl] are null once
/// [deletedAt] is set, same "content is null once deleted" rule
/// `ChatMessage` follows -- in practice a deleted message never actually
/// reaches this model, since `delete_message()` auto-unpins in the same
/// transaction (see supabase/schema.sql's WYN-138 section), but the
/// fields stay nullable defensively rather than assuming that race can
/// never be observed for a moment.
class PinnedMessage {
  const PinnedMessage({
    required this.messageId,
    required this.pinnedAt,
    required this.pinnedBy,
    required this.senderId,
    this.text,
    this.imageUrl,
    this.deletedAt,
  });

  final String messageId;
  final DateTime pinnedAt;
  final String pinnedBy;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory PinnedMessage.fromMap(Map<String, dynamic> map) => PinnedMessage(
        messageId: map['message_id'] as String,
        pinnedAt: DateTime.parse(map['pinned_at'] as String),
        pinnedBy: map['pinned_by'] as String,
        senderId: map['sender_id'] as String,
        text: map['text'] as String?,
        imageUrl: map['image_url'] as String?,
        deletedAt: map['deleted_at'] == null ? null : DateTime.parse(map['deleted_at'] as String),
      );
}
