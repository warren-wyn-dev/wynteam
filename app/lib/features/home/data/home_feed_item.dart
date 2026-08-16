import '../../../core/text_utils.dart';
import '../../drop/data/drop.dart';
import '../../pop/data/pop.dart';

enum HomeContentType { drop, pop }

/// One row of the unified Home feed (`public.home_feed` view -- see
/// supabase/schema.sql, WYN-007 section), which UNIONs `drops` and `pops`
/// so they can be paginated together in one chronological order. Carries
/// enough fields to render either card type directly, and to convert
/// into the full [Drop]/[Pop] object each detail/clip screen already
/// expects -- so tapping into a card doesn't need a second fetch.
class HomeFeedItem {
  const HomeFeedItem({
    required this.id,
    required this.contentType,
    required this.authorId,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    required this.createdAt,
    this.caption,
    this.imageUrl,
    this.videoUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.savedByMe,
  });

  final String id;
  final HomeContentType contentType;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final String? caption;

  /// Set only when [contentType] is [HomeContentType.drop].
  final String? imageUrl;

  /// Set only when [contentType] is [HomeContentType.pop].
  final String? videoUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final int? viewCount;

  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool savedByMe;

  String get authorNameOrUsername => displayNameOrUsername(
        displayName: authorDisplayName,
        username: authorUsername,
      );

  /// Converts to the full [Drop] object DropDetailScreen expects. Only
  /// valid when [contentType] is [HomeContentType.drop].
  Drop toDrop() => Drop(
        id: id,
        authorId: authorId,
        authorUsername: authorUsername,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
        imageUrl: imageUrl!,
        caption: caption,
        createdAt: createdAt,
        likeCount: likeCount,
        commentCount: commentCount,
        likedByMe: likedByMe,
        savedByMe: savedByMe,
      );

  /// Converts to the full [Pop] object PopClipView expects. Only valid
  /// when [contentType] is [HomeContentType.pop].
  Pop toPop() => Pop(
        id: id,
        authorId: authorId,
        authorUsername: authorUsername,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
        videoUrl: videoUrl!,
        thumbnailUrl: thumbnailUrl,
        caption: caption,
        durationSeconds: durationSeconds!,
        viewCount: viewCount!,
        createdAt: createdAt,
        likeCount: likeCount,
        commentCount: commentCount,
        likedByMe: likedByMe,
        savedByMe: savedByMe,
      );

  /// Converts a [Drop] into a drop-typed [HomeFeedItem] -- the reverse of
  /// [toDrop] -- so widgets built for the unified Home feed (HomeDropCard)
  /// can be reused wherever a plain Drop list is fetched instead (WYN-019's
  /// Drop tab). See .wyn/docs/design/wyn-019-drop-feed-tabs.md.
  factory HomeFeedItem.fromDrop(Drop drop) => HomeFeedItem(
        id: drop.id,
        contentType: HomeContentType.drop,
        authorId: drop.authorId,
        authorUsername: drop.authorUsername,
        authorDisplayName: drop.authorDisplayName,
        authorAvatarUrl: drop.authorAvatarUrl,
        createdAt: drop.createdAt,
        caption: drop.caption,
        imageUrl: drop.imageUrl,
        likeCount: drop.likeCount,
        commentCount: drop.commentCount,
        likedByMe: drop.likedByMe,
        savedByMe: drop.savedByMe,
      );

  factory HomeFeedItem.fromMap(
    Map<String, dynamic> map, {
    required bool likedByMe,
    required bool savedByMe,
  }) {
    final contentType = map['content_type'] as String;
    return HomeFeedItem(
      id: map['id'] as String,
      contentType:
          contentType == 'drop' ? HomeContentType.drop : HomeContentType.pop,
      authorId: map['author_id'] as String,
      authorUsername: map['author_username'] as String? ?? '',
      authorDisplayName: map['author_display_name'] as String?,
      authorAvatarUrl: map['author_avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      caption: map['caption'] as String?,
      imageUrl: map['image_url'] as String?,
      videoUrl: map['video_url'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      durationSeconds: map['duration_seconds'] as int?,
      viewCount: (map['view_count'] as num?)?.toInt(),
      likeCount: (map['like_count'] as num).toInt(),
      commentCount: (map['comment_count'] as num).toInt(),
      likedByMe: likedByMe,
      savedByMe: savedByMe,
    );
  }
}
