import '../../../core/text_utils.dart';

/// A WYN Pop comment row, joined with its author's profile and like
/// count. See supabase/schema.sql (WYN-006 section).
class PopComment {
  const PopComment({
    required this.id,
    required this.popId,
    required this.authorId,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    required this.textContent,
    required this.createdAt,
    required this.likeCount,
    required this.likedByMe,
    this.parentCommentId,
  });

  final String id;
  final String popId;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final String textContent;
  final DateTime createdAt;
  final int likeCount;
  final bool likedByMe;

  /// See DropComment.parentCommentId -- same one-level reply design.
  final String? parentCommentId;

  String get authorNameOrUsername => displayNameOrUsername(
        displayName: authorDisplayName,
        username: authorUsername,
      );

  PopComment copyWith({int? likeCount, bool? likedByMe}) => PopComment(
        id: id,
        popId: popId,
        authorId: authorId,
        authorUsername: authorUsername,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
        textContent: textContent,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        parentCommentId: parentCommentId,
      );

  /// A copy with the like toggled -- used for optimistic UI updates before
  /// the server call resolves (and to roll back if it fails).
  PopComment toggledLike() => copyWith(
        likedByMe: !likedByMe,
        likeCount: likedByMe ? likeCount - 1 : likeCount + 1,
      );

  /// [likedByMe] isn't embeddable in the same query (it depends on who's
  /// asking), so PopRepository.fetchComments fills it in from a separate
  /// lookup against the current user's own comment likes.
  factory PopComment.fromMap(
    Map<String, dynamic> map, {
    required bool likedByMe,
  }) {
    final author = map['author'] as Map<String, dynamic>?;

    return PopComment(
      id: map['id'] as String,
      popId: map['pop_id'] as String,
      authorId: map['author_id'] as String,
      authorUsername: author?['username'] as String? ?? '',
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      textContent: map['text_content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      likeCount: _embeddedCount(map['pop_comment_likes'] as List<dynamic>?),
      likedByMe: likedByMe,
      parentCommentId: map['parent_comment_id'] as String?,
    );
  }

  /// PostgREST embedded-resource counts (e.g. `pop_comment_likes(count)`)
  /// come back as a single-element list like `[{'count': 3}]`.
  static int _embeddedCount(List<dynamic>? embedded) {
    if (embedded == null || embedded.isEmpty) return 0;
    return (embedded.first as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}
