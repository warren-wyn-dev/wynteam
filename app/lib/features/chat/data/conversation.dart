/// One row of `chat_inbox` (WYN-031, see supabase/schema.sql) -- the
/// other participant's profile plus the conversation's last message
/// (however it got there) plus this caller's own read-timestamp.
/// `user_a_id`/`user_b_id` on the underlying `conversations` table are
/// unordered by uid, not by "me"/"other" -- the view already resolves
/// that, so this model never needs to.
class Conversation {
  const Conversation({
    required this.id,
    required this.status,
    this.requestedBy,
    required this.createdAt,
    required this.otherUserId,
    required this.otherUsername,
    this.otherDisplayName,
    this.otherAvatarUrl,
    this.lastMessageText,
    this.lastMessageImageUrl,
    this.lastMessageDeletedAt,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.myLastReadAt,
  });

  final String id;
  final String status;

  /// WYN-032: who started this conversation. Null for every
  /// conversation that started 'active' -- only set when [status] is
  /// (or was) `'pending'`. `chat_inbox` only ever returns a pending row
  /// to the requester themselves (see supabase/schema.sql), so within
  /// this model `requestedBy == myUserId` whenever it's non-null.
  final String? requestedBy;

  final DateTime createdAt;
  final String otherUserId;
  final String otherUsername;
  final String? otherDisplayName;
  final String? otherAvatarUrl;

  final String? lastMessageText;
  final String? lastMessageImageUrl;
  final DateTime? lastMessageDeletedAt;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;

  final DateTime? myLastReadAt;

  /// True when the last message is from the other side and arrived
  /// after this caller last read the conversation. A conversation with
  /// no messages yet, or whose last message is the caller's own, is
  /// never unread.
  bool isUnread(String myUserId) {
    final lastMessageAt = this.lastMessageAt;
    if (lastMessageAt == null) return false;
    if (lastMessageSenderId == myUserId) return false;
    final myLastReadAt = this.myLastReadAt;
    if (myLastReadAt == null) return true;
    return lastMessageAt.isAfter(myLastReadAt);
  }

  /// What the Inbox list sorts by -- the last message's time, or the
  /// conversation's own creation time if nothing's been sent yet.
  DateTime get sortKey => lastMessageAt ?? createdAt;

  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
        id: map['conversation_id'] as String,
        status: map['status'] as String,
        requestedBy: map['requested_by'] as String?,
        createdAt: DateTime.parse(map['conversation_created_at'] as String),
        otherUserId: map['other_user_id'] as String,
        otherUsername: map['other_username'] as String,
        otherDisplayName: map['other_display_name'] as String?,
        otherAvatarUrl: map['other_avatar_url'] as String?,
        lastMessageText: map['last_message_text'] as String?,
        lastMessageImageUrl: map['last_message_image_url'] as String?,
        lastMessageDeletedAt: map['last_message_deleted_at'] == null
            ? null
            : DateTime.parse(map['last_message_deleted_at'] as String),
        lastMessageAt: map['last_message_at'] == null
            ? null
            : DateTime.parse(map['last_message_at'] as String),
        lastMessageSenderId: map['last_message_sender_id'] as String?,
        myLastReadAt: map['my_last_read_at'] == null
            ? null
            : DateTime.parse(map['my_last_read_at'] as String),
      );
}
