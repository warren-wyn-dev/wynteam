import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/pop/data/pop.dart';
import 'package:wyn/features/pop/data/pop_comment.dart';
import 'package:wyn/features/pop/data/pop_repository.dart';

/// A PopRepository whose network-touching methods are overridden to just
/// record what they were called with, instead of making a real Supabase
/// call. Mirrors RecordingDropRepository (WYN-005) -- see
/// .wyn/learning/PATTERNS.md.
class RecordingPopRepository extends PopRepository {
  RecordingPopRepository({List<Pop>? feedPops, List<PopComment>? comments})
      : feedPops = feedPops ?? [],
        comments = comments ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchFeed] for page 0 only (page 1+ returns empty).
  final List<Pop> feedPops;

  /// Returned by [fetchComments], regardless of popId.
  final List<PopComment> comments;

  int toggleLikeCalls = 0;
  int toggleSaveCalls = 0;
  int toggleCommentLikeCalls = 0;
  int recordViewCalls = 0;
  final List<bool> toggleLikeCurrentlyLikedArgs = [];
  final List<bool> toggleCommentLikeCurrentlyLikedArgs = [];
  final List<String> deleteCommentCalls = [];
  final List<String> recordViewArgs = [];

  @override
  Future<List<Pop>> fetchFeed({required int page}) async {
    return page == 0 ? feedPops : <Pop>[];
  }

  @override
  Future<void> createPop({
    required Uint8List videoBytes,
    required String videoExtension,
    required Uint8List? thumbnailBytes,
    required int durationSeconds,
    required String caption,
  }) async {}

  @override
  Future<void> toggleLike({
    required String popId,
    required bool currentlyLiked,
  }) async {
    toggleLikeCalls++;
    toggleLikeCurrentlyLikedArgs.add(currentlyLiked);
  }

  @override
  Future<void> toggleSave({
    required String popId,
    required bool currentlySaved,
  }) async {
    toggleSaveCalls++;
  }

  @override
  Future<void> deletePop(String popId) async {}

  @override
  Future<void> recordView(String popId) async {
    recordViewCalls++;
    recordViewArgs.add(popId);
  }

  @override
  Future<List<PopComment>> fetchComments(String popId) async => comments;

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
