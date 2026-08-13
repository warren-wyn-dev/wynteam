import '../../../core/text_utils.dart';

/// A WYN post row, joined with its author's profile and like/comment
/// counts. See supabase/schema.sql (WYN-004 section).
class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.textContent,
    this.imageUrl,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
  });

  final String id;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final String? textContent;
  final String? imageUrl;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  String get authorNameOrUsername => displayNameOrUsername(
        displayName: authorDisplayName,
        username: authorUsername,
      );

  Post copyWith({int? likeCount, int? commentCount, bool? likedByMe}) => Post(
        id: id,
        authorId: authorId,
        authorUsername: authorUsername,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
        textContent: textContent,
        imageUrl: imageUrl,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
      );

  /// A copy with the like toggled -- used for optimistic UI updates before
  /// the server call resolves (and to roll back if it fails).
  Post toggledLike() => copyWith(
        likedByMe: !likedByMe,
        likeCount: likedByMe ? likeCount - 1 : likeCount + 1,
      );

  /// A copy with the comment count bumped -- used right after posting a
  /// new comment, without waiting for a full feed refresh.
  Post withExtraComment() => copyWith(commentCount: commentCount + 1);

  /// [likedByMe] isn't embeddable in the same query (it depends on who's
  /// asking), so PostRepository.fetchFeed fills it in from a separate
  /// lookup against the current user's own likes.
  factory Post.fromMap(Map<String, dynamic> map, {required bool likedByMe}) {
    final author = map['author'] as Map<String, dynamic>?;

    return Post(
      id: map['id'] as String,
      authorId: map['author_id'] as String,
      authorUsername: author?['username'] as String? ?? '',
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      textContent: map['text_content'] as String?,
      imageUrl: map['image_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      likeCount: _embeddedCount(map['likes'] as List<dynamic>?),
      commentCount: _embeddedCount(map['comments'] as List<dynamic>?),
      likedByMe: likedByMe,
    );
  }

  /// PostgREST embedded-resource counts (e.g. `likes(count)`) come back as
  /// a single-element list like `[{'count': 3}]`.
  static int _embeddedCount(List<dynamic>? embedded) {
    if (embedded == null || embedded.isEmpty) return 0;
    return (embedded.first as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}
