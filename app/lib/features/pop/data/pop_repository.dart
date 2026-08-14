import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import 'pop.dart';
import 'pop_comment.dart';

const _authorSelect = 'author:profiles(username, display_name, avatar_url)';
const _savesContentType = 'pop';

/// Wraps the `pops`/`pop_likes`/`pop_comments`/`saves` reads/writes and
/// pop-video storage needed for WYN-006 (Pop). See supabase/schema.sql for
/// the RLS policies this relies on. Mirrors DropRepository (WYN-005)
/// field-for-field.
class PopRepository {
  PopRepository(this._client);

  final SupabaseClient _client;

  // Feed is a single-column vertical swipe (not a grid), so there's no
  // multiple-of-N sizing concern like Drop's grid page size.
  static const pageSize = 10;

  /// Fetches one page (0-indexed) of the Pop feed, newest first.
  Future<List<Pop>> fetchFeed({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('pops')
        .select('*, $_authorSelect, pop_likes(count), pop_comments(count)')
        .order('created_at', ascending: false)
        .range(from, to);

    final popIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedPopIds(userId: userId, popIds: popIds);
    final savedIds = await _fetchSavedPopIds(userId: userId, popIds: popIds);

    return rows
        .map((row) => Pop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
            ))
        .toList();
  }

  /// Fetches one page (0-indexed) of Pops by a single author, newest
  /// first -- for the Pop grid tab on that author's profile (WYN-013).
  /// A separate method from [fetchFeed] (global, unfiltered) so the
  /// existing Pop Feed query stays untouched.
  Future<List<Pop>> fetchByAuthor({
    required String authorId,
    required int page,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('pops')
        .select('*, $_authorSelect, pop_likes(count), pop_comments(count)')
        .eq('author_id', authorId)
        .order('created_at', ascending: false)
        .range(from, to);

    final popIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedPopIds(userId: userId, popIds: popIds);
    final savedIds = await _fetchSavedPopIds(userId: userId, popIds: popIds);

    return rows
        .map((row) => Pop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
            ))
        .toList();
  }

  /// Fetches one page (0-indexed) of Pops whose caption contains [query]
  /// (case insensitive), newest first -- for WYN-009 Search's Pop tab.
  Future<List<Pop>> searchByCaption({
    required String query,
    required int page,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('pops')
        .select('*, $_authorSelect, pop_likes(count), pop_comments(count)')
        .ilike('caption', '%$query%')
        .order('created_at', ascending: false)
        .range(from, to);

    final popIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedPopIds(userId: userId, popIds: popIds);
    final savedIds = await _fetchSavedPopIds(userId: userId, popIds: popIds);

    return rows
        .map((row) => Pop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
            ))
        .toList();
  }

  /// Fetches a single Pop by id, with a fresh likedByMe/savedByMe for the
  /// current user -- for opening a Pop referenced by a notification
  /// (WYN-012), where only the id is known, not a full Pop object.
  /// Returns null if the Pop no longer exists (e.g. deleted since the
  /// notification was created).
  Future<Pop?> fetchById(String popId) async {
    final userId = _client.auth.currentUser!.id;

    final row = await _client
        .from('pops')
        .select('*, $_authorSelect, pop_likes(count), pop_comments(count)')
        .eq('id', popId)
        .maybeSingle();
    if (row == null) return null;

    final likedIds = await _fetchLikedPopIds(userId: userId, popIds: [popId]);
    final savedIds = await _fetchSavedPopIds(userId: userId, popIds: [popId]);

    return Pop.fromMap(
      row,
      likedByMe: likedIds.contains(popId),
      savedByMe: savedIds.contains(popId),
    );
  }

  Future<Set<String>> _fetchLikedPopIds({
    required String userId,
    required List<String> popIds,
  }) async {
    if (popIds.isEmpty) return {};

    final rows = await _client
        .from('pop_likes')
        .select('pop_id')
        .eq('user_id', userId)
        .inFilter('pop_id', popIds);

    return rows.map((row) => row['pop_id'] as String).toSet();
  }

  Future<Set<String>> _fetchSavedPopIds({
    required String userId,
    required List<String> popIds,
  }) async {
    if (popIds.isEmpty) return {};

    final rows = await _client
        .from('saves')
        .select('content_id')
        .eq('user_id', userId)
        .eq('content_type', _savesContentType)
        .inFilter('content_id', popIds);

    return rows.map((row) => row['content_id'] as String).toSet();
  }

  /// Creates a Pop. [videoBytes] is required -- a Pop is always a video,
  /// the same way a Drop is always a photo. [thumbnailBytes] is optional
  /// (thumbnail generation can fail on some source videos -- see
  /// CreatePopScreen); a null thumbnail just means the feed falls back to
  /// a plain placeholder until the video itself loads.
  Future<void> createPop({
    required Uint8List videoBytes,
    required String videoExtension,
    required Uint8List? thumbnailBytes,
    required int durationSeconds,
    required String caption,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final baseName = DateTime.now().millisecondsSinceEpoch;

    final videoPath = '$userId/$baseName.$videoExtension';
    await _client.storage
        .from('pop-videos')
        .uploadBinary(videoPath, videoBytes);
    final videoUrl = _client.storage.from('pop-videos').getPublicUrl(videoPath);

    String? thumbnailUrl;
    if (thumbnailBytes != null) {
      final thumbnailPath = '$userId/thumb_$baseName.jpg';
      await _client.storage
          .from('pop-videos')
          .uploadBinary(thumbnailPath, thumbnailBytes);
      thumbnailUrl =
          _client.storage.from('pop-videos').getPublicUrl(thumbnailPath);
    }

    await _client.from('pops').insert({
      'author_id': userId,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'duration_seconds': durationSeconds,
      'caption': normalizeOptionalText(caption.trim()),
    });
  }

  Future<void> deletePop(String popId) {
    return _client.from('pops').delete().eq('id', popId);
  }

  Future<void> toggleLike({
    required String popId,
    required bool currentlyLiked,
  }) async {
    final userId = _client.auth.currentUser!.id;
    if (currentlyLiked) {
      await _client
          .from('pop_likes')
          .delete()
          .eq('pop_id', popId)
          .eq('user_id', userId);
    } else {
      await _client
          .from('pop_likes')
          .insert({'pop_id': popId, 'user_id': userId});
    }
  }

  Future<void> toggleSave({
    required String popId,
    required bool currentlySaved,
  }) async {
    final userId = _client.auth.currentUser!.id;
    if (currentlySaved) {
      await _client
          .from('saves')
          .delete()
          .eq('user_id', userId)
          .eq('content_type', _savesContentType)
          .eq('content_id', popId);
    } else {
      await _client.from('saves').insert({
        'user_id': userId,
        'content_type': _savesContentType,
        'content_id': popId,
      });
    }
  }

  /// Records a view via a security-definer RPC (rather than a direct
  /// client update to `pops.view_count`) so a user can't set an arbitrary
  /// count -- see supabase/schema.sql's increment_pop_view_count().
  Future<void> recordView(String popId) {
    return _client.rpc('increment_pop_view_count', params: {'pop_id': popId});
  }

  /// Oldest first, unlike the feed -- comments read top-to-bottom like a
  /// conversation.
  Future<List<PopComment>> fetchComments(String popId) async {
    final userId = _client.auth.currentUser!.id;

    final rows = await _client
        .from('pop_comments')
        .select('*, $_authorSelect, pop_comment_likes(count)')
        .eq('pop_id', popId)
        .order('created_at', ascending: true);

    final commentIds = rows.map((row) => row['id'] as String).toList();
    final likedIds =
        await _fetchLikedCommentIds(userId: userId, commentIds: commentIds);

    return rows
        .map((row) => PopComment.fromMap(
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
        .from('pop_comment_likes')
        .select('comment_id')
        .eq('user_id', userId)
        .inFilter('comment_id', commentIds);

    return rows.map((row) => row['comment_id'] as String).toSet();
  }

  Future<PopComment> addComment({
    required String popId,
    required String textContent,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final row = await _client
        .from('pop_comments')
        .insert({
          'pop_id': popId,
          'author_id': userId,
          'text_content': textContent.trim(),
        })
        .select('*, $_authorSelect')
        .single();

    // A freshly-created comment can't have any likes yet -- no need for a
    // count/liked lookup like fetchComments does.
    return PopComment.fromMap(row, likedByMe: false);
  }

  Future<void> toggleCommentLike({
    required String commentId,
    required bool currentlyLiked,
  }) async {
    final userId = _client.auth.currentUser!.id;
    if (currentlyLiked) {
      await _client
          .from('pop_comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
    } else {
      await _client
          .from('pop_comment_likes')
          .insert({'comment_id': commentId, 'user_id': userId});
    }
  }

  /// RLS on pop_comments restricts this to the caller's own comments --
  /// no client-side ownership check needed before sending the request,
  /// only before showing the delete affordance in the UI.
  Future<void> deleteComment(String commentId) {
    return _client.from('pop_comments').delete().eq('id', commentId);
  }
}
