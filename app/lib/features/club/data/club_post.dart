import '../../../core/text_utils.dart';

/// A WYN Club post row, joined with its author's profile and
/// like/comment counts. See supabase/schema.sql (WYN-014 section).
/// Mirrors Drop (WYN-005) with the addition of [imageUrls] (multiple
/// images -- Drop only ever has one), [linkUrl], and [pinned].
class ClubPost {
  const ClubPost({
    required this.id,
    required this.clubId,
    required this.authorId,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.content,
    this.imageUrls,
    this.linkUrl,
    required this.pinned,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.savedByMe,
  });

  final String id;
  final String clubId;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final String? content;
  final List<String>? imageUrls;
  final String? linkUrl;
  final bool pinned;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool savedByMe;

  String get authorNameOrUsername => displayNameOrUsername(
        displayName: authorDisplayName,
        username: authorUsername,
      );

  ClubPost copyWith({
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
    bool? savedByMe,
    bool? pinned,
  }) =>
      ClubPost(
        id: id,
        clubId: clubId,
        authorId: authorId,
        authorUsername: authorUsername,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
        content: content,
        imageUrls: imageUrls,
        linkUrl: linkUrl,
        pinned: pinned ?? this.pinned,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
      );

  /// A copy with the like toggled -- used for optimistic UI updates before
  /// the server call resolves (and to roll back if it fails).
  ClubPost toggledLike() => copyWith(
        likedByMe: !likedByMe,
        likeCount: likedByMe ? likeCount - 1 : likeCount + 1,
      );

  /// A copy with save toggled -- same optimistic-update role as
  /// [toggledLike]. Bookmarking a Club post reuses the `saves` table
  /// (content_type = 'club_post') per the Product spec's Risks section.
  ClubPost toggledSave() => copyWith(savedByMe: !savedByMe);

  /// A copy with the comment count bumped -- used right after posting a
  /// new comment, without waiting for a full list refresh.
  ClubPost withExtraComment() => copyWith(commentCount: commentCount + 1);

  /// A copy with the comment count reduced -- used right after deleting a
  /// comment, without waiting for a full list refresh.
  ClubPost withRemovedComment() => copyWith(commentCount: commentCount - 1);

  /// A copy with pin/unpin toggled -- used for optimistic UI updates by
  /// club staff (see ClubMemberRolePermissions.canModeratePosts).
  ClubPost toggledPin() => copyWith(pinned: !pinned);

  /// [likedByMe]/[savedByMe] aren't embeddable in the same query (they
  /// depend on who's asking), so ClubPostRepository.fetchPosts fills them
  /// in from separate lookups against the current user's own likes/saves.
  factory ClubPost.fromMap(
    Map<String, dynamic> map, {
    required bool likedByMe,
    required bool savedByMe,
  }) {
    final author = map['author'] as Map<String, dynamic>?;
    final rawImageUrls = map['image_urls'] as List<dynamic>?;

    return ClubPost(
      id: map['id'] as String,
      clubId: map['club_id'] as String,
      authorId: map['author_id'] as String,
      authorUsername: author?['username'] as String? ?? '',
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      content: map['content'] as String?,
      imageUrls: rawImageUrls?.map((e) => e as String).toList(),
      linkUrl: map['link_url'] as String?,
      pinned: map['pinned'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
      likeCount: _embeddedCount(map['club_post_likes'] as List<dynamic>?),
      commentCount:
          _embeddedCount(map['club_post_comments'] as List<dynamic>?),
      likedByMe: likedByMe,
      savedByMe: savedByMe,
    );
  }

  /// PostgREST embedded-resource counts (e.g. `club_post_likes(count)`)
  /// come back as a single-element list like `[{'count': 3}]`.
  static int _embeddedCount(List<dynamic>? embedded) {
    if (embedded == null || embedded.isEmpty) return 0;
    return (embedded.first as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}
