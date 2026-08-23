import '../../../core/text_utils.dart';

/// A WYN Drop (image post) row, joined with its author's profile and
/// like/comment counts. See supabase/schema.sql (WYN-005 section).
class Drop {
  const Drop({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.savedByMe,
    this.redropCount = 0,
    this.redroppedByMe = false,
  });

  final String id;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool savedByMe;

  /// WYN-034: total Standard + Quote ReDrops of this Drop. Always 0 for
  /// content that doesn't support ReDrop (there is none today -- every
  /// [Drop] supports it -- default kept only so existing call sites that
  /// don't yet pass it (fixtures, older tests) still compile).
  final int redropCount;

  /// Whether the *current viewer* has Standard ReDropped this Drop
  /// (drives the 🔄 button's filled/outline state -- mirrors
  /// [likedByMe]). Quote ReDrops don't affect this -- a user can Quote
  /// ReDrop freely regardless of their Standard ReDrop state.
  final bool redroppedByMe;

  String get authorNameOrUsername => displayNameOrUsername(
        displayName: authorDisplayName,
        username: authorUsername,
      );

  Drop copyWith({
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
    bool? savedByMe,
    int? redropCount,
    bool? redroppedByMe,
  }) =>
      Drop(
        id: id,
        authorId: authorId,
        authorUsername: authorUsername,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
        imageUrl: imageUrl,
        caption: caption,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
        redropCount: redropCount ?? this.redropCount,
        redroppedByMe: redroppedByMe ?? this.redroppedByMe,
      );

  /// A copy with the like toggled -- used for optimistic UI updates before
  /// the server call resolves (and to roll back if it fails).
  Drop toggledLike() => copyWith(
        likedByMe: !likedByMe,
        likeCount: likedByMe ? likeCount - 1 : likeCount + 1,
      );

  /// A copy with save toggled -- same optimistic-update role as
  /// [toggledLike].
  Drop toggledSave() => copyWith(savedByMe: !savedByMe);

  /// A copy with the Standard ReDrop toggled -- same optimistic-update
  /// role as [toggledLike]. Quote ReDrop never calls this (it doesn't
  /// change [redroppedByMe]; see that field's doc comment) -- it only
  /// bumps [redropCount] separately after a successful post.
  Drop toggledRedrop() => copyWith(
        redroppedByMe: !redroppedByMe,
        redropCount: redroppedByMe ? redropCount - 1 : redropCount + 1,
      );

  /// A copy with the ReDrop count bumped -- used right after posting a
  /// Quote ReDrop, without waiting for a full feed refresh.
  Drop withExtraRedrop() => copyWith(redropCount: redropCount + 1);

  /// A copy with the comment count bumped -- used right after posting a
  /// new comment, without waiting for a full feed refresh.
  Drop withExtraComment() => copyWith(commentCount: commentCount + 1);

  /// A copy with the comment count reduced -- used right after deleting a
  /// comment, without waiting for a full feed refresh.
  Drop withRemovedComment() => copyWith(commentCount: commentCount - 1);

  /// [likedByMe]/[savedByMe] aren't embeddable in the same query (they
  /// depend on who's asking), so DropRepository.fetchFeed fills them in
  /// from separate lookups against the current user's own likes/saves.
  factory Drop.fromMap(
    Map<String, dynamic> map, {
    required bool likedByMe,
    required bool savedByMe,
    bool redroppedByMe = false,
  }) {
    final author = map['author'] as Map<String, dynamic>?;

    return Drop(
      id: map['id'] as String,
      authorId: map['author_id'] as String,
      authorUsername: author?['username'] as String? ?? '',
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      imageUrl: map['image_url'] as String,
      caption: map['caption'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      likeCount: _embeddedCount(map['drop_likes'] as List<dynamic>?),
      commentCount: _embeddedCount(map['drop_comments'] as List<dynamic>?),
      likedByMe: likedByMe,
      savedByMe: savedByMe,
      redropCount: _embeddedCount(map['redrops'] as List<dynamic>?),
      redroppedByMe: redroppedByMe,
    );
  }

  /// PostgREST embedded-resource counts (e.g. `drop_likes(count)`) come
  /// back as a single-element list like `[{'count': 3}]`.
  static int _embeddedCount(List<dynamic>? embedded) {
    if (embedded == null || embedded.isEmpty) return 0;
    return (embedded.first as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}
