import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/feed/data/comment.dart';
import 'package:wyn/features/feed/data/post.dart';
import 'package:wyn/features/feed/data/post_repository.dart';

/// A PostRepository whose network-touching methods are overridden to just
/// record what they were called with, instead of making a real Supabase
/// call. PostRepository has no abstract interface, but its methods are
/// ordinary (non-final) instance methods, so a plain subclass is enough
/// to make it testable without a broader DI refactor. Used to regression-
/// test the WYN-004 QA round 1 double-tap bug (see
/// .wyn/tasks/bugs/WYN-004-feed-and-post.md), where the defect was
/// specifically about *which arguments* a rapid double-tap sends.
class RecordingPostRepository extends PostRepository {
  RecordingPostRepository({List<Post>? feedPosts})
      : feedPosts = feedPosts ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchFeed] for page 0 only (page 1+ returns empty, so
  /// FeedScreen's infinite-scroll doesn't keep requesting more).
  final List<Post> feedPosts;

  int createPostCalls = 0;
  int toggleLikeCalls = 0;
  final List<bool> toggleLikeCurrentlyLikedArgs = [];

  @override
  Future<List<Post>> fetchFeed({required int page}) async {
    return page == 0 ? feedPosts : <Post>[];
  }

  @override
  Future<void> createPost({
    required String textContent,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    createPostCalls++;
  }

  @override
  Future<void> toggleLike({
    required String postId,
    required bool currentlyLiked,
  }) async {
    toggleLikeCalls++;
    toggleLikeCurrentlyLikedArgs.add(currentlyLiked);
  }

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<List<Comment>> fetchComments(String postId) async => [];
}
