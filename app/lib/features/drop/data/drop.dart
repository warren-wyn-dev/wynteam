import '../../../core/text_utils.dart';

/// WYN-097: who can see one Drop, chosen per-post at Compose time (the
/// Audience Selector chip/sheet) -- mirrors [InteractionPermission]'s
/// shape (WYN-045) but is its own type: a completely different
/// vocabulary (5 values, not 3) for a completely different question
/// ("who sees this post" vs. "who can DM/mention/comment on me").
/// `everyone` is the default, matching `drops.audience`'s own
/// `not null default 'everyone'` (supabase/schema.sql) -- every Drop
/// created before this feature existed reads as `everyone`.
enum AudienceOption { everyone, friends, friendsExcept, closeFriends, onlyMe }

AudienceOption audienceOptionFromString(String? value) => switch (value) {
      'friends' => AudienceOption.friends,
      'friends_except' => AudienceOption.friendsExcept,
      'close_friends' => AudienceOption.closeFriends,
      'only_me' => AudienceOption.onlyMe,
      _ => AudienceOption.everyone,
    };

extension AudienceOptionDbValue on AudienceOption {
  String get dbValue => switch (this) {
        AudienceOption.everyone => 'everyone',
        AudienceOption.friends => 'friends',
        AudienceOption.friendsExcept => 'friends_except',
        AudienceOption.closeFriends => 'close_friends',
        AudienceOption.onlyMe => 'only_me',
      };
}

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
    this.viewCount = 0,
    this.pollId,
    this.pollOptions,
    this.pollExpiresAt,
    this.pollMyVoteIndex,
    this.pollTotalVotes,
    this.pollOptionCounts,
    this.editedAt,
    this.deletedAt,
    this.imageWidth,
    this.imageHeight,
    this.audience = AudienceOption.everyone,
    this.location,
    this.imageUrls,
    int? imageCount,
  }) : imageCount = imageCount ?? (imageUrl != null ? 1 : 0);

  final String id;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  /// Null when this Drop is a Poll ([pollId] set) instead -- WYN-035:
  /// a Drop carries either an image or a Poll, never both this round.
  final String? imageUrl;

  /// WYN-071: total images this Drop has (1-9), sourced from
  /// `drop_images(count)` -- defaults to 1 when [imageUrl] is set and 0
  /// when it isn't (a Poll/text-only Drop), so every existing call site
  /// that doesn't pass this explicitly (fixtures, older tests, any
  /// fetch path not yet updated to embed the count) still gets the
  /// correct value for the single-image case it always represented.
  /// The images themselves (URLs 2-9, beyond [imageUrl]) live in
  /// [imageUrls] when a fetch path resolved them, and are otherwise
  /// fetched on demand -- see DropRepository.fetchDropImages.
  final int imageCount;

  /// Beta3: the full ordered image list, when whoever built this [Drop]
  /// already had it -- the Home feed batch-loads one page's worth in a
  /// single query (see HomeRepository.attachImageUrls) and hands it
  /// down, so opening a multi-image post from the feed no longer costs
  /// a per-card round trip on the way in and another on the way to
  /// Detail.
  ///
  /// Null means "not known here", never "this Drop has no images" --
  /// [imageCount] is the authority on how many there are. A consumer
  /// that needs the list falls back to
  /// [DropRepository.fetchDropImages], exactly as it did before this
  /// field existed.
  final List<String>? imageUrls;

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

  /// WYN-037: set once this Drop's caption has been edited at least
  /// once (via [DropRepository.editDrop]) -- drives the "แก้ไขแล้ว"
  /// badge. Null means never edited.
  final DateTime? editedAt;

  /// WYN-037: set when this Drop has been soft-deleted (via
  /// [DropRepository.softDeleteDrop]). A [Drop] with this set is only
  /// ever fetched by [DropRepository.fetchDeletedDrops] -- RLS hides
  /// it from every other read path (feeds/search/profile) for anyone
  /// but its own author, so an ordinarily-fetched [Drop] never has
  /// this set. Null means live/visible as normal.
  final DateTime? deletedAt;

  /// WYN-093 (Wynos V1.0.0 Beta2, item 19): the primary image's real
  /// pixel dimensions, captured once at upload time (DropRepository.
  /// createDrop) -- drives HomeDropCard's dynamic-height/aspect-fit
  /// clamp. Null for a Drop created before this metadata existed, or
  /// one with no image at all (Poll/text-only) -- either way,
  /// HomeDropCard falls back to the old fixed 1:1 square rather than
  /// guessing.
  final int? imageWidth;
  final int? imageHeight;

  /// WYN-097: who can see this Drop -- see [AudienceOption]'s own doc
  /// comment. Enforced server-side via RLS (supabase/schema.sql's
  /// `internal.can_view_drop_audience`); this field only drives
  /// client-side UI decisions (e.g. hiding the ReDrop button when this
  /// isn't [AudienceOption.everyone] -- Product spec Edge Case 2).
  final AudienceOption audience;

  /// WYN-098: the human-readable place name attached at Compose time
  /// (e.g. "สยามพารากอน") -- null for every Drop without a check-in
  /// (the overwhelming majority). This is the *only* location field
  /// this app ever displays; the raw coordinates/LocationIQ place id
  /// (`drops.location_lat`/`location_lon`/`location_place_id`) are
  /// stored server-side for a possible future feature but deliberately
  /// never fetched/shown here -- see Product spec's Privacy section.
  final String? location;

  bool get isPoll => pollId != null;

  /// WYN-071: drives the small "multiple photos" badge on grid tiles/
  /// cards and whether DropDetailScreen shows a swipeable PageView
  /// instead of a single static image.
  bool get hasMultipleImages => imageCount > 1;

  bool get wasEdited => editedAt != null;

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

  /// WYN-038: total unique-viewer View count of this Drop, sourced from
  /// `public.drop_view_count()` (see supabase/schema.sql) -- 0 default,
  /// same "existing call sites that don't pass it yet still compile"
  /// shape as [redropCount]. Only rows read via `home_feed`/`saved_feed`
  /// (i.e. Drops opened through Home/Saved, via [HomeFeedItem.toDrop])
  /// carry the real count today -- other DropRepository fetch paths
  /// (search, profile grid, notification-linked fetchById) still default
  /// to 0 until wired up, same scope note as this task's Coding Output.
  final int viewCount;

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
    int? viewCount,
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
        imageCount: imageCount,
        imageUrls: imageUrls,
        caption: caption,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
        redropCount: redropCount ?? this.redropCount,
        redroppedByMe: redroppedByMe ?? this.redroppedByMe,
        viewCount: viewCount ?? this.viewCount,
        pollId: pollId,
        pollOptions: pollOptions,
        pollExpiresAt: pollExpiresAt,
        pollMyVoteIndex: pollMyVoteIndex ?? this.pollMyVoteIndex,
        pollTotalVotes: pollTotalVotes ?? this.pollTotalVotes,
        pollOptionCounts: pollOptionCounts ?? this.pollOptionCounts,
        editedAt: editedAt,
        deletedAt: deletedAt,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        audience: audience,
        location: location,
      );

  /// A copy with the caption (or Poll question) edited -- WYN-037,
  /// optimistic-update role like [toggledLike]. Not part of [copyWith]
  /// because that method always carries [caption] over unconditionally
  /// -- this is the one place a Drop's caption is allowed to actually
  /// change. [caption] may be null (clearing it entirely, same as at
  /// creation time).
  Drop withEditedCaption(String? caption) => Drop(
        id: id,
        authorId: authorId,
        authorUsername: authorUsername,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
        imageUrl: imageUrl,
        imageCount: imageCount,
        imageUrls: imageUrls,
        caption: caption,
        createdAt: createdAt,
        likeCount: likeCount,
        commentCount: commentCount,
        likedByMe: likedByMe,
        savedByMe: savedByMe,
        redropCount: redropCount,
        redroppedByMe: redroppedByMe,
        viewCount: viewCount,
        pollId: pollId,
        pollOptions: pollOptions,
        pollExpiresAt: pollExpiresAt,
        pollMyVoteIndex: pollMyVoteIndex,
        pollTotalVotes: pollTotalVotes,
        pollOptionCounts: pollOptionCounts,
        editedAt: DateTime.now(),
        deletedAt: deletedAt,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        audience: audience,
        location: location,
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

  /// A copy with the View count bumped -- used right after
  /// [DropRepository.recordView] fires (optimistic UI), without waiting
  /// for a full feed refresh. Mirrors [Pop.withExtraView] -- WYN-038.
  Drop withExtraView() => copyWith(viewCount: viewCount + 1);

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
    List<String>? imageUrls,
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
      // Falls back to the imageUrl-based default (see the constructor)
      // when the query didn't embed drop_images(count) at all -- not
      // every DropRepository fetch path is updated to include it yet
      // (see the field's own doc comment).
      imageCount: map.containsKey('drop_images')
          ? _embeddedCount(map['drop_images'] as List<dynamic>?)
          : null,
      // Not a `drops` column -- batch-loaded alongside the page and
      // passed in by the caller (DropRepository._fetchImageUrls).
      imageUrls: imageUrls,
      caption: map['caption'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      likeCount: _embeddedCount(map['drop_likes'] as List<dynamic>?),
      commentCount: _embeddedCount(map['drop_comments'] as List<dynamic>?),
      likedByMe: likedByMe,
      savedByMe: savedByMe,
      redropCount: _embeddedCount(map['redrops'] as List<dynamic>?),
      redroppedByMe: redroppedByMe,
      // WYN-038: not part of _dropSelect today (only home_feed/
      // saved_feed carry the real value) -- defaults to 0 like every
      // other DropRepository read path, same defensive parsing as
      // [Pop.fromMap]'s view_count for whichever caller does supply it.
      viewCount: (map['view_count'] as num?)?.toInt() ?? 0,
      pollId: poll?['id'] as String?,
      pollOptions: (poll?['options'] as List<dynamic>?)?.cast<String>(),
      pollExpiresAt: poll?['expires_at'] != null
          ? DateTime.parse(poll!['expires_at'] as String)
          : null,
      pollMyVoteIndex: pollMyVoteIndex,
      pollTotalVotes: pollTotalVotes,
      pollOptionCounts: pollOptionCounts,
      editedAt: map['edited_at'] != null
          ? DateTime.parse(map['edited_at'] as String)
          : null,
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
      imageWidth: (map['image_width'] as num?)?.toInt(),
      imageHeight: (map['image_height'] as num?)?.toInt(),
      // WYN-097: defaults to `everyone` when the query didn't select it
      // (the `*` in _dropSelect already includes it, but a fixture/test
      // map built by hand may not) -- same "missing key defaults to the
      // least-restrictive value" reasoning as InteractionPermission's
      // own fromString.
      audience: audienceOptionFromString(map['audience'] as String?),
      // WYN-098: `*` in _dropSelect already includes this existing
      // `drops.location` column -- see that field's own doc comment
      // for why the lat/lon/place_id siblings are never read here.
      location: map['location'] as String?,
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
