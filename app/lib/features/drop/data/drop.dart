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
    this.imageUrl,
    this.caption,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.savedByMe,
    this.redropCount = 0,
    this.redroppedByMe = false,
    this.pollId,
    this.pollOptions,
    this.pollExpiresAt,
    this.pollMyVoteIndex,
    this.pollTotalVotes,
    this.pollOptionCounts,
  });

  final String id;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  /// Null when this Drop is a Poll ([pollId] set) instead -- WYN-035:
  /// a Drop carries either an image or a Poll, never both this round.
  final String? imageUrl;
  final String? caption;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool savedByMe;

  /// WYN-035: set only when this Drop is a Poll. [pollOptions] is
  /// always 2-4 items when [pollId] is set.
  final String? pollId;
  final List<String>? pollOptions;
  final DateTime? pollExpiresAt;

  /// Index into [pollOptions] the *current viewer* voted for, or null
  /// if they haven't (or can't -- they're the poll's own author).
  final int? pollMyVoteIndex;

  /// Null exactly when results aren't visible to the current viewer
  /// yet (hasn't voted, isn't the author, poll still open) -- see
  /// `get_poll_results()` in supabase/schema.sql. Non-null always
  /// means [pollOptionCounts] is too.
  final int? pollTotalVotes;

  /// Vote count per option, same order/length as [pollOptions]. Null
  /// under the exact same condition as [pollTotalVotes].
  final List<int>? pollOptionCounts;

  bool get isPoll => pollId != null;

  bool get pollResultsVisible => pollTotalVotes != null;

  bool get pollIsClosed =>
      pollExpiresAt != null && !DateTime.now().toUtc().isBefore(pollExpiresAt!);

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
    int? pollMyVoteIndex,
    int? pollTotalVotes,
    List<int>? pollOptionCounts,
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
        pollId: pollId,
        pollOptions: pollOptions,
        pollExpiresAt: pollExpiresAt,
        pollMyVoteIndex: pollMyVoteIndex ?? this.pollMyVoteIndex,
        pollTotalVotes: pollTotalVotes ?? this.pollTotalVotes,
        pollOptionCounts: pollOptionCounts ?? this.pollOptionCounts,
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

  /// A copy with [optionIndex] recorded as the viewer's vote --
  /// optimistic-update role, same shape as [toggledLike]. Handles
  /// changing an existing vote too: the old option's count (if any) is
  /// decremented and the new one incremented, [pollTotalVotes] only
  /// grows on a first-time vote. Voting always makes results visible
  /// (a non-empty [pollOptionCounts] is seeded with zeros if this is
  /// the viewer's first look at a poll they hadn't voted on yet).
  Drop votedPoll(int optionIndex) {
    final previousVote = pollMyVoteIndex;
    final counts = List<int>.from(
      pollOptionCounts ?? List.filled(pollOptions?.length ?? 0, 0),
    );
    if (previousVote != null && previousVote < counts.length) {
      counts[previousVote] -= 1;
    }
    if (optionIndex < counts.length) counts[optionIndex] += 1;

    return copyWith(
      pollMyVoteIndex: optionIndex,
      pollTotalVotes: previousVote == null ? (pollTotalVotes ?? 0) + 1 : pollTotalVotes ?? 1,
      pollOptionCounts: counts,
    );
  }

  /// [likedByMe]/[savedByMe] aren't embeddable in the same query (they
  /// depend on who's asking), so DropRepository.fetchFeed fills them in
  /// from separate lookups against the current user's own likes/saves.
  /// Same for the WYN-035 poll per-viewer fields ([pollMyVoteIndex]/
  /// [pollTotalVotes]/[pollOptionCounts]) -- [pollId]/[pollOptions]/
  /// [pollExpiresAt] come straight off the row's `drop_polls` embed
  /// (a 1:1 relation, so PostgREST returns it as a single object, not
  /// a list, unlike the count embeds above).
  factory Drop.fromMap(
    Map<String, dynamic> map, {
    required bool likedByMe,
    required bool savedByMe,
    bool redroppedByMe = false,
    int? pollMyVoteIndex,
    int? pollTotalVotes,
    List<int>? pollOptionCounts,
  }) {
    final author = map['author'] as Map<String, dynamic>?;
    final poll = _embeddedPoll(map['drop_polls']);

    return Drop(
      id: map['id'] as String,
      authorId: map['author_id'] as String,
      authorUsername: author?['username'] as String? ?? '',
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      imageUrl: map['image_url'] as String?,
      caption: map['caption'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      likeCount: _embeddedCount(map['drop_likes'] as List<dynamic>?),
      commentCount: _embeddedCount(map['drop_comments'] as List<dynamic>?),
      likedByMe: likedByMe,
      savedByMe: savedByMe,
      redropCount: _embeddedCount(map['redrops'] as List<dynamic>?),
      redroppedByMe: redroppedByMe,
      pollId: poll?['id'] as String?,
      pollOptions: (poll?['options'] as List<dynamic>?)?.cast<String>(),
      pollExpiresAt: poll?['expires_at'] != null
          ? DateTime.parse(poll!['expires_at'] as String)
          : null,
      pollMyVoteIndex: pollMyVoteIndex,
      pollTotalVotes: pollTotalVotes,
      pollOptionCounts: pollOptionCounts,
    );
  }

  /// PostgREST embeds a to-one relation (drop_polls.drop_id is unique)
  /// as a single object normally, but returns null rather than an
  /// object when there's no related row -- handles both that and the
  /// defensive case of a stray single-element list, the same shape
  /// [_embeddedCount] already defends against for the count embeds.
  static Map<String, dynamic>? _embeddedPoll(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      return raw.isEmpty ? null : raw.first as Map<String, dynamic>;
    }
    return raw as Map<String, dynamic>;
  }

  /// PostgREST embedded-resource counts (e.g. `drop_likes(count)`) come
  /// back as a single-element list like `[{'count': 3}]`.
  static int _embeddedCount(List<dynamic>? embedded) {
    if (embedded == null || embedded.isEmpty) return 0;
    return (embedded.first as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}
