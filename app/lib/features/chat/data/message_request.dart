/// One row of `message_requests` (WYN-032, see supabase/schema.sql) --
/// a pending conversation someone else started that this caller (the
/// recipient) hasn't decided on yet. The view only ever returns rows
/// where the caller is the recipient, never the requester -- see that
/// view's own WHERE clause.
class MessageRequest {
  const MessageRequest({
    required this.conversationId,
    required this.conversationCreatedAt,
    required this.otherUserId,
    required this.otherUsername,
    this.otherDisplayName,
    this.otherAvatarUrl,
    this.lastMessageText,
    this.lastMessageImageUrl,
    this.lastMessageAt,
  });

  final String conversationId;
  final DateTime conversationCreatedAt;
  final String otherUserId;
  final String otherUsername;
  final String? otherDisplayName;
  final String? otherAvatarUrl;

  final String? lastMessageText;
  final String? lastMessageImageUrl;
  final DateTime? lastMessageAt;

  factory MessageRequest.fromMap(Map<String, dynamic> map) => MessageRequest(
        conversationId: map['conversation_id'] as String,
        conversationCreatedAt: DateTime.parse(map['conversation_created_at'] as String),
        otherUserId: map['other_user_id'] as String,
        otherUsername: map['other_username'] as String,
        otherDisplayName: map['other_display_name'] as String?,
        otherAvatarUrl: map['other_avatar_url'] as String?,
        lastMessageText: map['last_message_text'] as String?,
        lastMessageImageUrl: map['last_message_image_url'] as String?,
        lastMessageAt: map['last_message_at'] == null
            ? null
            : DateTime.parse(map['last_message_at'] as String),
      );
}
