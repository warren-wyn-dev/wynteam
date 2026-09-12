import '../../../core/text_utils.dart';

/// One row of `public.club_channel_messages` (WYN-128), as seen by an
/// approved member of the channel's Club. Mirrors ChatMessage (WYN-031)
/// wherever the shape matches, minus what a group room doesn't need:
/// no View-Once, no shared-content card (not specified for this round --
/// see the Product spec's Requirements, which only asks for text/image/
/// reply). Unlike ChatMessage, a deleted row is gone outright (hard
/// DELETE, see supabase/schema.sql) -- there is no `deletedAt` state to
/// carry.
class ClubChannelMessage {
  const ClubChannelMessage({
    required this.id,
    required this.channelId,
    required this.authorId,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    required this.createdAt,
    this.content,
    this.imageUrl,
    this.replyToMessageId,
    this.replyPreviewContent,
    this.replyPreviewImageUrl,
  });

  final String id;
  final String channelId;
  final String authorId;

  /// WYN-128's own addition vs. ChatMessage -- a group room needs the
  /// sender's name/avatar on every incoming bubble (Design's Components:
  /// "ชื่อผู้ส่งกำกับเหนือ bubble ที่ไม่ใช่ตัวเอง"), unlike a 1:1 thread
  /// where the header already names the one other participant.
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  final DateTime createdAt;
  final String? content;
  final String? imageUrl;
  final String? replyToMessageId;

  final String? replyPreviewContent;
  final String? replyPreviewImageUrl;

  /// WYN-128 fast-follow: used by the "รายงานข้อความ" report label --
  /// mirrors ClubPost.authorNameOrUsername exactly.
  String get authorNameOrUsername => displayNameOrUsername(
        displayName: authorDisplayName,
        username: authorUsername,
      );

  factory ClubChannelMessage.fromMap(Map<String, dynamic> map) {
    final author = map['author'] as Map<String, dynamic>?;
    // Same defensive object-or-list-or-null handling ChatMessage.fromMap
    // needs for its own self-referencing `reply_to` embed -- see that
    // factory's doc comment for why PostgREST's to-one/to-many inference
    // can't be trusted blindly for a self-join.
    final rawReply = map['reply_to'];
    final reply = rawReply is Map<String, dynamic>
        ? rawReply
        : (rawReply is List && rawReply.isNotEmpty ? rawReply.first as Map<String, dynamic> : null);

    return ClubChannelMessage(
      id: map['id'] as String,
      channelId: map['channel_id'] as String,
      authorId: map['author_id'] as String,
      authorUsername: author?['username'] as String? ?? '',
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      content: map['content'] as String?,
      imageUrl: map['image_url'] as String?,
      replyToMessageId: map['reply_to_message_id'] as String?,
      replyPreviewContent: reply?['content'] as String?,
      replyPreviewImageUrl: reply?['image_url'] as String?,
    );
  }
}
