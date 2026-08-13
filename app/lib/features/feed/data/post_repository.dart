import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import 'comment.dart';
import 'post.dart';

const _authorSelect = 'author:profiles(username, display_name, avatar_url)';

/// Wraps the `posts`/`likes`/`comments` reads/writes and post-image
/// storage needed for WYN-004 (Feed & Post). See supabase/schema.sql for
/// the RLS policies this relies on.
class PostRepository {
  PostRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 20;

  /// Fetches one page (0-indexed) of the global feed, newest first.
  Future<List<Post>> fetchFeed({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('posts')
        .select('*, $_authorSelect, likes(count), comments(count)')
        .order('created_at', ascending: false)
        .range(from, to);

    final postIds = rows.map((row) => row['id'] as String).toList();
    final likedPostIds = await _fetchLikedPostIds(userId: userId, postIds: postIds);

    return rows
        .map((row) => Post.fromMap(
              row,
              likedByMe: likedPostIds.contains(row['id'] as String),
            ))
        .toList();
  }

  Future<Set<String>> _fetchLikedPostIds({
    required String userId,
    required List<String> postIds,
  }) async {
    if (postIds.isEmpty) return {};

    final rows = await _client
        .from('likes')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', postIds);

    return rows.map((row) => row['post_id'] as String).toSet();
  }

  /// Creates a post. [textContent] may be empty (sent as null) if
  /// [imageBytes] is provided instead -- posts_have_content in
  /// supabase/schema.sql requires at least one of the two.
  Future<void> createPost({
    required String textContent,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final userId = _client.auth.currentUser!.id;
    String? imageUrl;

    if (imageBytes != null) {
      // Unlike avatars (one fixed filename per user), each post image gets
      // a unique filename since posts are never edited -- no need for
      // upsert or cache-busting query params.
      final path =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.${imageExtension ?? 'jpg'}';
      await _client.storage.from('post-images').uploadBinary(path, imageBytes);
      imageUrl = _client.storage.from('post-images').getPublicUrl(path);
    }

    await _client.from('posts').insert({
      'author_id': userId,
      'text_content': normalizeOptionalText(textContent.trim()),
      'image_url': imageUrl,
    });
  }

  Future<void> deletePost(String postId) {
    return _client.from('posts').delete().eq('id', postId);
  }

  Future<void> toggleLike({
    required String postId,
    required bool currentlyLiked,
  }) async {
    final userId = _client.auth.currentUser!.id;
    if (currentlyLiked) {
      await _client.from('likes').delete().eq('post_id', postId).eq('user_id', userId);
    } else {
      await _client.from('likes').insert({'post_id': postId, 'user_id': userId});
    }
  }

  /// Oldest first, unlike the feed -- comments read top-to-bottom like a
  /// conversation.
  Future<List<Comment>> fetchComments(String postId) async {
    final rows = await _client
        .from('comments')
        .select('*, $_authorSelect')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return rows.map(Comment.fromMap).toList();
  }

  Future<Comment> addComment({
    required String postId,
    required String textContent,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final row = await _client
        .from('comments')
        .insert({
          'post_id': postId,
          'author_id': userId,
          'text_content': textContent.trim(),
        })
        .select('*, $_authorSelect')
        .single();

    return Comment.fromMap(row);
  }
}
