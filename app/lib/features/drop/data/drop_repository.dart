import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import '../../home/data/home_feed_item.dart';
import '../../home/data/home_ranking.dart';
import 'drop.dart';
import 'drop_comment.dart';

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
        .select('*, $_dropAuthorSelect, drop_likes(count), drop_comments(count), redrops(count)')
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: dropIds);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: dropIds);
    final redroppedIds =
        await _fetchRedroppedDropIds(userId: userId, dropIds: dropIds);

    return rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
              redroppedByMe: redroppedIds.contains(row['id'] as String),
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
        .select('*, $_dropAuthorSelect, drop_likes(count), drop_comments(count), redrops(count)')
        .ilike('caption', '%$query%')
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: dropIds);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: dropIds);
    final redroppedIds =
        await _fetchRedroppedDropIds(userId: userId, dropIds: dropIds);

    return rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
              redroppedByMe: redroppedIds.contains(row['id'] as String),
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
        .select('*, $_dropAuthorSelect, drop_likes(count), drop_comments(count), redrops(count)')
        .eq('author_id', authorId)
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: dropIds);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: dropIds);
    final redroppedIds =
        await _fetchRedroppedDropIds(userId: userId, dropIds: dropIds);

    return rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
              redroppedByMe: redroppedIds.contains(row['id'] as String),
            ))
        .toList();
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
        .select('*, $_dropAuthorSelect, drop_likes(count), drop_comments(count), redrops(count)')
        .inFilter('author_id', followingIds)
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: dropIds);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: dropIds);
    final redroppedIds =
        await _fetchRedroppedDropIds(userId: userId, dropIds: dropIds);

    return rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
              redroppedByMe: redroppedIds.contains(row['id'] as String),
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
        .select('*, $_dropAuthorSelect, drop_likes(count), drop_comments(count), redrops(count)')
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

    final drops = rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
              redroppedByMe: redroppedIds.contains(row['id'] as String),
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
        .select('*, $_dropAuthorSelect, drop_likes(count), drop_comments(count), redrops(count)')
        .eq('id', dropId)
        .maybeSingle();
    if (row == null) return null;

    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: [dropId]);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: [dropId]);
    final redroppedIds =
        await _fetchRedroppedDropIds(userId: userId, dropIds: [dropId]);

    return Drop.fromMap(
      row,
      likedByMe: likedIds.contains(dropId),
      savedByMe: savedIds.contains(dropId),
      redroppedByMe: redroppedIds.contains(dropId),
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

  /// Creates a Drop. [imageBytes] is required -- a Drop is always a photo,
  /// unlike WYN-004's posts where text alone was enough. [mentionedUserIds]
  /// (WYN-021) is the set of user ids MentionInput already resolved while
  /// composing the caption -- inserted into `drop_mentions` right after
  /// the Drop itself, not re-parsed from the caption text server-side.
  Future<void> createDrop({
    required Uint8List imageBytes,
    required String imageExtension,
    required String caption,
    Set<String> mentionedUserIds = const {},
  }) async {
    final userId = _client.auth.currentUser!.id;

    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$imageExtension';
    await _client.storage.from('drop-images').uploadBinary(path, imageBytes);
    final imageUrl = _client.storage.from('drop-images').getPublicUrl(path);

    final row = await _client
        .from('drops')
        .insert({
          'author_id': userId,
          'image_url': imageUrl,
          'caption': normalizeOptionalText(caption.trim()),
        })
        .select('id')
        .single();

    if (mentionedUserIds.isNotEmpty) {
      final dropId = row['id'] as String;
      await _client.from('drop_mentions').insert([
        for (final mentionedId in mentionedUserIds)
          {'drop_id': dropId, 'mentioned_user_id': mentionedId},
      ]);
    }
  }

  Future<void> deleteDrop(String dropId) {
    return _client.from('drops').delete().eq('id', dropId);
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
}
