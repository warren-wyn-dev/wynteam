import '../../../core/text_utils.dart';

/// A WYN Club post comment row, joined with its author's profile. See
/// supabase/schema.sql (WYN-014 section). Mirrors DropComment except
/// comments on a Club post have no per-comment like of their own -- not
/// specified by Product/Design for WYN-014, so left out rather than
/// speculatively added.
class ClubPostComment {
  const ClubPostComment({
    required this.id,
    required this.clubPostId,
    required this.authorId,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    required this.textContent,
    required this.createdAt,
    this.parentCommentId,
  });

  final String id;
  final String clubPostId;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final String textContent;
  final DateTime createdAt;

  /// See DropComment.parentCommentId -- same one-level reply design
  /// (WYN-022).
  final String? parentCommentId;

  String get authorNameOrUsername => displayNameOrUsername(
        displayName: authorDisplayName,
        username: authorUsername,
      );

  factory ClubPostComment.fromMap(Map<String, dynamic> map) {
    final author = map['author'] as Map<String, dynamic>?;

    return ClubPostComment(
      id: map['id'] as String,
      clubPostId: map['club_post_id'] as String,
      authorId: map['author_id'] as String,
      authorUsername: author?['username'] as String? ?? '',
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      textContent: map['text_content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      parentCommentId: map['parent_comment_id'] as String?,
    );
  }
}
