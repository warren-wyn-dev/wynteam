import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import '../../home/data/home_feed_item.dart';
import '../../home/data/home_ranking.dart';
import 'drop.dart';
import 'drop_comment.dart';
import 'drop_draft.dart';
import 'image_dimensions.dart';

// PostgREST can't resolve a bare `profiles(...)` embed on its own when a
// sibling embed in the same select (drop_likes/drop_comments/
// drop_comment_likes) *also* has a foreign key to profiles -- it sees two
// candidate join paths and rejects the request with PGRST201 ("more than
// one relationship was found"). Only surfaced by running against a real
// Postgres database (discovered 2026-08-16, see
// .wyn/tasks/bugs/SCHEMA-DROP-001-ambiguous-author-embed.md) -- every
// widget test uses RecordingDropRepository, which never sends a real
// PostgREST query, so this was invisible until now. Fix: name the exact
// foreign key constraint (`!<table>_author_id_fkey`) instead of leaving
// PostgREST to guess.
const _dropAuthorSelect =
    'author:profiles!drops_author_id_fkey(username, display_name, avatar_url)';
const _commentAuthorSelect =
    'author:profiles!drop_comments_author_id_fkey(username, display_name, avatar_url)';
const _savesContentType = 'drop';

// WYN-035: drop_polls(...) is a to-one embed (drop_polls.drop_id is
// unique) -- every fetch method below shares this one select string
// (like _dropAuthorSelect/the count embeds already did) so a Poll
// Drop's base poll data (id/options/expires_at) always comes back
// alongside everything else, with no per-method opt-in to forget.
// WYN-071: drop_images(count) -- how many images this Drop actually has
// (1-9), not the images themselves (the full ordered list is only
// fetched on demand via fetchDropImages, when a viewer actually opens
// the full-screen viewer) -- keeps every list/feed fetch cheap.
const _dropSelect =
    '*, $_dropAuthorSelect, drop_likes(count), drop_comments(count), redrops(count), drop_polls(id, options, expires_at), drop_images(count)';

/// Per-viewer poll state ([DropRepository._fetchPollStates]'s result) --
/// combines "did I vote, and for what" with the aggregate results
/// [get_poll_results()] is willing to reveal to this viewer right now.
/// Never constructed for a drop id that isn't actually a poll.
class _PollState {
  const _PollState({this.myVoteIndex, this.totalVotes, this.optionCounts});

  final int? myVoteIndex;
  final int? totalVotes;
  final List<int>? optionCounts;
}

/// Wraps the `drops`/`drop_likes`/`drop_comments`/`saves` reads/writes and
/// drop-image storage needed for WYN-005 (Drop). See supabase/schema.sql
/// for the RLS policies this relies on.
class DropRepository {
  DropRepository(this._client);

  final SupabaseClient _client;

  // 21 (a multiple of 3) so a full page always fills whole grid rows.
  static const pageSize = 21;

  // The ranked "For You" tab (WYN-018 follow-up) is a bounded top-N
  // window, not true infinite ranking -- see fetchRankedFeed's doc
  // comment. A multiple of pageSize so _hasMore's "did this page come
  // back full" check in DropFeedScreen still behaves the same as every
  // other paginated method here.
  static const _rankedCandidateLimit = pageSize * 10;

  /// Fetches one page (0-indexed) of the Drop grid, newest first.
  Future<List<Drop>> fetchFeed({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('drops')
        .select(_dropSelect)
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: dropIds);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: dropIds);
    final redroppedIds =
        await _fetchRedroppedDropIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows.map(_pollIdFromRow).whereType<String>().toList(),
    );

    return rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
              redroppedByMe: redroppedIds.contains(row['id'] as String),
              pollMyVoteIndex: pollStates[_pollIdFromRow(row)]?.myVoteIndex,
              pollTotalVotes: pollStates[_pollIdFromRow(row)]?.totalVotes,
              pollOptionCounts: pollStates[_pollIdFromRow(row)]?.optionCounts,
            ))
        .toList();
  }

  /// Fetches one page (0-indexed) of Drops whose caption contains [query]
  /// (case insensitive), newest first -- for WYN-009 Search's Drop tab.
  Future<List<Drop>> searchByCaption({
    required String query,
    required int page,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('drops')
        .select(_dropSelect)
        .ilike('caption', '%$query%')
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: dropIds);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: dropIds);
    final redroppedIds =
        await _fetchRedroppedDropIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows.map(_pollIdFromRow).whereType<String>().toList(),
    );

    return rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
              redroppedByMe: redroppedIds.contains(row['id'] as String),
              pollMyVoteIndex: pollStates[_pollIdFromRow(row)]?.myVoteIndex,
              pollTotalVotes: pollStates[_pollIdFromRow(row)]?.totalVotes,
              pollOptionCounts: pollStates[_pollIdFromRow(row)]?.optionCounts,
            ))
        .toList();
  }

  /// Fetches one page (0-indexed) of Drops by a single author, newest
  /// first -- for the Drop grid tab on that author's profile (WYN-013).
  /// A separate method from [fetchFeed] (global, unfiltered) rather than
  /// adding an optional filter to it, so the existing Drop Feed query
  /// stays untouched.
  Future<List<Drop>> fetchByAuthor({
    required String authorId,
    required int page,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('drops')
        .select(_dropSelect)
        .eq('author_id', authorId)
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: dropIds);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: dropIds);
    final redroppedIds =
        await _fetchRedroppedDropIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows.map(_pollIdFromRow).whereType<String>().toList(),
    );

    return rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
              redroppedByMe: redroppedIds.contains(row['id'] as String),
              pollMyVoteIndex: pollStates[_pollIdFromRow(row)]?.myVoteIndex,
              pollTotalVotes: pollStates[_pollIdFromRow(row)]?.totalVotes,
              pollOptionCounts: pollStates[_pollIdFromRow(row)]?.optionCounts,
            ))
        .toList();
  }

  /// Total (non-deleted) Drop count for one author -- 05-profile.tsx's
  /// StatsRow "โพสต์" stat, same `_client.rpc` shape as
  /// FollowRepository.countFollowers/countFollowing (see
  /// public.drop_count() in supabase/schema.sql).
  Future<int> countByAuthor(String authorId) async {
    final response =
        await _client.rpc('drop_count', params: {'p_user_id': authorId});
    return (response as num).toInt();
  }

  /// WYN-071: Profile's "Likes" tab -- Drops [authorId] has Liked, newest
  /// Like first (not newest Drop first -- ordered by `drop_likes.
  /// created_at`, mirroring how a Likes tab reads on the reference apps
  /// this was modeled on). `drop_likes` is already public-read (`using
  /// (true)`, see schema.sql) -- Founder decision 2026-08-24 makes this
  /// tab itself public the same way, so no new RLS is needed at all,
  /// only this query. The embedded `drops!inner(...)` still goes
  /// through `drops`' own RLS, so a Liked-but-since-moderated/deleted/
  /// blocked-author Drop is silently excluded rather than surfaced.
  Future<List<Drop>> fetchLikedByAuthor({
    required String authorId,
    required int page,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final likeRows = await _client
        .from('drop_likes')
        .select('drops!inner($_dropSelect)')
        .eq('user_id', authorId)
        .order('created_at', ascending: false)
        .range(from, to);
    final rows = likeRows.map((row) => row['drops'] as Map<String, dynamic>).toList();

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: dropIds);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: dropIds);
    final redroppedIds =
        await _fetchRedroppedDropIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows.map(_pollIdFromRow).whereType<String>().toList(),
    );

    return rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
              redroppedByMe: redroppedIds.contains(row['id'] as String),
              pollMyVoteIndex: pollStates[_pollIdFromRow(row)]?.myVoteIndex,
              pollTotalVotes: pollStates[_pollIdFromRow(row)]?.totalVotes,
              pollOptionCounts: pollStates[_pollIdFromRow(row)]?.optionCounts,
            ))
        .toList();
  }

  /// WYN-071: Profile's "Replies" tab -- top-level and reply comments
  /// [authorId] has written, newest first, alongside enough of the
  /// parent Drop to show it in context (author, image, caption).
  /// `drop_comments` is already public-read the same way `drop_likes`
  /// is (see [fetchLikedByAuthor]'s doc comment) -- no new RLS needed.
  ///
  /// Returns [ProfileReply] rather than a bare [DropComment] -- unlike
  /// every other place [DropComment] is fetched (always already scoped
  /// to one known Drop, e.g. DropDetailScreen's comment list), this tab
  /// shows comments made across many different Drops at once, so the
  /// UI needs enough of each parent Drop to distinguish and link to it.
  Future<List<ProfileReply>> fetchRepliesByAuthor({
    required String authorId,
    required int page,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('drop_comments')
        .select('*, $_commentAuthorSelect, '
            'drop:drops!inner(id, caption, image_url, '
            'author:profiles!drops_author_id_fkey(username, display_name))')
        .eq('author_id', authorId)
        .order('created_at', ascending: false)
        .range(from, to);

    return rows.map((row) {
      final drop = row['drop'] as Map<String, dynamic>;
      final dropAuthor = drop['author'] as Map<String, dynamic>?;
      return ProfileReply(
        comment: DropComment.fromMap(row, likedByMe: false),
        dropId: drop['id'] as String,
        dropCaption: drop['caption'] as String?,
        dropImageUrl: drop['image_url'] as String?,
        dropAuthorUsername: dropAuthor?['username'] as String? ?? '',
        dropAuthorDisplayName: dropAuthor?['display_name'] as String?,
      );
    }).toList();
  }

  /// Fetches one page (0-indexed) of Drops authored by users the current
  /// user follows, newest first -- for WYN-019's Drop tab "Following" tab.
  /// `follows` doesn't join directly into a `drops` query (PostgREST has
  /// no subquery-in-filter syntax), so this fetches the followed-user-id
  /// list first, same two-step shape ClubRepository/HomeRepository already
  /// use for similar "filtered by a related table" reads.
  Future<List<Drop>> fetchFollowingFeed({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final followRows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    final followingIds =
        followRows.map((row) => row['following_id'] as String).toList();
    if (followingIds.isEmpty) return [];

    final rows = await _client
        .from('drops')
        .select(_dropSelect)
        .inFilter('author_id', followingIds)
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: dropIds);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: dropIds);
    final redroppedIds =
        await _fetchRedroppedDropIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows.map(_pollIdFromRow).whereType<String>().toList(),
    );

    return rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
              redroppedByMe: redroppedIds.contains(row['id'] as String),
              pollMyVoteIndex: pollStates[_pollIdFromRow(row)]?.myVoteIndex,
              pollTotalVotes: pollStates[_pollIdFromRow(row)]?.totalVotes,
              pollOptionCounts: pollStates[_pollIdFromRow(row)]?.optionCounts,
            ))
        .toList();
  }

  /// Fetches one page (0-indexed) of Drop tab's "For You" tab, ordered by
  /// [rankingScore] instead of chronologically -- the WYN-018 follow-up
  /// its own design doc flagged as the natural next step ("Once WYN-018
  /// ships, For You switches to the shared ranking query"). Reuses the
  /// exact same formula Home's "สำหรับคุณ" uses (via
  /// [HomeFeedItem.fromDrop]) rather than a second scoring function, so
  /// the two "For You" feeds in the app agree on what "relevant" means.
  ///
  /// Same bounded-window shape as [HomeRepository.fetchRankedFeed] and
  /// for the same reason: PostgREST can't `order()` by a computed
  /// expression, so this fetches a bounded set of recent candidates and
  /// ranks them client-side. [page]s beyond the window return empty.
  Future<List<Drop>> fetchRankedFeed({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;
    if (from >= _rankedCandidateLimit) return [];

    final rows = await _client
        .from('drops')
        .select(_dropSelect)
        .order('created_at', ascending: false)
        .limit(_rankedCandidateLimit);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final authorIds = rows.map((row) => row['author_id'] as String).toSet();
    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: dropIds);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: dropIds);
    final redroppedIds =
        await _fetchRedroppedDropIds(userId: userId, dropIds: dropIds);
    final followedAuthorIds = await _fetchFollowedAuthorIds(
      userId: userId,
      authorIds: authorIds,
    );
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows.map(_pollIdFromRow).whereType<String>().toList(),
    );

    final drops = rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
              redroppedByMe: redroppedIds.contains(row['id'] as String),
              pollMyVoteIndex: pollStates[_pollIdFromRow(row)]?.myVoteIndex,
              pollTotalVotes: pollStates[_pollIdFromRow(row)]?.totalVotes,
              pollOptionCounts: pollStates[_pollIdFromRow(row)]?.optionCounts,
            ))
        .toList();

    final now = DateTime.now().toUtc();
    drops.sort((a, b) {
      final scoreA = rankingScore(
        HomeFeedItem.fromDrop(a),
        now: now,
        isFollowingAuthor: followedAuthorIds.contains(a.authorId),
      );
      final scoreB = rankingScore(
        HomeFeedItem.fromDrop(b),
        now: now,
        isFollowingAuthor: followedAuthorIds.contains(b.authorId),
      );
      return scoreB.compareTo(scoreA);
    });

    if (from >= drops.length) return [];
    return drops.sublist(from, to + 1 > drops.length ? drops.length : to + 1);
  }

  Future<Set<String>> _fetchFollowedAuthorIds({
    required String userId,
    required Set<String> authorIds,
  }) async {
    if (authorIds.isEmpty) return {};

    final rows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId)
        .inFilter('following_id', authorIds.toList());

    return rows.map((row) => row['following_id'] as String).toSet();
  }

  /// Fetches a single Drop by id, with a fresh likedByMe/savedByMe for the
  /// current user -- for opening a Drop referenced by a notification
  /// (WYN-012), where only the id is known, not a full Drop object.
  /// Returns null if the Drop no longer exists (e.g. deleted since the
  /// notification was created).
  Future<Drop?> fetchById(String dropId) async {
    final userId = _client.auth.currentUser!.id;

    final row = await _client
        .from('drops')
        .select(_dropSelect)
        .eq('id', dropId)
        .maybeSingle();
    if (row == null) return null;

    final likedIds =
        await _fetchLikedDropIds(userId: userId, dropIds: [dropId]);
    final savedIds =
        await _fetchSavedDropIds(userId: userId, dropIds: [dropId]);
    final redroppedIds =
        await _fetchRedroppedDropIds(userId: userId, dropIds: [dropId]);
    final pollId = _pollIdFromRow(row);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: pollId == null ? const [] : [pollId],
    );

    return Drop.fromMap(
      row,
      likedByMe: likedIds.contains(dropId),
      savedByMe: savedIds.contains(dropId),
      redroppedByMe: redroppedIds.contains(dropId),
      pollMyVoteIndex: pollStates[pollId]?.myVoteIndex,
      pollTotalVotes: pollStates[pollId]?.totalVotes,
      pollOptionCounts: pollStates[pollId]?.optionCounts,
    );
  }

  Future<Set<String>> _fetchLikedDropIds({
    required String userId,
    required List<String> dropIds,
  }) async {
    if (dropIds.isEmpty) return {};

    final rows = await _client
        .from('drop_likes')
        .select('drop_id')
        .eq('user_id', userId)
        .inFilter('drop_id', dropIds);

    return rows.map((row) => row['drop_id'] as String).toSet();
  }

  Future<Set<String>> _fetchSavedDropIds({
    required String userId,
    required List<String> dropIds,
  }) async {
    if (dropIds.isEmpty) return {};

    final rows = await _client
        .from('saves')
        .select('content_id')
        .eq('user_id', userId)
        .eq('content_type', _savesContentType)
        .inFilter('content_id', dropIds);

    return rows.map((row) => row['content_id'] as String).toSet();
  }

  /// Only Standard ReDrops (quote_text is null) count toward
  /// [Drop.redroppedByMe] -- a Quote ReDrop doesn't toggle the 🔄
  /// button's state (see that field's doc comment).
  Future<Set<String>> _fetchRedroppedDropIds({
    required String userId,
    required List<String> dropIds,
  }) async {
    if (dropIds.isEmpty) return {};

    final rows = await _client
        .from('redrops')
        .select('drop_id')
        .eq('redropper_id', userId)
        .isFilter('quote_text', null)
        .inFilter('drop_id', dropIds);

    return rows.map((row) => row['drop_id'] as String).toSet();
  }

  /// Same defensive object-or-list-or-null handling as
  /// [Drop._embeddedPoll] -- see that method's doc comment. Returns
  /// null for a Drop with no poll.
  static String? _pollIdFromRow(Map<String, dynamic> row) {
    final raw = row['drop_polls'];
    if (raw == null) return null;
    if (raw is List) {
      return raw.isEmpty
          ? null
          : (raw.first as Map<String, dynamic>)['id'] as String?;
    }
    return (raw as Map<String, dynamic>)['id'] as String?;
  }

  /// Batches "my vote" (RLS restricts this to the caller's own row) and
  /// aggregate results ([get_poll_results()], which enforces the
  /// voted/author/expired visibility rule at the DB layer, not here)
  /// into one per-poll state map -- one query pair per page, not one
  /// per card, mirroring [_fetchLikedDropIds]/[_fetchRedroppedDropIds].
  Future<Map<String, _PollState>> _fetchPollStates({
    required String userId,
    required List<String> pollIds,
  }) async {
    if (pollIds.isEmpty) return {};

    final myVoteRows = await _client
        .from('drop_poll_votes')
        .select('poll_id, option_index')
        .eq('voter_id', userId)
        .inFilter('poll_id', pollIds);
    final myVotes = {
      for (final row in myVoteRows)
        row['poll_id'] as String: row['option_index'] as int,
    };

    final resultRows = await _client.rpc(
      'get_poll_results',
      params: {'p_poll_ids': pollIds},
    ) as List<dynamic>;
    final resultsByPollId = {
      for (final row in resultRows)
        row['poll_id'] as String: row as Map<String, dynamic>,
    };

    return {
      for (final id in pollIds)
        id: _PollState(
          myVoteIndex: myVotes[id],
          totalVotes: resultsByPollId[id]?['visible'] == true
              ? (resultsByPollId[id]!['total_votes'] as num).toInt()
              : null,
          optionCounts: resultsByPollId[id]?['visible'] == true
              ? (resultsByPollId[id]!['option_counts'] as List<dynamic>)
                  .map((e) => (e as num).toInt())
                  .toList()
              : null,
        ),
    };
  }

  /// Creates a Poll Drop (WYN-035) via the `create_poll_drop()` RPC --
  /// atomically inserts `drops` (image_url left null)+`drop_polls`+
  /// `drop_mentions` in one transaction. A separate method from
  /// [createDrop] rather than a bunch of nullable params on it, same
  /// "one method per distinct action" shape [toggleRedrop]/
  /// [quoteRedrop] already use.
  Future<void> createPollDrop({
    required String question,
    required List<String> options,
    required int durationDays,
    Set<String> mentionedUserIds = const {},
  }) {
    return _client.rpc('create_poll_drop', params: {
      'p_caption': question.trim(),
      'p_options': options,
      'p_duration_days': durationDays,
      'p_mentioned_user_ids': mentionedUserIds.toList(),
    });
  }

  /// Casts (or changes) a vote -- an upsert on `drop_poll_votes` so a
  /// second call with a different [optionIndex] updates the same row
  /// (see `drop_poll_votes_validate` in supabase/schema.sql for the
  /// server-side rules this is subject to: not the poll's own author,
  /// not after it closes, not blocked-either-way with the author).
  Future<void> votePoll({
    required String pollId,
    required int optionIndex,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('drop_poll_votes').upsert(
      {
        'poll_id': pollId,
        'voter_id': userId,
        'option_index': optionIndex,
      },
      onConflict: 'poll_id,voter_id',
    );
  }

  /// Creates a Drop with 1-9 photos (WYN-071 -- was exactly 1 photo
  /// before). [imagesBytes]/[imageExtensions] are parallel lists, same
  /// order the Composer's preview grid shows them in -- that order
  /// becomes each image's `drop_images.position`. [mentionedUserIds]
  /// (WYN-021) is the set of user ids MentionInput already resolved
  /// while composing the caption -- inserted into `drop_mentions` right
  /// after the Drop itself, not re-parsed from the caption text
  /// server-side. [caption] may be empty here (image Drop,
  /// WYNOS V1.0.0 Beta) -- use [createTextDrop] instead when there's no
  /// image at all.
  Future<void> createDrop({
    required List<Uint8List> imagesBytes,
    required List<String> imageExtensions,
    required String caption,
    Set<String> mentionedUserIds = const {},
  }) async {
    assert(imagesBytes.length == imageExtensions.length);
    assert(imagesBytes.isNotEmpty && imagesBytes.length <= 9);
    final userId = _client.auth.currentUser!.id;

    final imageUrls = <String>[];
    // WYN-093: decoded from the in-memory bytes already picked/
    // compressed for upload -- no extra network round-trip, and known
    // before drops/drop_images are ever inserted so HomeDropCard never
    // has to wait for Image.network to finish loading before it knows
    // how tall to render the card.
    final imageDimensions = <(int, int)>[];
    for (var i = 0; i < imagesBytes.length; i++) {
      final path =
          '$userId/${DateTime.now().millisecondsSinceEpoch}_$i.${imageExtensions[i]}';
      await _client.storage
          .from('drop-images')
          .uploadBinary(path, imagesBytes[i]);
      imageUrls.add(_client.storage.from('drop-images').getPublicUrl(path));
      imageDimensions.add(await decodeImageDimensions(imagesBytes[i]));
    }

    await _insertDrop(
      imageUrl: imageUrls.first,
      allImageUrls: imageUrls,
      allImageDimensions: imageDimensions,
      caption: caption,
      mentionedUserIds: mentionedUserIds,
    );
  }

  /// WYN-036: publishes a Drop from an image that's *already*
  /// uploaded (a Draft's `image_url`, carried over unchanged from
  /// when it was saved) -- skips the upload step [createDrop] always
  /// does, since there are no fresh bytes to upload here. Continuing
  /// a Draft only calls this when the user never picked a replacement
  /// image; picking a new one still goes through [createDrop] as
  /// normal.
  Future<void> createDropFromExistingImage({
    required String imageUrl,
    required String caption,
    Set<String> mentionedUserIds = const {},
  }) {
    return _insertDrop(
      imageUrl: imageUrl,
      caption: caption,
      mentionedUserIds: mentionedUserIds,
    );
  }

  /// Creates a caption-only Drop (WYNOS V1.0.0 Beta) -- no photo at all,
  /// mirroring how [createPollDrop] already produces a null-`image_url`
  /// row. [caption] must be non-empty after trimming (the composer's
  /// own `_canShare` already guarantees this; re-checked here so a
  /// caller can't slip an all-null row past this method the way the
  /// dropped `image_url not null` table constraint used to prevent).
  Future<void> createTextDrop({
    required String caption,
    Set<String> mentionedUserIds = const {},
  }) {
    if (caption.trim().isEmpty) {
      throw ArgumentError('A text-only Drop needs a non-empty caption');
    }
    return _insertDrop(
      imageUrl: null,
      caption: caption,
      mentionedUserIds: mentionedUserIds,
    );
  }

  Future<void> _insertDrop({
    required String? imageUrl,
    required String caption,
    required Set<String> mentionedUserIds,
    // WYN-071: every image (including [imageUrl] itself, at position 0)
    // -- same "position 0 lives in drop_images too" convention the
    // schema.sql backfill migration establishes. Empty/omitted for the
    // no-image (createTextDrop) and existing-single-image
    // (createDropFromExistingImage) call sites, neither of which needs
    // more than the one row image_url already represents.
    List<String> allImageUrls = const [],
    // WYN-093: parallel to [allImageUrls] (same index = same image).
    // Empty whenever [allImageUrls] is (or when the caller has no
    // fresh bytes to measure, e.g. createDropFromExistingImage --
    // that Drop's `drops.image_width`/`image_height` just stay null,
    // same accepted gap as any other pre-this-migration Drop).
    List<(int, int)> allImageDimensions = const [],
  }) async {
    final primaryDimensions =
        allImageDimensions.isNotEmpty ? allImageDimensions.first : null;
    final row = await _client
        .from('drops')
        .insert({
          'author_id': _client.auth.currentUser!.id,
          'image_url': imageUrl,
          'caption': normalizeOptionalText(caption.trim()),
          'image_width': primaryDimensions?.$1,
          'image_height': primaryDimensions?.$2,
        })
        .select('id')
        .single();
    final dropId = row['id'] as String;

    if (allImageUrls.isNotEmpty) {
      await _client.from('drop_images').insert([
        for (var i = 0; i < allImageUrls.length; i++)
          {
            'drop_id': dropId,
            'image_url': allImageUrls[i],
            'position': i,
            'image_width': i < allImageDimensions.length ? allImageDimensions[i].$1 : null,
            'image_height': i < allImageDimensions.length ? allImageDimensions[i].$2 : null,
          },
      ]);
    }

    if (mentionedUserIds.isNotEmpty) {
      await _client.from('drop_mentions').insert([
        for (final mentionedId in mentionedUserIds)
          {'drop_id': dropId, 'mentioned_user_id': mentionedId},
      ]);
    }
  }

  /// WYN-071: the full ordered image list for a Drop with more than one
  /// image -- only DropDetailScreen's full-screen viewer calls this
  /// (see [Drop.hasMultipleImages]), on demand, rather than every list/
  /// feed fetch eagerly loading every image URL of every Drop.
  Future<List<String>> fetchDropImages(String dropId) async {
    final rows = await _client
        .from('drop_images')
        .select('image_url')
        .eq('drop_id', dropId)
        .order('position');
    return rows.map((row) => row['image_url'] as String).toList();
  }

  /// Caption-only fetch for hashtag suggestion counting (WYNOS V1.0.0
  /// Beta) -- unlike [searchByCaption], this skips the like/save/redrop/
  /// poll lookups since a suggestion dropdown only needs the raw caption
  /// text to extract hashtags from, not full renderable [Drop] rows.
  /// Bounded to [limit] most-recent matches -- an approximate candidate
  /// set, same "no dedicated hashtags table" posture WYN-020 already
  /// established, not an exact global count.
  Future<List<String>> fetchCaptionsForHashtagSuggestion(
    String query, {
    int limit = 60,
  }) async {
    final rows = await _client
        .from('drops')
        .select('caption')
        .ilike('caption', '%$query%')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map((row) => row['caption'] as String?)
        .whereType<String>()
        .toList();
  }

  /// Soft-deletes a Drop (WYN-037) -- hides it from everyone but its
  /// own author (RLS, not a client-side filter), recoverable via
  /// [restoreDrop] within the 30-day window `soft_delete_drop()`
  /// enforces server-side. There is no client-facing hard delete of a
  /// Drop anymore -- moderation's Remove Content (WYN-029) still
  /// hard-deletes, but that's a separate SECURITY DEFINER path this
  /// method never touches.
  Future<void> deleteDrop(String dropId) {
    return _client.rpc('soft_delete_drop', params: {'p_drop_id': dropId});
  }

  /// Restores a previously soft-deleted Drop (WYN-037) -- rejected
  /// server-side by `restore_drop()` once the 30-day window has
  /// passed, or if the caller isn't the Drop's own author.
  Future<void> restoreDrop(String dropId) {
    return _client.rpc('restore_drop', params: {'p_drop_id': dropId});
  }

  /// Edits a Drop's caption (or a Poll Drop's question -- same field)
  /// (WYN-037) -- rejected server-side by `edit_drop()` past the
  /// 30-minute edit window, if the Drop is deleted, or if the caller
  /// isn't the Drop's own author. The image and (for a Poll) its
  /// options/duration are never editable, by design -- this only ever
  /// touches `caption`.
  Future<void> editDrop({required String dropId, required String caption}) {
    return _client.rpc(
      'edit_drop',
      params: {'p_drop_id': dropId, 'p_caption': caption},
    );
  }

  /// Every Drop the current user has soft-deleted and can still
  /// restore -- WYN-037's "รายการที่ลบ" screen. RLS already restricts
  /// this to the caller's own rows (the same policy that lets an
  /// author keep seeing their own deleted Drop everywhere else), the
  /// explicit filters here just narrow it to deleted-only, newest
  /// first.
  Future<List<Drop>> fetchDeletedDrops() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('drops')
        .select(_dropSelect)
        .eq('author_id', userId)
        .not('deleted_at', 'is', null)
        .order('deleted_at', ascending: false);
    return rows
        .map((row) => Drop.fromMap(row, likedByMe: false, savedByMe: false))
        .toList();
  }

  Future<void> toggleLike({
    required String dropId,
    required bool currentlyLiked,
  }) async {
    final userId = _client.auth.currentUser!.id;
    if (currentlyLiked) {
      await _client
          .from('drop_likes')
          .delete()
          .eq('drop_id', dropId)
          .eq('user_id', userId);
    } else {
      await _client
          .from('drop_likes')
          .insert({'drop_id': dropId, 'user_id': userId});
    }
  }

  Future<void> toggleSave({
    required String dropId,
    required bool currentlySaved,
  }) async {
    final userId = _client.auth.currentUser!.id;
    if (currentlySaved) {
      await _client
          .from('saves')
          .delete()
          .eq('user_id', userId)
          .eq('content_type', _savesContentType)
          .eq('content_id', dropId);
    } else {
      await _client.from('saves').insert({
        'user_id': userId,
        'content_type': _savesContentType,
        'content_id': dropId,
      });
    }
  }

  /// Records a View via a security-definer RPC (rather than a direct
  /// client insert into `drop_views`, which has no client-facing INSERT
  /// policy at all) -- see supabase/schema.sql's record_drop_view() for
  /// the rate-limit/velocity-cap rules it enforces (WYN-083: no more
  /// unique-viewer dedup or self-view exclusion -- every call counts,
  /// including repeats and the Drop's own author). Mirrors
  /// [PopRepository.recordView] -- WYN-038. Silently no-ops server-side
  /// (never throws for a normal rejection like "over quota"), same
  /// posture as Pop's.
  Future<void> recordView(String dropId) {
    return _client.rpc('record_drop_view', params: {'p_drop_id': dropId});
  }

  /// Standard ReDrop toggle (WYN-034) -- insert/delete on `redrops` with
  /// `quote_text: null`, same shape as [toggleLike]. Quote ReDrop uses
  /// [quoteRedrop] instead, never this method.
  Future<void> toggleRedrop({
    required String dropId,
    required bool currentlyRedropped,
  }) async {
    final userId = _client.auth.currentUser!.id;
    if (currentlyRedropped) {
      await _client
          .from('redrops')
          .delete()
          .eq('drop_id', dropId)
          .eq('redropper_id', userId)
          .isFilter('quote_text', null);
    } else {
      await _client.from('redrops').insert({
        'drop_id': dropId,
        'redropper_id': userId,
      });
    }
  }

  /// Quote ReDrop (WYN-034) -- always inserts a new row (never toggles;
  /// the same Drop can be quoted multiple times with different
  /// commentary, unlike Standard ReDrop). [quoteText] is required and
  /// non-blank -- `redrops_quote_text_length` also enforces 1-500
  /// characters server-side.
  Future<void> quoteRedrop({
    required String dropId,
    required String quoteText,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('redrops').insert({
      'drop_id': dropId,
      'redropper_id': userId,
      'quote_text': quoteText.trim(),
    });
  }

  /// Deletes a single ReDrop (Standard or Quote) by its own id -- for
  /// removing a specific Quote ReDrop from the "ReDrops" Profile tab.
  /// RLS restricts this to the caller's own redrops, same posture as
  /// [deleteComment].
  Future<void> deleteRedrop(String redropId) {
    return _client.from('redrops').delete().eq('id', redropId);
  }

  /// Oldest first, unlike the grid -- comments read top-to-bottom like a
  /// conversation.
  Future<List<DropComment>> fetchComments(String dropId) async {
    final userId = _client.auth.currentUser!.id;

    final rows = await _client
        .from('drop_comments')
        .select('*, $_commentAuthorSelect, drop_comment_likes(count)')
        .eq('drop_id', dropId)
        .order('created_at', ascending: true);

    final commentIds = rows.map((row) => row['id'] as String).toList();
    final likedIds =
        await _fetchLikedCommentIds(userId: userId, commentIds: commentIds);

    return rows
        .map((row) => DropComment.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
            ))
        .toList();
  }

  Future<Set<String>> _fetchLikedCommentIds({
    required String userId,
    required List<String> commentIds,
  }) async {
    if (commentIds.isEmpty) return {};

    final rows = await _client
        .from('drop_comment_likes')
        .select('comment_id')
        .eq('user_id', userId)
        .inFilter('comment_id', commentIds);

    return rows.map((row) => row['comment_id'] as String).toSet();
  }

  /// [parentCommentId] (WYN-022): set to reply to that top-level comment
  /// instead of posting a new top-level one. The DB rejects a reply
  /// whose own parent is itself already a reply (one level of nesting
  /// only) -- not re-checked client-side.
  Future<DropComment> addComment({
    required String dropId,
    required String textContent,
    String? parentCommentId,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final row = await _client
        .from('drop_comments')
        .insert({
          'drop_id': dropId,
          'author_id': userId,
          'text_content': textContent.trim(),
          'parent_comment_id': parentCommentId,
        })
        .select('*, $_commentAuthorSelect')
        .single();

    // A freshly-created comment can't have any likes yet -- no need for a
    // count/liked lookup like fetchComments does.
    return DropComment.fromMap(row, likedByMe: false);
  }

  Future<void> toggleCommentLike({
    required String commentId,
    required bool currentlyLiked,
  }) async {
    final userId = _client.auth.currentUser!.id;
    if (currentlyLiked) {
      await _client
          .from('drop_comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
    } else {
      await _client
          .from('drop_comment_likes')
          .insert({'comment_id': commentId, 'user_id': userId});
    }
  }

  /// RLS on drop_comments restricts this to the caller's own comments --
  /// no client-side ownership check needed before sending the request,
  /// only before showing the delete affordance in the UI.
  Future<void> deleteComment(String commentId) {
    return _client.from('drop_comments').delete().eq('id', commentId);
  }

  /// Fetches every draft belonging to the current user, most-recently-
  /// edited first (`updated_at`, not `created_at` -- editing an old
  /// draft should bring it back to the top) -- WYN-036. RLS already
  /// restricts this to the caller's own rows even without the
  /// (redundant but explicit) filter here.
  Future<List<DropDraft>> fetchDrafts() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('drop_drafts')
        .select()
        .eq('author_id', userId)
        .order('updated_at', ascending: false);
    return rows.map(DropDraft.fromMap).toList();
  }

  /// Creates or updates a draft (WYN-036) -- an insert when [draftId]
  /// is null, an update in place otherwise (so re-saving an
  /// already-saved draft never creates a duplicate row). Returns the
  /// draft's id either way, so the caller (CreateDropScreen) can keep
  /// targeting the same row across multiple saves in one editing
  /// session.
  ///
  /// [imageBytes] is only for a freshly picked/replaced image --
  /// uploads it and stores the new URL. [existingImageUrl] carries
  /// forward a draft's already-uploaded image when the user didn't
  /// change it this time (no re-upload). Passing neither saves the
  /// draft with no image (e.g. poll mode, or the image was removed).
  Future<String> saveDraft({
    String? draftId,
    Uint8List? imageBytes,
    String imageExtension = 'jpg',
    String? existingImageUrl,
    String? caption,
    List<String>? pollOptions,
    int? pollDurationDays,
  }) async {
    final userId = _client.auth.currentUser!.id;

    var imageUrl = existingImageUrl;
    if (imageBytes != null) {
      final path =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.$imageExtension';
      await _client.storage.from('drop-images').uploadBinary(path, imageBytes);
      imageUrl = _client.storage.from('drop-images').getPublicUrl(path);
    }

    final row = {
      'author_id': userId,
      'image_url': imageUrl,
      'caption': caption == null ? null : normalizeOptionalText(caption.trim()),
      'poll_options': pollOptions,
      'poll_duration_days': pollDurationDays,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (draftId == null) {
      final inserted =
          await _client.from('drop_drafts').insert(row).select('id').single();
      return inserted['id'] as String;
    }

    await _client.from('drop_drafts').update(row).eq('id', draftId);
    return draftId;
  }

  /// RLS on drop_drafts restricts this to the caller's own drafts --
  /// same posture as [deleteComment]/[deleteDrop].
  Future<void> deleteDraft(String draftId) {
    return _client.from('drop_drafts').delete().eq('id', draftId);
  }
}
