import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import 'drop.dart';
import 'drop_comment.dart';

const _authorSelect = 'author:profiles(username, display_name, avatar_url)';
const _savesContentType = 'drop';

/// Wraps the `drops`/`drop_likes`/`drop_comments`/`saves` reads/writes and
/// drop-image storage needed for WYN-005 (Drop). See supabase/schema.sql
/// for the RLS policies this relies on.
class DropRepository {
  DropRepository(this._client);

  final SupabaseClient _client;

  // 21 (a multiple of 3) so a full page always fills whole grid rows.
  static const pageSize = 21;

  /// Fetches one page (0-indexed) of the Drop grid, newest first.
  Future<List<Drop>> fetchFeed({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('drops')
        .select('*, $_authorSelect, drop_likes(count), drop_comments(count)')
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: dropIds);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: dropIds);

    return rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
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
        .select('*, $_authorSelect, drop_likes(count), drop_comments(count)')
        .eq('author_id', authorId)
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedDropIds(userId: userId, dropIds: dropIds);
    final savedIds = await _fetchSavedDropIds(userId: userId, dropIds: dropIds);

    return rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: likedIds.contains(row['id'] as String),
              savedByMe: savedIds.contains(row['id'] as String),
            ))
        .toList();
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

  /// Creates a Drop. [imageBytes] is required -- a Drop is always a photo,
  /// unlike WYN-004's posts where text alone was enough.
  Future<void> createDrop({
    required Uint8List imageBytes,
    required String imageExtension,
    required String caption,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$imageExtension';
    await _client.storage.from('drop-images').uploadBinary(path, imageBytes);
    final imageUrl = _client.storage.from('drop-images').getPublicUrl(path);

    await _client.from('drops').insert({
      'author_id': userId,
      'image_url': imageUrl,
      'caption': normalizeOptionalText(caption.trim()),
    });
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

  /// Oldest first, unlike the grid -- comments read top-to-bottom like a
  /// conversation.
  Future<List<DropComment>> fetchComments(String dropId) async {
    final userId = _client.auth.currentUser!.id;

    final rows = await _client
        .from('drop_comments')
        .select('*, $_authorSelect, drop_comment_likes(count)')
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

  Future<DropComment> addComment({
    required String dropId,
    required String textContent,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final row = await _client
        .from('drop_comments')
        .insert({
          'drop_id': dropId,
          'author_id': userId,
          'text_content': textContent.trim(),
        })
        .select('*, $_authorSelect')
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
