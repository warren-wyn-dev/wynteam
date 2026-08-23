import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/data/drop_comment.dart';
import 'package:wyn/features/drop/data/drop_draft.dart';
import 'package:wyn/features/drop/data/drop_repository.dart';

/// A DropRepository whose network-touching methods are overridden to just
/// record what they were called with, instead of making a real Supabase
/// call. Mirrors RecordingPostRepository (WYN-004) -- see
/// .wyn/learning/PATTERNS.md.
class RecordingDropRepository extends DropRepository {
  RecordingDropRepository({
    List<Drop>? feedDrops,
    List<Drop>? followingFeedDrops,
    List<Drop>? rankedFeedDrops,
    List<DropComment>? comments,
  })  : feedDrops = feedDrops ?? [],
        followingFeedDrops = followingFeedDrops ?? [],
        // Defaults to the same list as feedDrops -- see
        // RecordingHomeRepository's identical rationale (WYN-018): most
        // call sites predating this follow-up only care that "the feed
        // shows these drops", not which of the two queries served them.
        rankedFeedDrops = rankedFeedDrops ?? feedDrops ?? [],
        comments = comments ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchFeed] for page 0 only (page 1+ returns empty).
  final List<Drop> feedDrops;

  /// Returned by [fetchFollowingFeed] for page 0 only (page 1+ returns
  /// empty) -- WYN-019.
  final List<Drop> followingFeedDrops;

  /// Returned by [fetchRankedFeed] for page 0 only (page 1+ returns
  /// empty) -- WYN-018 follow-up. Defaults to the same list as
  /// [feedDrops] unless given explicitly.
  final List<Drop> rankedFeedDrops;

  int fetchRankedFeedCalls = 0;

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

  @override
  Future<List<Drop>> fetchRankedFeed({required int page}) async {
    fetchRankedFeedCalls++;
    return page == 0 ? rankedFeedDrops : <Drop>[];
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

  /// Each call to [createPollDrop], in order -- WYN-035.
  final List<Map<String, Object?>> createPollDropArgs = [];
  Object? createPollDropError;

  @override
  Future<void> createPollDrop({
    required String question,
    required List<String> options,
    required int durationDays,
    Set<String> mentionedUserIds = const {},
  }) async {
    if (createPollDropError != null) throw createPollDropError!;
    createPollDropArgs.add({
      'question': question,
      'options': options,
      'durationDays': durationDays,
      'mentionedUserIds': mentionedUserIds,
    });
  }

  /// Each call to [votePoll]'s (pollId, optionIndex), in order -- WYN-035.
  final List<(String, int)> votePollArgs = [];
  Object? votePollError;

  @override
  Future<void> votePoll({
    required String pollId,
    required int optionIndex,
  }) async {
    if (votePollError != null) throw votePollError!;
    votePollArgs.add((pollId, optionIndex));
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

  /// Each call to [deleteDrop] (WYN-037's soft delete), in order.
  final List<String> deleteDropCalls = [];
  Object? deleteDropError;

  @override
  Future<void> deleteDrop(String dropId) async {
    if (deleteDropError != null) throw deleteDropError!;
    deleteDropCalls.add(dropId);
  }

  /// Each call to [restoreDrop], in order -- WYN-037.
  final List<String> restoreDropCalls = [];
  Object? restoreDropError;

  @override
  Future<void> restoreDrop(String dropId) async {
    if (restoreDropError != null) throw restoreDropError!;
    restoreDropCalls.add(dropId);
  }

  /// Each call to [editDrop]'s arguments, in order -- WYN-037.
  final List<Map<String, String>> editDropArgs = [];
  Object? editDropError;

  @override
  Future<void> editDrop({required String dropId, required String caption}) async {
    if (editDropError != null) throw editDropError!;
    editDropArgs.add({'dropId': dropId, 'caption': caption});
  }

  /// Returned by [fetchDeletedDrops] -- WYN-037.
  List<Drop> deletedDropsToReturn = [];
  int fetchDeletedDropsCalls = 0;
  Object? fetchDeletedDropsError;

  @override
  Future<List<Drop>> fetchDeletedDrops() async {
    fetchDeletedDropsCalls++;
    if (fetchDeletedDropsError != null) throw fetchDeletedDropsError!;
    return deletedDropsToReturn;
  }

  @override
  Future<List<DropComment>> fetchComments(String dropId) async => comments;

  int addCommentCalls = 0;
  final List<String?> addCommentParentIdArgs = [];

  @override
  Future<DropComment> addComment({
    required String dropId,
    required String textContent,
    String? parentCommentId,
  }) async {
    addCommentCalls++;
    addCommentParentIdArgs.add(parentCommentId);
    return DropComment(
      id: 'new-comment-$addCommentCalls',
      dropId: dropId,
      authorId: 'me',
      authorUsername: 'me',
      textContent: textContent,
      createdAt: DateTime.now(),
      likeCount: 0,
      likedByMe: false,
      parentCommentId: parentCommentId,
    );
  }

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

  int toggleRedropCalls = 0;
  final List<bool> toggleRedropCurrentlyRedroppedArgs = [];

  @override
  Future<void> toggleRedrop({
    required String dropId,
    required bool currentlyRedropped,
  }) async {
    toggleRedropCalls++;
    toggleRedropCurrentlyRedroppedArgs.add(currentlyRedropped);
  }

  int quoteRedropCalls = 0;
  final List<String> quoteRedropTextArgs = [];
  Object? quoteRedropError;

  @override
  Future<void> quoteRedrop({
    required String dropId,
    required String quoteText,
  }) async {
    if (quoteRedropError != null) throw quoteRedropError!;
    quoteRedropCalls++;
    quoteRedropTextArgs.add(quoteText);
  }

  final List<String> deleteRedropCalls = [];

  @override
  Future<void> deleteRedrop(String redropId) async {
    deleteRedropCalls.add(redropId);
  }

  /// Returned by [fetchDrafts] -- WYN-036.
  List<DropDraft> draftsToReturn = [];
  int fetchDraftsCalls = 0;
  Object? fetchDraftsError;

  @override
  Future<List<DropDraft>> fetchDrafts() async {
    fetchDraftsCalls++;
    if (fetchDraftsError != null) throw fetchDraftsError!;
    return draftsToReturn;
  }

  /// Each call to [saveDraft]'s arguments, in order -- WYN-036.
  final List<Map<String, Object?>> saveDraftArgs = [];
  Object? saveDraftError;

  /// Returned by [saveDraft] when called with a null `draftId` (a
  /// brand-new draft being inserted for the first time).
  String saveDraftReturnsId = 'new-draft-id';

  @override
  Future<String> saveDraft({
    String? draftId,
    Uint8List? imageBytes,
    String imageExtension = 'jpg',
    String? existingImageUrl,
    String? caption,
    List<String>? pollOptions,
    int? pollDurationDays,
  }) async {
    if (saveDraftError != null) throw saveDraftError!;
    saveDraftArgs.add({
      'draftId': draftId,
      'imageBytes': imageBytes,
      'existingImageUrl': existingImageUrl,
      'caption': caption,
      'pollOptions': pollOptions,
      'pollDurationDays': pollDurationDays,
    });
    return draftId ?? saveDraftReturnsId;
  }

  final List<String> deleteDraftCalls = [];
  Object? deleteDraftError;

  @override
  Future<void> deleteDraft(String draftId) async {
    if (deleteDraftError != null) throw deleteDraftError!;
    deleteDraftCalls.add(draftId);
  }

  /// Each call to [createDropFromExistingImage]'s arguments, in order
  /// -- WYN-036 (publishing a Draft without picking a new image).
  final List<Map<String, Object?>> createDropFromExistingImageArgs = [];
  Object? createDropFromExistingImageError;

  @override
  Future<void> createDropFromExistingImage({
    required String imageUrl,
    required String caption,
    Set<String> mentionedUserIds = const {},
  }) async {
    if (createDropFromExistingImageError != null) {
      throw createDropFromExistingImageError!;
    }
    createDropFromExistingImageArgs.add({
      'imageUrl': imageUrl,
      'caption': caption,
      'mentionedUserIds': mentionedUserIds,
    });
  }
}
