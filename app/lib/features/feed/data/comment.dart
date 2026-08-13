import '../../../core/text_utils.dart';

/// A WYN comment row, joined with its author's profile. See
/// supabase/schema.sql (WYN-004 section).
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    required this.textContent,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final String textContent;
  final DateTime createdAt;

  String get authorNameOrUsername => displayNameOrUsername(
        displayName: authorDisplayName,
        username: authorUsername,
      );

  factory Comment.fromMap(Map<String, dynamic> map) {
    final author = map['author'] as Map<String, dynamic>?;

    return Comment(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      authorId: map['author_id'] as String,
      authorUsername: author?['username'] as String? ?? '',
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      textContent: map['text_content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
