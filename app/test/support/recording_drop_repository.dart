import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/data/drop_comment.dart';
import 'package:wyn/features/drop/data/drop_draft.dart';
import 'package:wyn/features/drop/data/drop_repository.dart';
import 'package:wyn/features/drop/data/square_crop.dart';
import 'package:wyn/features/drop/data/location_result.dart';

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
  int recordViewCalls = 0;
  int searchByCaptionCalls = 0;
  final List<bool> toggleLikeCurrentlyLikedArgs = [];
  final List<bool> toggleCommentLikeCurrentlyLikedArgs = [];
  final List<String> deleteCommentCalls = [];
  final List<String> recordViewArgs = [];
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

  /// Returned by [countByAuthor], keyed by authorId -- defaults to 0 for
  /// any author not present, same "missing key -> harmless default" shape
  /// as [likedDropsByAuthor].
  Map<String, int> dropCountByAuthor = {};

  @override
  Future<int> countByAuthor(String authorId) async =>
      dropCountByAuthor[authorId] ?? 0;

  /// Returned by [fetchLikedByAuthor], keyed by authorId -- WYN-071.
  Map<String, List<Drop>> likedDropsByAuthor = {};
  Object? fetchLikedByAuthorError;

  /// Beta3: how many times [fetchLikedByAuthor] was called -- lets a
  /// test assert that coming back from Detail refreshes one row rather
  /// than reloading the whole tab from page 0.
  int fetchLikedByAuthorCalls = 0;

  /// Beta3: real multi-page results, keyed by authorId -- page N is
  /// `likedDropPagesByAuthor[authorId][N]`. Takes precedence over
  /// [likedDropsByAuthor] (single-page) when an entry exists, so every
  /// existing test keeps its one-page behaviour untouched. Exists so a
  /// test can hand back a page 1 that overlaps page 0, which is what
  /// offset pagination really does when a row is added at the top
  /// mid-scroll.
  Map<String, List<List<Drop>>> likedDropPagesByAuthor = {};

  @override
  Future<List<Drop>> fetchLikedByAuthor({
    required String authorId,
    required int page,
  }) async {
    fetchLikedByAuthorCalls++;
    if (fetchLikedByAuthorError != null) throw fetchLikedByAuthorError!;
    final pages = likedDropPagesByAuthor[authorId];
    if (pages != null) return page < pages.length ? pages[page] : <Drop>[];
    if (page != 0) return [];
    return likedDropsByAuthor[authorId] ?? [];
  }

  /// Returned by [fetchRepliesByAuthor], keyed by authorId -- WYN-071.
  Map<String, List<ProfileReply>> repliesByAuthor = {};
  Object? fetchRepliesByAuthorError;

  @override
  Future<List<ProfileReply>> fetchRepliesByAuthor({
    required String authorId,
    required int page,
  }) async {
    if (fetchRepliesByAuthorError != null) throw fetchRepliesByAuthorError!;
    if (page != 0) return [];
    return repliesByAuthor[authorId] ?? [];
  }

  /// Beta3: how many times [fetchById] was called, and what to hand
  /// back instead of the [feedDrops] lookup -- lets a test assert that
  /// coming back from Detail refreshes exactly the one row it was
  /// showing (and can see that row change), rather than reloading the
  /// whole list.
  int fetchByIdCalls = 0;
  final Map<String, Drop?> fetchByIdResults = {};

  /// Looks [dropId] up in [fetchByIdResults] first, then [feedDrops];
  /// returns null if in neither (mirrors the real fetchById's "deleted
  /// content" null case). A key present in [fetchByIdResults] with a
  /// null value means "deleted" and wins over any [feedDrops] entry.
  @override
  Future<Drop?> fetchById(String dropId) async {
    fetchByIdCalls++;
    if (fetchByIdResults.containsKey(dropId)) return fetchByIdResults[dropId];
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

  /// Each call to [createDrop]'s image count, in order -- WYN-071.
  final List<int> createDropImageCountArgs = [];
  Object? createDropError;

  /// WYN-094: when set, [createDrop] awaits one entry per image (in
  /// order) before firing that image's `onImageUploaded` callback --
  /// lets a test observe progress landing one image at a time by
  /// completing these itself, instead of every image "uploading"
  /// within a single microtask. Left null (the default) so every
  /// pre-existing test that doesn't care about upload progress keeps
  /// working unchanged (all images resolve immediately, in order).
  List<Completer<void>>? imageUploadGate;

  /// Returned by [fetchDropImages], keyed by dropId -- WYN-071.
  Map<String, List<String>> dropImagesById = {};
  Object? fetchDropImagesError;

  /// Beta3: how many times [fetchDropImages] was called -- lets a test
  /// assert that a Drop already carrying its image list (batch-loaded
  /// with the feed page) costs no request of its own.
  int fetchDropImagesCalls = 0;

  @override
  Future<List<String>> fetchDropImages(String dropId) async {
    fetchDropImagesCalls++;
    if (fetchDropImagesError != null) throw fetchDropImagesError!;
    return dropImagesById[dropId] ?? [];
  }

  /// Each call to [createDrop]'s audience argument, in order -- WYN-097.
  final List<AudienceOption> createDropAudienceArgs = [];

  /// Each call to [createDrop]'s location argument, in order -- WYN-098.
  final List<LocationResult?> createDropLocationArgs = [];

  /// Each call to [createDrop]'s aspect-ratio argument, in order --
  /// WYN-109.
  final List<DropAspectRatio> createDropAspectRatioArgs = [];

  @override
  Future<void> createDrop({
    required List<Uint8List> imagesBytes,
    required List<String> imageExtensions,
    required String caption,
    Set<String> mentionedUserIds = const {},
    AudienceOption audience = AudienceOption.everyone,
    Set<String> excludedFriendIds = const {},
    LocationResult? location,
    void Function(int uploaded, int total)? onImageUploaded,
    DropAspectRatio aspectRatio = DropAspectRatio.initial,
  }) async {
    if (createDropError != null) throw createDropError!;
    createDropImageCountArgs.add(imagesBytes.length);
    createDropAspectRatioArgs.add(aspectRatio);
    createDropMentionedUserIdsArgs.add(mentionedUserIds);
    createDropAudienceArgs.add(audience);
    createDropLocationArgs.add(location);
    final gate = imageUploadGate;
    for (var i = 0; i < imagesBytes.length; i++) {
      if (gate != null && i < gate.length) await gate[i].future;
      onImageUploaded?.call(i + 1, imagesBytes.length);
    }
  }

  /// Each call to [createTextDrop]'s arguments, in order -- WYNOS
  /// V1.0.0 Beta requirement 2 (caption-only Drop).
  final List<Map<String, Object?>> createTextDropArgs = [];
  Object? createTextDropError;

  @override
  Future<void> createTextDrop({
    required String caption,
    Set<String> mentionedUserIds = const {},
    AudienceOption audience = AudienceOption.everyone,
    Set<String> excludedFriendIds = const {},
    LocationResult? location,
  }) async {
    if (createTextDropError != null) throw createTextDropError!;
    createTextDropArgs.add({
      'caption': caption,
      'mentionedUserIds': mentionedUserIds,
      'audience': audience,
      'location': location,
    });
  }

  /// Returned by [fetchCaptionsForHashtagSuggestion], regardless of
  /// query -- WYNOS V1.0.0 Beta requirement 7 (hashtag autocomplete).
  List<String> hashtagSuggestionCaptionsToReturn = [];

  @override
  Future<List<String>> fetchCaptionsForHashtagSuggestion(
    String query, {
    int limit = 60,
  }) async {
    return hashtagSuggestionCaptionsToReturn;
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
    AudienceOption audience = AudienceOption.everyone,
    Set<String> excludedFriendIds = const {},
    LocationResult? location,
  }) async {
    if (createPollDropError != null) throw createPollDropError!;
    createPollDropArgs.add({
      'question': question,
      'options': options,
      'durationDays': durationDays,
      'mentionedUserIds': mentionedUserIds,
      'audience': audience,
      'location': location,
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

  Object? toggleLikeError;

  @override
  Future<void> toggleLike({
    required String dropId,
    required bool currentlyLiked,
  }) async {
    toggleLikeCalls++;
    toggleLikeCurrentlyLikedArgs.add(currentlyLiked);
    if (toggleLikeError != null) throw toggleLikeError!;
  }

  Object? toggleSaveError;

  @override
  Future<void> toggleSave({
    required String dropId,
    required bool currentlySaved,
  }) async {
    toggleSaveCalls++;
    if (toggleSaveError != null) throw toggleSaveError!;
  }

  @override
  Future<void> recordView(String dropId) async {
    recordViewCalls++;
    recordViewArgs.add(dropId);
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
  Future<List<DropComment>> fetchComments(String dropId, {int page = 0}) async {
    fetchCommentsPageArgs.add(page);
    // Page 0 returns the canned list; later pages are empty, so a screen
    // under test settles instead of paging forever. A test that needs a
    // real second page overrides this method.
    return page == 0 ? comments : <DropComment>[];
  }

  /// Every page [fetchComments] was asked for, in order.
  final List<int> fetchCommentsPageArgs = [];

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
    AudienceOption audience = AudienceOption.everyone,
    Set<String> excludedFriendIds = const {},
    LocationResult? location,
  }) async {
    if (createDropFromExistingImageError != null) {
      throw createDropFromExistingImageError!;
    }
    createDropFromExistingImageArgs.add({
      'imageUrl': imageUrl,
      'caption': caption,
      'mentionedUserIds': mentionedUserIds,
      'audience': audience,
      'location': location,
    });
  }
}
