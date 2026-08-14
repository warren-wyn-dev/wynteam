import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/data/drop_comment.dart';
import 'package:wyn/features/drop/data/drop_repository.dart';

/// A DropRepository whose network-touching methods are overridden to just
/// record what they were called with, instead of making a real Supabase
/// call. Mirrors RecordingPostRepository (WYN-004) -- see
/// .wyn/learning/PATTERNS.md.
class RecordingDropRepository extends DropRepository {
  RecordingDropRepository({List<Drop>? feedDrops, List<DropComment>? comments})
      : feedDrops = feedDrops ?? [],
        comments = comments ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchFeed] for page 0 only (page 1+ returns empty).
  final List<Drop> feedDrops;

  /// Returned by [fetchComments], regardless of dropId.
  final List<DropComment> comments;

  int toggleLikeCalls = 0;
  int toggleSaveCalls = 0;
  int toggleCommentLikeCalls = 0;
  final List<bool> toggleLikeCurrentlyLikedArgs = [];
  final List<bool> toggleCommentLikeCurrentlyLikedArgs = [];
  final List<String> deleteCommentCalls = [];

  @override
  Future<List<Drop>> fetchFeed({required int page}) async {
    return page == 0 ? feedDrops : <Drop>[];
  }

  /// Returned by [fetchByAuthor] for page 0 only, filtered by [authorId]
  /// against [feedDrops] (unlike [fetchFeed], which ignores authorship).
  @override
  Future<List<Drop>> fetchByAuthor({
    required String authorId,
    required int page,
  }) async {
    if (page != 0) return [];
    return feedDrops.where((d) => d.authorId == authorId).toList();
  }

  @override
  Future<void> createDrop({
    required Uint8List imageBytes,
    required String imageExtension,
    required String caption,
  }) async {}

  @override
  Future<void> toggleLike({
    required String dropId,
    required bool currentlyLiked,
  }) async {
    toggleLikeCalls++;
    toggleLikeCurrentlyLikedArgs.add(currentlyLiked);
  }

  @override
  Future<void> toggleSave({
    required String dropId,
    required bool currentlySaved,
  }) async {
    toggleSaveCalls++;
  }

  @override
  Future<void> deleteDrop(String dropId) async {}

  @override
  Future<List<DropComment>> fetchComments(String dropId) async => comments;

  @override
  Future<void> toggleCommentLike({
    required String commentId,
    required bool currentlyLiked,
  }) async {
    toggleCommentLikeCalls++;
    toggleCommentLikeCurrentlyLikedArgs.add(currentlyLiked);
  }

  @override
  Future<void> deleteComment(String commentId) async {
    deleteCommentCalls.add(commentId);
  }
}
