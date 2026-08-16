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
  RecordingDropRepository({
    List<Drop>? feedDrops,
    List<Drop>? followingFeedDrops,
    List<DropComment>? comments,
  })  : feedDrops = feedDrops ?? [],
        followingFeedDrops = followingFeedDrops ?? [],
        comments = comments ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchFeed] for page 0 only (page 1+ returns empty).
  final List<Drop> feedDrops;

  /// Returned by [fetchFollowingFeed] for page 0 only (page 1+ returns
  /// empty) -- WYN-019.
  final List<Drop> followingFeedDrops;

  /// Returned by [fetchComments], regardless of dropId.
  final List<DropComment> comments;

  /// Each call to [createDrop]'s mentionedUserIds argument, in order --
  /// WYN-021.
  final List<Set<String>> createDropMentionedUserIdsArgs = [];

  int toggleLikeCalls = 0;
  int toggleSaveCalls = 0;
  int toggleCommentLikeCalls = 0;
  int searchByCaptionCalls = 0;
  final List<bool> toggleLikeCurrentlyLikedArgs = [];
  final List<bool> toggleCommentLikeCurrentlyLikedArgs = [];
  final List<String> deleteCommentCalls = [];
  final List<String> searchByCaptionQueryArgs = [];

  @override
  Future<List<Drop>> fetchFeed({required int page}) async {
    return page == 0 ? feedDrops : <Drop>[];
  }

  @override
  Future<List<Drop>> fetchFollowingFeed({required int page}) async {
    return page == 0 ? followingFeedDrops : <Drop>[];
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

  /// Looks [dropId] up in [feedDrops]; returns null if not present
  /// (mirrors the real fetchById's "deleted content" null case).
  @override
  Future<Drop?> fetchById(String dropId) async {
    for (final drop in feedDrops) {
      if (drop.id == dropId) return drop;
    }
    return null;
  }

  /// Returned by [searchByCaption] for page 0 only, filtered by whether
  /// [feedDrops] caption contains [query] (case insensitive) -- same
  /// "reuse feedDrops as the fake dataset" approach as [fetchByAuthor].
  @override
  Future<List<Drop>> searchByCaption({
    required String query,
    required int page,
  }) async {
    searchByCaptionCalls++;
    searchByCaptionQueryArgs.add(query);
    if (page != 0) return [];
    final lowerQuery = query.toLowerCase();
    return feedDrops
        .where((d) => (d.caption ?? '').toLowerCase().contains(lowerQuery))
        .toList();
  }

  @override
  Future<void> createDrop({
    required Uint8List imageBytes,
    required String imageExtension,
    required String caption,
    Set<String> mentionedUserIds = const {},
  }) async {
    createDropMentionedUserIdsArgs.add(mentionedUserIds);
  }

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
