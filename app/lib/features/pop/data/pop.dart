import '../../../core/text_utils.dart';

/// A WYN Pop (short vertical video) row, joined with its author's profile
/// and like/comment counts. See supabase/schema.sql (WYN-006 section).
class Pop {
  const Pop({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    required this.videoUrl,
    this.thumbnailUrl,
    this.caption,
    required this.durationSeconds,
    required this.viewCount,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.savedByMe,
  });

  final String id;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? caption;
  final int durationSeconds;
  final int viewCount;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool savedByMe;

  String get authorNameOrUsername => displayNameOrUsername(
        displayName: authorDisplayName,
        username: authorUsername,
      );

  Pop copyWith({
    int? viewCount,
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
    bool? savedByMe,
  }) =>
      Pop(
        id: id,
        authorId: authorId,
        authorUsername: authorUsername,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        caption: caption,
        durationSeconds: durationSeconds,
        viewCount: viewCount ?? this.viewCount,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
      );

  /// A copy with the like toggled -- used for optimistic UI updates before
  /// the server call resolves (and to roll back if it fails).
  Pop toggledLike() => copyWith(
        likedByMe: !likedByMe,
        likeCount: likedByMe ? likeCount - 1 : likeCount + 1,
      );

  /// A copy with save toggled -- same optimistic-update role as
  /// [toggledLike].
  Pop toggledSave() => copyWith(savedByMe: !savedByMe);

  /// A copy with the comment count bumped -- used right after posting a
  /// new comment, without waiting for a full feed refresh.
  Pop withExtraComment() => copyWith(commentCount: commentCount + 1);

  /// A copy with the comment count reduced -- used right after deleting a
  /// comment, without waiting for a full feed refresh.
  Pop withRemovedComment() => copyWith(commentCount: commentCount - 1);

  /// A copy with the view count bumped -- used right after a view is
  /// recorded, without waiting for a full feed refresh.
  Pop withExtraView() => copyWith(viewCount: viewCount + 1);

  /// [likedByMe]/[savedByMe] aren't embeddable in the same query (they
  /// depend on who's asking), so PopRepository.fetchFeed fills them in
  /// from separate lookups against the current user's own likes/saves.
  factory Pop.fromMap(
    Map<String, dynamic> map, {
    required bool likedByMe,
    required bool savedByMe,
  }) {
    final author = map['author'] as Map<String, dynamic>?;

    return Pop(
      id: map['id'] as String,
      authorId: map['author_id'] as String,
      authorUsername: author?['username'] as String? ?? '',
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      videoUrl: map['video_url'] as String,
      thumbnailUrl: map['thumbnail_url'] as String?,
      caption: map['caption'] as String?,
      durationSeconds: map['duration_seconds'] as int,
      viewCount: (map['view_count'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      likeCount: _embeddedCount(map['pop_likes'] as List<dynamic>?),
      commentCount: _embeddedCount(map['pop_comments'] as List<dynamic>?),
      likedByMe: likedByMe,
      savedByMe: savedByMe,
    );
  }

  /// PostgREST embedded-resource counts (e.g. `pop_likes(count)`) come
  /// back as a single-element list like `[{'count': 3}]`.
  static int _embeddedCount(List<dynamic>? embedded) {
    if (embedded == null || embedded.isEmpty) return 0;
    return (embedded.first as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}
