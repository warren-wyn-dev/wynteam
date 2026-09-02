import '../../../core/text_utils.dart';
import '../../drop/data/drop.dart';
import '../../pop/data/pop.dart';
import 'home_liker.dart';
import 'home_top_reply.dart';

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
    this.authorIsVerified = false,
    required this.createdAt,
    this.caption,
    this.imageUrl,
    this.videoUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.viewCount,
    required this.likeCount,
    this.likedBy = const [],
    required this.commentCount,
    this.topReply,
    required this.likedByMe,
    required this.savedByMe,
    this.redropCount = 0,
    this.redroppedByMe = false,
    this.redropId,
    this.redropperId,
    this.redropperUsername,
    this.redropperDisplayName,
    this.redropperAvatarUrl,
    this.redropperIsVerified = false,
    this.quoteText,
    this.pollId,
    this.pollOptions,
    this.pollExpiresAt,
    this.pollMyVoteIndex,
    this.pollTotalVotes,
    this.pollOptionCounts,
    this.imageWidth,
    this.imageHeight,
  });

  final String id;
  final HomeContentType contentType;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  /// WYNOSHomeSpec.md 4.9/4.6: true for exactly one account, the
  /// official WYNOS account (Product's own manual flag via
  /// `profiles.is_verified` -- not a general creator-verification
  /// system). False for every other author.
  final bool authorIsVerified;

  final DateTime createdAt;
  final String? caption;

  /// Set only when [contentType] is [HomeContentType.drop].
  final String? imageUrl;

  /// WYN-093 (Wynos V1.0.0 Beta2, item 19): the primary image's real
  /// pixel dimensions -- drives HomeDropCard's dynamic-height/
  /// aspect-fit clamp. Null for a Drop created before this metadata
  /// existed (or any Pop-typed row); HomeDropCard falls back to the
  /// old fixed 1:1 square in that case. See [Drop.imageWidth]'s
  /// identical doc comment.
  final int? imageWidth;
  final int? imageHeight;

  /// Set only when [contentType] is [HomeContentType.pop].
  final String? videoUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final int? viewCount;

  final int likeCount;

  /// WYNOSHomeSpec.md 4.8: the first 3 likers (most-recent first), for
  /// the stacked-avatar "ถูกใจโดย ..." row. Empty whenever [likeCount]
  /// is 0, and also empty on any fetch path that doesn't embed
  /// `home_feed.liked_by` yet (see [HomeLiker.listFromMap]) -- callers
  /// render nothing rather than a count-only fallback in that case,
  /// same as the row being genuinely hidden.
  final List<HomeLiker> likedBy;

  final int commentCount;

  /// WYNOSHomeSpec.md 4.10: the highest-engagement top-level comment on
  /// this post, or null when nothing qualifies (see [HomeTopReply]'s
  /// own doc comment) -- including on any fetch path that doesn't
  /// embed `home_feed.top_reply` yet.
  final HomeTopReply? topReply;

  final bool likedByMe;
  final bool savedByMe;

  /// WYN-034: total Standard + Quote ReDrops of the underlying Drop. 0
  /// for Pop content (ReDrop doesn't apply there).
  final int redropCount;

  /// Whether the *current viewer* has Standard ReDropped the underlying
  /// Drop -- independent of whether *this particular row* is itself a
  /// ReDrop (see [redropId]). Drives the 🔄 button's toggle state on
  /// every drop-typed card, ReDrop-sourced or not.
  final bool redroppedByMe;

  /// Non-null only when this row came from someone's ReDrop rather than
  /// directly from `drops` -- i.e. this card is itself a ReDrop entry
  /// in the feed. When set, [redropperId]/[redropperUsername]/etc.
  /// describe *who* ReDropped, and [id]/[authorId]/[imageUrl]/[caption]
  /// still describe the *original* Drop untouched (credit preserved).
  final String? redropId;
  final String? redropperId;
  final String? redropperUsername;
  final String? redropperDisplayName;
  final String? redropperAvatarUrl;

  /// Same [authorIsVerified] semantics, for the redropper -- not
  /// currently rendered anywhere (WYNOSHomeSpec.md's own reference only
  /// shows the badge next to the *original* author's name), kept for
  /// parity with every other author_*/redropper_* field pair here.
  final bool redropperIsVerified;

  /// Set only for a Quote ReDrop (`redropId != null`) -- the redropper's
  /// own commentary. Null for a Standard ReDrop or a plain (non-ReDrop)
  /// row.
  final String? quoteText;

  /// WYN-035: set only when this row is a Poll Drop. See [Drop]'s
  /// identically-named fields for the exact same semantics.
  final String? pollId;
  final List<String>? pollOptions;
  final DateTime? pollExpiresAt;
  final int? pollMyVoteIndex;
  final int? pollTotalVotes;
  final List<int>? pollOptionCounts;

  bool get isPoll => pollId != null;

  bool get pollResultsVisible => pollTotalVotes != null;

  bool get pollIsClosed =>
      pollExpiresAt != null && !DateTime.now().toUtc().isBefore(pollExpiresAt!);

  /// Same optimistic-update role as [Drop.votedPoll] -- see its doc
  /// comment for the exact rules. Duplicated rather than shared
  /// because [HomeFeedItem] and [Drop] are two separate value types
  /// with no common base, same as every other pair of parallel
  /// toggle methods already in these two classes (toggledLike,
  /// toggledRedrop, ...).
  HomeFeedItem votedPoll(int optionIndex) {
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

  /// A real field-for-field copy, unlike the ad hoc "rebuild every
  /// field by hand" that used to live in HomeFeedScreen's own toggle
  /// helpers -- that shape silently reset any field it forgot to
  /// repeat to the constructor default (harmless before WYN-034, since
  /// nothing else existed yet; would have quietly wiped a ReDrop
  /// card's label/state on every Like/Save tap once redrop_* existed).
  HomeFeedItem copyWith({
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
      HomeFeedItem(
        id: id,
        contentType: contentType,
        authorId: authorId,
        authorUsername: authorUsername,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
        authorIsVerified: authorIsVerified,
        createdAt: createdAt,
        caption: caption,
        imageUrl: imageUrl,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        durationSeconds: durationSeconds,
        viewCount: viewCount,
        likeCount: likeCount ?? this.likeCount,
        likedBy: likedBy,
        commentCount: commentCount ?? this.commentCount,
        topReply: topReply,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
        redropCount: redropCount ?? this.redropCount,
        redroppedByMe: redroppedByMe ?? this.redroppedByMe,
        redropId: redropId,
        redropperId: redropperId,
        redropperUsername: redropperUsername,
        redropperDisplayName: redropperDisplayName,
        redropperAvatarUrl: redropperAvatarUrl,
        redropperIsVerified: redropperIsVerified,
        quoteText: quoteText,
        pollId: pollId,
        pollOptions: pollOptions,
        pollExpiresAt: pollExpiresAt,
        pollMyVoteIndex: pollMyVoteIndex ?? this.pollMyVoteIndex,
        pollTotalVotes: pollTotalVotes ?? this.pollTotalVotes,
        pollOptionCounts: pollOptionCounts ?? this.pollOptionCounts,
      );

  String get redropperNameOrUsername => displayNameOrUsername(
        displayName: redropperDisplayName,
        username: redropperUsername ?? '',
      );

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
        imageUrl: imageUrl,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        caption: caption,
        createdAt: createdAt,
        likeCount: likeCount,
        commentCount: commentCount,
        likedByMe: likedByMe,
        savedByMe: savedByMe,
        redropCount: redropCount,
        redroppedByMe: redroppedByMe,
        // WYN-038: home_feed/saved_feed always return a real (never
        // null) count via drop_view_count() for a Drop-typed row -- the
        // `?? 0` only guards a defensive default, same posture as every
        // other nullable-in-theory field this factory carries over.
        viewCount: viewCount ?? 0,
        pollId: pollId,
        pollOptions: pollOptions,
        pollExpiresAt: pollExpiresAt,
        pollMyVoteIndex: pollMyVoteIndex,
        pollTotalVotes: pollTotalVotes,
        pollOptionCounts: pollOptionCounts,
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
        imageWidth: drop.imageWidth,
        imageHeight: drop.imageHeight,
        likeCount: drop.likeCount,
        commentCount: drop.commentCount,
        likedByMe: drop.likedByMe,
        savedByMe: drop.savedByMe,
        redropCount: drop.redropCount,
        redroppedByMe: drop.redroppedByMe,
        // WYN-038: without this, a HomeDropCard built from fromDrop()
        // (hashtag_feed_screen.dart's Drop branch) would render the
        // literal string "null" for view count instead of a number --
        // [Drop.viewCount] itself already defaults to 0 when unknown,
        // so this always carries a real int through either way.
        viewCount: drop.viewCount,
        pollId: drop.pollId,
        pollOptions: drop.pollOptions,
        pollExpiresAt: drop.pollExpiresAt,
        pollMyVoteIndex: drop.pollMyVoteIndex,
        pollTotalVotes: drop.pollTotalVotes,
        pollOptionCounts: drop.pollOptionCounts,
      );

  /// [pollId]/[pollOptions]/[pollExpiresAt] read straight off
  /// `home_feed`'s own trailing columns (unlike [Drop.fromMap], which
  /// reads a nested `drop_polls` embed -- home_feed is a flat view, so
  /// these are already plain columns on the row). The per-viewer
  /// fields ([pollMyVoteIndex]/[pollTotalVotes]/[pollOptionCounts])
  /// are filled in by the caller from a separate batched lookup, same
  /// as [likedByMe]/[savedByMe]/[redroppedByMe].
  factory HomeFeedItem.fromMap(
    Map<String, dynamic> map, {
    required bool likedByMe,
    required bool savedByMe,
    bool redroppedByMe = false,
    int? pollMyVoteIndex,
    int? pollTotalVotes,
    List<int>? pollOptionCounts,
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
      authorIsVerified: map['author_is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      caption: map['caption'] as String?,
      imageUrl: map['image_url'] as String?,
      imageWidth: (map['image_width'] as num?)?.toInt(),
      imageHeight: (map['image_height'] as num?)?.toInt(),
      videoUrl: map['video_url'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      durationSeconds: map['duration_seconds'] as int?,
      viewCount: (map['view_count'] as num?)?.toInt(),
      likeCount: (map['like_count'] as num).toInt(),
      likedBy: HomeLiker.listFromMap(map),
      commentCount: (map['comment_count'] as num).toInt(),
      topReply: HomeTopReply.fromHomeFeedMap(map),
      likedByMe: likedByMe,
      savedByMe: savedByMe,
      redropCount: (map['redrop_count'] as num?)?.toInt() ?? 0,
      redroppedByMe: redroppedByMe,
      redropId: map['redrop_id'] as String?,
      redropperId: map['redropper_id'] as String?,
      redropperUsername: map['redropper_username'] as String?,
      redropperDisplayName: map['redropper_display_name'] as String?,
      redropperAvatarUrl: map['redropper_avatar_url'] as String?,
      redropperIsVerified: map['redropper_is_verified'] as bool? ?? false,
      quoteText: map['quote_text'] as String?,
      pollId: map['poll_id'] as String?,
      pollOptions: (map['poll_options'] as List<dynamic>?)?.cast<String>(),
      pollExpiresAt: map['poll_expires_at'] != null
          ? DateTime.parse(map['poll_expires_at'] as String)
          : null,
      pollMyVoteIndex: pollMyVoteIndex,
      pollTotalVotes: pollTotalVotes,
      pollOptionCounts: pollOptionCounts,
    );
  }
}
