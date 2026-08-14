import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/club/data/club_post.dart';
import 'package:wyn/features/club/data/club_post_comment.dart';
import 'package:wyn/features/club/data/club_post_repository.dart';

/// A ClubPostRepository whose network-touching methods are overridden to
/// just record what they were called with / return canned data, instead
/// of making a real Supabase call. Mirrors RecordingDropRepository -- see
/// .wyn/learning/PATTERNS.md.
class RecordingClubPostRepository extends ClubPostRepository {
  RecordingClubPostRepository({
    List<ClubPost>? posts,
    List<ClubPostComment>? comments,
  })  : posts = posts ?? [],
        comments = comments ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchPosts] for page 0 only (page 1+ returns empty).
  final List<ClubPost> posts;

  /// Returned by [fetchComments].
  final List<ClubPostComment> comments;

  int createPostCalls = 0;
  int deletePostCalls = 0;
  final List<String> deletePostIdArgs = [];
  int toggleLikeCalls = 0;
  int toggleSaveCalls = 0;
  int togglePinCalls = 0;
  final List<bool> togglePinCurrentlyPinnedArgs = [];
  int addCommentCalls = 0;
  int deleteCommentCalls = 0;

  @override
  Future<List<ClubPost>> fetchPosts({required String clubId, required int page}) async {
    return page == 0 ? posts : <ClubPost>[];
  }

  @override
  Future<void> createPost({
    required String clubId,
    String? content,
    List<Uint8List>? images,
    List<String>? imageExtensions,
    String? linkUrl,
  }) async {
    createPostCalls++;
  }

  @override
  Future<void> deletePost(String postId) async {
    deletePostCalls++;
    deletePostIdArgs.add(postId);
  }

  @override
  Future<void> togglePin({required String postId, required bool currentlyPinned}) async {
    togglePinCalls++;
    togglePinCurrentlyPinnedArgs.add(currentlyPinned);
  }

  @override
  Future<void> toggleLike({required String postId, required bool currentlyLiked}) async {
    toggleLikeCalls++;
  }

  @override
  Future<void> toggleSave({required String postId, required bool currentlySaved}) async {
    toggleSaveCalls++;
  }

  @override
  Future<List<ClubPostComment>> fetchComments(String postId) async => comments;

  @override
  Future<ClubPostComment> addComment({
    required String postId,
    required String textContent,
  }) async {
    addCommentCalls++;
    return ClubPostComment(
      id: 'new-comment-$addCommentCalls',
      clubPostId: postId,
      authorId: 'me',
      authorUsername: 'me',
      textContent: textContent,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteComment(String commentId) async {
    deleteCommentCalls++;
  }
}
