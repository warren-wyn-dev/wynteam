import '../../../core/text_utils.dart';

/// A WYN Drop comment row, joined with its author's profile and like
/// count. See supabase/schema.sql (WYN-005 section).
class DropComment {
  const DropComment({
    required this.id,
    required this.dropId,
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
  final String dropId;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final String textContent;
  final DateTime createdAt;
  final int likeCount;
  final bool likedByMe;

  /// Null for a top-level comment; set to that comment's id for a reply
  /// -- WYN-022. Capped at one level (a reply's own parent is always a
  /// top-level comment, never another reply) by a DB trigger, not
  /// re-checked client-side.
  final String? parentCommentId;

  String get authorNameOrUsername => displayNameOrUsername(
        displayName: authorDisplayName,
        username: authorUsername,
      );

  DropComment copyWith({int? likeCount, bool? likedByMe}) => DropComment(
        id: id,
        dropId: dropId,
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
  DropComment toggledLike() => copyWith(
        likedByMe: !likedByMe,
        likeCount: likedByMe ? likeCount - 1 : likeCount + 1,
      );

  /// [likedByMe] isn't embeddable in the same query (it depends on who's
  /// asking), so DropRepository.fetchComments fills it in from a separate
  /// lookup against the current user's own comment likes.
  factory DropComment.fromMap(
    Map<String, dynamic> map, {
    required bool likedByMe,
  }) {
    final author = map['author'] as Map<String, dynamic>?;

    return DropComment(
      id: map['id'] as String,
      dropId: map['drop_id'] as String,
      authorId: map['author_id'] as String,
      authorUsername: author?['username'] as String? ?? '',
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      textContent: map['text_content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      likeCount: _embeddedCount(map['drop_comment_likes'] as List<dynamic>?),
      likedByMe: likedByMe,
      parentCommentId: map['parent_comment_id'] as String?,
    );
  }

  /// PostgREST embedded-resource counts (e.g. `drop_comment_likes(count)`)
  /// come back as a single-element list like `[{'count': 3}]`.
  static int _embeddedCount(List<dynamic>? embedded) {
    if (embedded == null || embedded.isEmpty) return 0;
    return (embedded.first as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}

/// WYN-064: one row of Profile's "Replies" tab -- a [comment] plus just
/// enough of its parent Drop ([dropId]/[dropCaption]/[dropImageUrl]/
/// [dropAuthorUsername]/[dropAuthorDisplayName]) to show it in context
/// and link to it. See [DropRepository.fetchRepliesByAuthor].
class ProfileReply {
  const ProfileReply({
    required this.comment,
    required this.dropId,
    this.dropCaption,
    this.dropImageUrl,
    required this.dropAuthorUsername,
    this.dropAuthorDisplayName,
  });

  final DropComment comment;
  final String dropId;
  final String? dropCaption;
  final String? dropImageUrl;
  final String dropAuthorUsername;
  final String? dropAuthorDisplayName;

  String get dropAuthorNameOrUsername => displayNameOrUsername(
        displayName: dropAuthorDisplayName,
        username: dropAuthorUsername,
      );
}
