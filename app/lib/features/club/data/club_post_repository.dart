import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import 'club_post.dart';
import 'club_post_comment.dart';

// See DropRepository's identical comment for why this needs the exact
// foreign key name -- PostgREST can't resolve a bare `profiles(...)`
// embed when a sibling embed (club_post_likes/club_post_comments) also
// has a path to profiles. Discovered 2026-08-16 running against a real
// database; every widget test uses RecordingClubPostRepository, which
// never sends a real PostgREST query. club_post_comments has no
// separate "comment likes" table (unlike Drop/Pop), so
// _commentAuthorSelect isn't currently ambiguous on its own, but is
// qualified anyway for consistency and to stay safe if that ever
// changes.
const _postAuthorSelect =
    'author:profiles!club_posts_author_id_fkey(username, display_name, avatar_url)';
const _commentAuthorSelect =
    'author:profiles!club_post_comments_author_id_fkey(username, display_name, avatar_url)';
const _savesContentType = 'club_post';

/// Wraps the `club_posts`/`club_post_likes`/`club_post_comments` reads/
/// writes and club-media (post image) storage needed for WYN-014 (Club
/// Core). Mirrors DropRepository wherever the shape matches. See
/// supabase/schema.sql for the RLS policies this relies on.
class ClubPostRepository {
  ClubPostRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 20;
  static const _bucket = 'club-media';
  // Same private-bucket / sign-on-read reasoning as ClubRepository -- see
  // that file's _signedUrlTtlSeconds comment.
  static const _signedUrlTtlSeconds = 3600;

  Future<String?> _signedUrl(String path) async {
    try {
      return await _client.storage.from(_bucket).createSignedUrl(
            path,
            _signedUrlTtlSeconds,
          );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _withSignedImageUrls(
    Map<String, dynamic> row,
  ) async {
    final rawPaths = row['image_urls'] as List<dynamic>?;
    if (rawPaths == null) return row;
    final signed = await Future.wait(
      rawPaths.map((path) => _signedUrl(path as String)),
    );
    return {...row, 'image_urls': signed.whereType<String>().toList()};
  }

  /// Pinned posts first, then newest first within each group -- the
  /// Design spec's "ปักหมุดเรียงบนสุดเสมอ" rule for the Posts tab.
  Future<List<ClubPost>> fetchPosts({
    required String clubId,
    required int page,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('club_posts')
        .select(
          '*, $_postAuthorSelect, club_post_likes(count), club_post_comments(count)',
        )
        .eq('club_id', clubId)
        .order('pinned', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);

    final postIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedPostIds(userId: userId, postIds: postIds);
    final savedIds = await _fetchSavedPostIds(userId: userId, postIds: postIds);

    final posts = <ClubPost>[];
    for (final row in rows) {
      final signedRow = await _withSignedImageUrls(row);
      posts.add(ClubPost.fromMap(
        signedRow,
        likedByMe: likedIds.contains(row['id'] as String),
        savedByMe: savedIds.contains(row['id'] as String),
      ));
    }
    return posts;
  }

  /// Every club_post the current user can see (RLS on club_posts already
  /// restricts this to approved members of whichever club each row
  /// belongs to -- see supabase/schema.sql), across all joined clubs at
  /// once. No `club_id` filter needed: querying without one naturally
  /// scopes to every club the user is an approved member of, which is
  /// exactly WYN-015's "จาก Club ของคุณ" Home tab, without a new DB view.
  Future<List<ClubPost>> fetchFromJoinedClubs({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('club_posts')
        .select(
          '*, $_postAuthorSelect, club_post_likes(count), club_post_comments(count)',
        )
        .order('created_at', ascending: false)
        .range(from, to);

    final postIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedPostIds(userId: userId, postIds: postIds);
    final savedIds = await _fetchSavedPostIds(userId: userId, postIds: postIds);

    final posts = <ClubPost>[];
    for (final row in rows) {
      final signedRow = await _withSignedImageUrls(row);
      posts.add(ClubPost.fromMap(
        signedRow,
        likedByMe: likedIds.contains(row['id'] as String),
        savedByMe: savedIds.contains(row['id'] as String),
      ));
    }
    return posts;
  }

  /// Fetches one page (0-indexed) of club posts whose content contains
  /// [query] (case insensitive), newest first -- for WYN-020's Hashtag
  /// Feed (mirrors DropRepository.searchByCaption's shape). No explicit
  /// visibility filter needed: club_posts' own RLS already restricts
  /// this to posts the caller can actually see, same guarantee
  /// [fetchFromJoinedClubs] already relies on.
  Future<List<ClubPost>> searchByContent({
    required String query,
    required int page,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('club_posts')
        .select(
          '*, $_postAuthorSelect, club_post_likes(count), club_post_comments(count)',
        )
        .ilike('content', '%$query%')
        .order('created_at', ascending: false)
        .range(from, to);

    final postIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedPostIds(userId: userId, postIds: postIds);
    final savedIds = await _fetchSavedPostIds(userId: userId, postIds: postIds);

    final posts = <ClubPost>[];
    for (final row in rows) {
      final signedRow = await _withSignedImageUrls(row);
      posts.add(ClubPost.fromMap(
        signedRow,
        likedByMe: likedIds.contains(row['id'] as String),
        savedByMe: savedIds.contains(row['id'] as String),
      ));
    }
    return posts;
  }

  /// Fetches a single club post by id, with a fresh likedByMe/savedByMe
  /// for the current user -- for opening a club post referenced by a
  /// notification (WYN-015), where only the id is known. Returns null
  /// if the post no longer exists (e.g. deleted since the notification
  /// was created) or RLS hides it (e.g. the user has since left the
  /// club). Mirrors DropRepository.fetchById/PopRepository.fetchById
  /// (WYN-012).
  Future<ClubPost?> fetchById(String postId) async {
    final userId = _client.auth.currentUser!.id;

    final row = await _client
        .from('club_posts')
        .select(
          '*, $_postAuthorSelect, club_post_likes(count), club_post_comments(count)',
        )
        .eq('id', postId)
        .maybeSingle();
    if (row == null) return null;

    final likedIds = await _fetchLikedPostIds(userId: userId, postIds: [postId]);
    final savedIds = await _fetchSavedPostIds(userId: userId, postIds: [postId]);
    final signedRow = await _withSignedImageUrls(row);

    return ClubPost.fromMap(
      signedRow,
      likedByMe: likedIds.contains(postId),
      savedByMe: savedIds.contains(postId),
    );
  }

  Future<Set<String>> _fetchLikedPostIds({
    required String userId,
    required List<String> postIds,
  }) async {
    if (postIds.isEmpty) return {};

    final rows = await _client
        .from('club_post_likes')
        .select('club_post_id')
        .eq('user_id', userId)
        .inFilter('club_post_id', postIds);

    return rows.map((row) => row['club_post_id'] as String).toSet();
  }

  Future<Set<String>> _fetchSavedPostIds({
    required String userId,
    required List<String> postIds,
  }) async {
    if (postIds.isEmpty) return {};

    final rows = await _client
        .from('saves')
        .select('content_id')
        .eq('user_id', userId)
        .eq('content_type', _savesContentType)
        .inFilter('content_id', postIds);

    return rows.map((row) => row['content_id'] as String).toSet();
  }

  /// At least one of [content]/[images]/[linkUrl] must be non-empty --
  /// enforced both here (club_posts_have_content) and by the Create Post
  /// screen's disabled button state. Images are uploaded to a
  /// user+timestamp-disambiguated path *before* the post row is inserted
  /// (rather than after, keyed by the new post's id) so an images-only
  /// post's single insert already has non-null image_urls and never
  /// trips the have-content CHECK on an intermediate empty row.
  /// [mentionedUserIds] (WYN-021): same "already resolved by MentionInput,
  /// not re-parsed server-side" approach as DropRepository.createDrop.
  Future<void> createPost({
    required String clubId,
    String? content,
    List<Uint8List>? images,
    List<String>? imageExtensions,
    String? linkUrl,
    Set<String> mentionedUserIds = const {},
  }) async {
    final userId = _client.auth.currentUser!.id;

    List<String>? imagePaths;
    if (images != null && images.isNotEmpty) {
      imagePaths = [];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < images.length; i++) {
        final extension = imageExtensions![i];
        final path = '$clubId/posts/$userId-$timestamp-$i.$extension';
        await _client.storage.from(_bucket).uploadBinary(path, images[i]);
        imagePaths.add(path);
      }
    }

    final row = await _client
        .from('club_posts')
        .insert({
          'club_id': clubId,
          'author_id': userId,
          'content': normalizeOptionalText((content ?? '').trim()),
          'image_urls': imagePaths,
          'link_url': normalizeOptionalText((linkUrl ?? '').trim()),
        })
        .select('id')
        .single();

    if (mentionedUserIds.isNotEmpty) {
      final postId = row['id'] as String;
      await _client.from('club_post_mentions').insert([
        for (final mentionedId in mentionedUserIds)
          {'club_post_id': postId, 'mentioned_user_id': mentionedId},
      ]);
    }
  }

  Future<void> deletePost(String postId) {
    return _client.from('club_posts').delete().eq('id', postId);
  }

  Future<void> togglePin({
    required String postId,
    required bool currentlyPinned,
  }) {
    return _client
        .from('club_posts')
        .update({'pinned': !currentlyPinned}).eq('id', postId);
  }

  Future<void> toggleLike({
    required String postId,
    required bool currentlyLiked,
  }) async {
    final userId = _client.auth.currentUser!.id;
    if (currentlyLiked) {
      await _client
          .from('club_post_likes')
          .delete()
          .eq('club_post_id', postId)
          .eq('user_id', userId);
    } else {
      await _client
          .from('club_post_likes')
          .insert({'club_post_id': postId, 'user_id': userId});
    }
  }

  Future<void> toggleSave({
    required String postId,
    required bool currentlySaved,
  }) async {
    final userId = _client.auth.currentUser!.id;
    if (currentlySaved) {
      await _client
          .from('saves')
          .delete()
          .eq('user_id', userId)
          .eq('content_type', _savesContentType)
          .eq('content_id', postId);
    } else {
      await _client.from('saves').insert({
        'user_id': userId,
        'content_type': _savesContentType,
        'content_id': postId,
      });
    }
  }

  /// Oldest first, like DropRepository.fetchComments -- reads
  /// top-to-bottom like a conversation.
  Future<List<ClubPostComment>> fetchComments(String postId) async {
    final rows = await _client
        .from('club_post_comments')
        .select('*, $_commentAuthorSelect')
        .eq('club_post_id', postId)
        .order('created_at', ascending: true);

    return rows.map((row) => ClubPostComment.fromMap(row)).toList();
  }

  Future<ClubPostComment> addComment({
    required String postId,
    required String textContent,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final row = await _client
        .from('club_post_comments')
        .insert({
          'club_post_id': postId,
          'author_id': userId,
          'text_content': textContent.trim(),
        })
        .select('*, $_commentAuthorSelect')
        .single();

    return ClubPostComment.fromMap(row);
  }

  /// RLS on club_post_comments restricts this to the caller's own
  /// comments -- no client-side ownership check needed before sending
  /// the request, only before showing the delete affordance in the UI.
  Future<void> deleteComment(String commentId) {
    return _client.from('club_post_comments').delete().eq('id', commentId);
  }
}
