import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_inbox_screen.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../club/presentation/widgets/club_section.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_detail_screen.dart';
import '../../drop/presentation/quote_redrop_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../saved/data/saved_repository.dart';
import '../data/home_explainer_banner_preference.dart';
import '../data/home_feed_item.dart';
import '../data/home_repository.dart';
import 'pop_single_clip_screen.dart';
import 'widgets/from_your_clubs_feed.dart';
import 'widgets/home_drop_card.dart';
import 'widgets/home_pop_card.dart';
import 'widgets/trending_tile.dart';
import 'widgets/wynos_empty_feed_state.dart';
import 'widgets/wynos_explainer_banner.dart';
import '../../../core/design/wyn_spacing.dart';
import 'design/wynos_home_tokens.dart';

enum _HomeFeedMode { forYou, following, latest, fromYourClubs }

/// Screen 1 — Home tab (Bottom Nav, index 0). A feed mixing Drop and Pop
/// content, with the CLUB section (WYN-014) directly above the feed.
/// Default mode is "สำหรับคุณ" (ranked, WYN-018); "ติดตาม" (WYN-024)
/// absorbs the WYN-019 Drop tab's own Following capability now that Drop
/// no longer has a separate tab; "ล่าสุด" is the original WYN-007
/// chronological ordering. Search and Notifications moved out to their
/// own Bottom Nav tabs as part of WYN-024 -- this screen no longer owns a
/// top row. See .wyn/docs/design/wyn-007-home.md,
/// .wyn/docs/design/wyn-014-club-core.md (Screen 1),
/// .wyn/docs/design/wyn-018-home-feed-ranking.md, and
/// .wyn/docs/design/wyn-024-bottom-nav-v1-restructure.md (Screen 2).
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({
    super.key,
    required this.homeRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.savedRepository,
    required this.clubRepository,
    required this.clubPostRepository,
    required this.chatRepository,
    required this.homeTabReselectSignal,
  });

  final HomeRepository homeRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  // WYN-064 (Tap Home Tab to Scroll to Top & Refresh): RootShell bumps
  // this notifier's value every time the user taps the Home destination
  // while already on the Home tab. A ValueNotifier rather than a
  // GlobalKey<State> -- RootShell lives in a different file and this
  // screen's State is intentionally private, same reasoning as every
  // other cross-widget signal in this codebase (e.g. the visit-key
  // remount pattern) preferring an explicit, testable channel over
  // reaching into private State from outside.
  final ValueNotifier<int> homeTabReselectSignal;

  // WYN-031 -- Chat's entry point icon lives in this AppBar (see the
  // class doc comment: this screen "no longer owns a top row" as of
  // WYN-024, but Master Spec section 18 requires Chat to be reachable
  // via "a separate icon", never a 6th Bottom Nav tab, and this is the
  // most natural home-screen-adjacent place for it now that Search/
  // Notifications moved out).
  final ChatRepository chatRepository;

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final _scrollController = ScrollController();
  // WYN-064: lets _onHomeTabReselected trigger the same visual
  // pull-to-refresh affordance a manual pull would (spinner + onRefresh),
  // rather than calling _loadInitial directly and skipping the
  // indicator.
  final _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final List<HomeFeedItem> _items = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  // Resets to "สำหรับคุณ" every time Home is (re)built fresh -- not
  // persisted across app sessions, per the Design spec's "ค่าเริ่มต้น...
  // เสมอทุกครั้งที่เปิดแอป" simplification.
  _HomeFeedMode _feedMode = _HomeFeedMode.forYou;

  // Same fail-safe FutureBuilder pattern as ClubSection's own club row
  // (WYN-014) -- a failed/slow Trending fetch must never block the main
  // feed underneath it. See .wyn/docs/design/wyn-017-home-trending-
  // recommended-clubs.md.
  late Future<List<HomeFeedItem>> _trendingFuture;

  int _unreadChatCount = 0;

  // WYNOS Home reference spec 4.2/5 -- defaults to true (hidden) rather
  // than false, so a returning user who already dismissed the banner
  // never sees a one-frame flash of it while _loadBannerDismissed's
  // SharedPreferences read is still in flight.
  bool _bannerDismissed = true;

  // WYNOS Home reference spec 4.5 -- null means "not yet known", not
  // "zero": _buildBodySlivers only ever renders the richer new-account
  // empty state once this is confirmed to be exactly 0, falling back to
  // the old generic empty message otherwise (including while this is
  // still loading) -- see that method's own doc comment.
  int? _followingCount;
  List<Profile> _suggestedToFollow = const [];

  // WYNOS Home reference spec 4.4 -- new-posts pill. Only ever
  // populated for "ล่าสุด"/"ติดตาม" (see _pollForNewPosts's own doc
  // comment on why "สำหรับคุณ" is excluded); 0 means "hidden", matching
  // LikedByRow's/every other "hidden below a threshold" widget's own
  // convention in this codebase rather than a separate bool.
  int _newPostsCount = 0;

  // Set at the moment _loadInitial's fetch actually started, not off
  // the loaded items' own createdAt -- an empty page or a tie on the
  // very newest timestamp would otherwise leave this anchor wrong.
  // Polling asks "anything newer than this instant", which stays
  // correct regardless of what came back.
  DateTime? _feedLoadedAt;

  static const _newPostsPollInterval = Duration(seconds: 30);

  // Only ever running while _feedMode is latest/following (see
  // _onFilterTabSelected) -- not started here in initState, since the
  // default mode ("สำหรับคุณ") never polls at all. Most of this
  // screen's own tests never switch away from that default, so this
  // keeps a background Timer.periodic from existing for the lifetime of
  // screens/tests that have no use for it.
  Timer? _newPostsPollTimer;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _trendingFuture = widget.homeRepository.fetchTrending();
    _scrollController.addListener(_onScroll);
    _loadUnreadChatCount();
    _loadBannerDismissed();
    _loadEmptyStateData();
    widget.homeTabReselectSignal.addListener(_onHomeTabReselected);
  }

  /// WYNOS Home reference spec 4.4 -- lightweight polling instead of a
  /// push signal (see countNewSince's own doc comment for why). Scoped
  /// to "ล่าสุด"/"ติดตาม" only: "สำหรับคุณ" is a ranked top-N window, not
  /// a chronological feed, so "posts newer than my last load" isn't a
  /// question that feed can answer the same way.
  Future<void> _pollForNewPosts() async {
    if (!mounted) return;
    if (_feedMode != _HomeFeedMode.latest &&
        _feedMode != _HomeFeedMode.following) {
      return;
    }
    final anchor = _feedLoadedAt;
    if (anchor == null) return;

    try {
      final count = _feedMode == _HomeFeedMode.latest
          ? await widget.homeRepository.countNewSince(anchor)
          : await widget.homeRepository.countNewFollowingSince(
              userId: Supabase.instance.client.auth.currentUser!.id,
              since: anchor,
            );
      // Re-check mounted/mode/anchor after the await -- the user may
      // have switched tabs (or this screen may have been popped) while
      // the count request was in flight.
      if (!mounted ||
          (_feedMode != _HomeFeedMode.latest &&
              _feedMode != _HomeFeedMode.following) ||
          _feedLoadedAt != anchor) {
        return;
      }
      if (count > 0) setState(() => _newPostsCount = count);
    } catch (_) {
      // Silent -- a missed poll just tries again on the next tick, not
      // worth a blocking error for a background indicator.
    }
  }

  /// WYNOS Home reference spec 4.4 -- tapping the pill scrolls to the
  /// top and actually loads the new posts (never a silent prepend, per
  /// the spec's own "Do not silently prepend" rule) rather than the
  /// mock's own "just dismiss" stand-in.
  Future<void> _onNewPostsPillTap() async {
    setState(() => _newPostsCount = 0);
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    if (!mounted) return;
    await _loadInitial();
  }

  Future<void> _loadEmptyStateData() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser!.id;
      final followingCount =
          await widget.followRepository.countFollowing(userId: currentUserId);
      final suggestions = await widget.followRepository.fetchSuggestedToFollow();
      if (!mounted) return;
      setState(() {
        _followingCount = followingCount;
        _suggestedToFollow = suggestions;
      });
    } catch (_) {
      // Silent -- same posture as _loadUnreadChatCount/_trendingFuture: a
      // failed fetch just leaves the generic empty-state message
      // showing instead of the richer one, not worth a blocking error.
    }
  }

  /// WYNOS Home reference spec 4.5 -- the empty state's own follow
  /// button. Re-runs both _loadEmptyStateData (the followed account
  /// drops out of future suggestions) and _loadInitial (if they've
  /// already posted, the feed may stop being empty at all) rather than
  /// optimistically patching local state -- this is a rare, one-off
  /// action from a brand-new account, not a hot path worth the extra
  /// bookkeeping every other toggle in this screen has.
  Future<void> _followFromEmptyState(Profile profile) async {
    try {
      await widget.followRepository
          .toggleFollow(userId: profile.id, currentlyFollowing: false);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    _loadEmptyStateData();
    _loadInitial();
  }

  Future<void> _loadBannerDismissed() async {
    final dismissed = await loadHomeExplainerBannerDismissed(
      Supabase.instance.client.auth.currentUser!.id,
    );
    if (mounted && !dismissed) setState(() => _bannerDismissed = false);
  }

  Future<void> _dismissBanner() async {
    // Optimistic -- the banner disappears immediately rather than
    // waiting on the SharedPreferences write, same posture as every
    // other local-only toggle in this screen.
    setState(() => _bannerDismissed = true);
    await saveHomeExplainerBannerDismissed(
      Supabase.instance.client.auth.currentUser!.id,
    );
  }

  // WYN-032: the badge is "anything needing my attention" -- unread
  // messages in conversations I've already accepted, plus Message
  // Requests I haven't decided on yet. Fetched as 2 separate calls
  // (not summed server-side) since they come from 2 different
  // RPCs/views for unrelated reasons -- see chat_repository.dart.
  Future<void> _loadUnreadChatCount() async {
    try {
      final results = await Future.wait([
        widget.chatRepository.countUnreadConversations(),
        widget.chatRepository.countPendingMessageRequests(),
      ]);
      if (mounted) setState(() => _unreadChatCount = results[0] + results[1]);
    } catch (_) {
      // Silent -- same posture as RootShell's identical notification
      // badge fetch: a failed count just leaves the badge as-is, not
      // worth a blocking error for a number in an AppBar icon.
    }
  }

  Future<void> _openChatInbox() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatInboxScreen(chatRepository: widget.chatRepository),
      ),
    );
    if (mounted) _loadUnreadChatCount();
  }

  @override
  void dispose() {
    widget.homeTabReselectSignal.removeListener(_onHomeTabReselected);
    _newPostsPollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  // WYN-064 (Tap Home Tab to Scroll to Top & Refresh): RootShell calls
  // this by bumping homeTabReselectSignal whenever the user taps the
  // Home destination while already on the Home tab.
  // Case 1 -- scrolled down (pixels > 0): animate back to the top only,
  // no refetch (matches a plain "scroll to top" tap, not a refresh).
  // Case 2 -- already at the top: trigger the same pull-to-refresh the
  // user could do manually, guarded against overlapping calls while a
  // fetch triggered by this or another interaction (initial load,
  // manual pull, "ลองใหม่" retry) is already in flight.
  void _onHomeTabReselected() {
    if (!mounted || !_scrollController.hasClients) return;

    if (_scrollController.position.pixels > 0) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }

    if (_isLoadingInitial) return;
    _refreshIndicatorKey.currentState?.show();
  }

  // "สำหรับคุณ" (ranked, WYN-018), "ติดตาม" (WYN-024), and "ล่าสุด"
  // (chronological, WYN-007's original behavior) all share this same
  // _items/_page state and just swap which repository method feeds it --
  // "จาก Club ของคุณ" is a wholly separate widget (FromYourClubsFeed)
  // with its own state, untouched, and never reaches this method (see
  // the fromYourClubs case below and _onFilterTabSelected's guard).
  Future<List<HomeFeedItem>> _fetchPage(int page) {
    switch (_feedMode) {
      case _HomeFeedMode.forYou:
        return widget.homeRepository.fetchRankedFeed(page: page);
      case _HomeFeedMode.following:
        return widget.homeRepository.fetchFollowingFeed(page: page);
      case _HomeFeedMode.latest:
        return widget.homeRepository.fetchFeed(page: page);
      case _HomeFeedMode.fromYourClubs:
        throw StateError(
          '_fetchPage is never called in fromYourClubs mode -- see build()',
        );
    }
  }

  Future<void> _loadInitial() async {
    // Captured before the fetch, not off whatever comes back -- see
    // _feedLoadedAt's own doc comment.
    final loadStartedAt = DateTime.now().toUtc();
    setState(() {
      _isLoadingInitial = true;
      _error = null;
      // Any fresh load (tab switch, pull-to-refresh, or the pill's own
      // tap) makes a pending pill stale -- whatever's newer just got
      // loaded.
      _newPostsCount = 0;
    });
    try {
      final items = await _fetchPage(0);
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _page = 0;
        _hasMore = items.length == HomeRepository.pageSize;
        _feedLoadedAt = loadStartedAt;
      });
    } catch (_) {
      setState(() => _error = 'โหลด Home ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final items = await _fetchPage(nextPage);
      setState(() {
        _items.addAll(items);
        _page = nextPage;
        _hasMore = items.length == HomeRepository.pageSize;
      });
    } catch (_) {
      // Silent: an infinite-scroll load-more failure doesn't need a
      // blocking error state -- scrolling again just retries it.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // Takes the list index directly rather than re-locating the item by
  // id (the pre-WYN-034 approach): once a Drop can appear twice in the
  // same page -- once as a plain drop, once via someone's ReDrop of it
  // (WYN-034) -- `id` alone is no longer unique within `_items`, so an
  // id-based `indexWhere` could silently mutate the wrong row. The
  // index is captured directly from itemBuilder's own `index`, which
  // stays valid across setState here since this list is only ever
  // appended to (pagination), never reordered or spliced.
  Future<void> _toggleLike(int index) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];

    setState(() => _items[index] = _withToggledLike(previous));
    try {
      if (previous.contentType == HomeContentType.drop) {
        await widget.dropRepository.toggleLike(
          dropId: previous.id,
          currentlyLiked: previous.likedByMe,
        );
      } else {
        await widget.popRepository.toggleLike(
          popId: previous.id,
          currentlyLiked: previous.likedByMe,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = previous);
    }
  }

  Future<void> _toggleSave(int index) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];

    setState(() => _items[index] = _withToggledSave(previous));
    try {
      if (previous.contentType == HomeContentType.drop) {
        await widget.dropRepository.toggleSave(
          dropId: previous.id,
          currentlySaved: previous.savedByMe,
        );
      } else {
        await widget.popRepository.toggleSave(
          popId: previous.id,
          currentlySaved: previous.savedByMe,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = previous);
    }
  }

  /// Standard ReDrop toggle (WYN-034) -- Pop content has no ReDrop, so
  /// unlike [_toggleLike]/[_toggleSave] this never branches on
  /// [HomeContentType]; [onToggleRedrop] is only ever wired up for
  /// drop-typed cards (see the itemBuilder below).
  Future<void> _toggleRedrop(int index) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];

    setState(() => _items[index] = _withToggledRedrop(previous));
    try {
      await widget.dropRepository.toggleRedrop(
        dropId: previous.id,
        currentlyRedropped: previous.redroppedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = previous);
    }
  }

  /// WYN-035: casts (or changes) the viewer's vote on the Poll at
  /// [index] -- same optimistic-then-revert-on-error shape as
  /// [_toggleLike]. Only ever wired up for a drop-typed card whose
  /// [HomeFeedItem.isPoll] is true (see the itemBuilder below), so no
  /// [HomeContentType] branch is needed, same as [_toggleRedrop].
  Future<void> _votePoll(int index, int optionIndex) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];
    final pollId = previous.pollId;
    if (pollId == null) return;

    setState(() => _items[index] = previous.votedPoll(optionIndex));
    try {
      await widget.dropRepository.votePoll(
        pollId: pollId,
        optionIndex: optionIndex,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = previous);
    }
  }

  /// Deletes the viewer's own ReDrop entry at [index] (Standard or
  /// Quote) -- only ever wired up for a card HomeDropCard has already
  /// determined is the viewer's own ReDrop (see its `_isOwnRedrop`).
  /// Removes the row from the feed outright on success, unlike
  /// [_toggleRedrop] which flips [HomeFeedItem.redroppedByMe] on the
  /// *same* card -- deleting a specific ReDrop entry has nothing left
  /// to toggle back to.
  Future<void> _deleteRedrop(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    final redropId = item.redropId;
    if (redropId == null) return;

    setState(() => _items.removeAt(index));
    try {
      await widget.dropRepository.deleteRedrop(redropId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items.insert(index, item));
    }
  }

  /// WYNOS Unified Home Feed Algorithm V1.0 -- records the "Hide" User
  /// Signal for the item at [index] and removes it from the feed right
  /// away (optimistic, same "remove now, put back on failure" shape as
  /// [_deleteRedrop] -- there's nothing meaningful to "undo to" here
  /// either, hiding is a one-way action for this round, see
  /// HomeRepository.hideContent's own doc comment).
  Future<void> _hideItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];

    setState(() => _items.removeAt(index));
    try {
      await widget.homeRepository.hideContent(
        contentType: item.contentType,
        contentId: item.id,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _items.insert(index, item));
    }
  }

  /// Opens QuoteRedropScreen (WYN-034 Screen 2) for the Drop at
  /// [index]. Unlike [_toggleRedrop] this isn't optimistic -- posting
  /// happens on that screen itself, so this only bumps [redropCount]
  /// after a confirmed success (the screen pops `true`).
  Future<void> _quoteRedrop(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];

    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuoteRedropScreen(
          dropRepository: widget.dropRepository,
          drop: item.toDrop(),
        ),
      ),
    );
    if (posted != true || !mounted) return;
    if (index >= _items.length || _items[index].id != item.id) return;
    setState(() {
      _items[index] =
          _items[index].copyWith(redropCount: _items[index].redropCount + 1);
    });
  }

  // WYN-034: now that HomeFeedItem has a real copyWith (added alongside
  // the redrop_* fields), these delegate to it instead of rebuilding
  // every field by hand -- the old hand-rolled shape would have
  // silently reset any field it forgot to repeat to the constructor
  // default, which used to be harmless (nothing else existed yet) but
  // would have quietly wiped a ReDrop-sourced card's label/state on
  // every Like or Save tap once redrop_* existed.
  static HomeFeedItem _withToggledLike(HomeFeedItem item) => item.copyWith(
        likedByMe: !item.likedByMe,
        likeCount: item.likedByMe ? item.likeCount - 1 : item.likeCount + 1,
      );

  static HomeFeedItem _withToggledSave(HomeFeedItem item) =>
      item.copyWith(savedByMe: !item.savedByMe);

  static HomeFeedItem _withToggledRedrop(HomeFeedItem item) => item.copyWith(
        redroppedByMe: !item.redroppedByMe,
        redropCount:
            item.redroppedByMe ? item.redropCount - 1 : item.redropCount + 1,
      );

  Future<void> _openDrop(HomeFeedItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          dropRepository: widget.dropRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          drop: item.toDrop(),
        ),
      ),
    );
    // The detail screen can change like/comment/save state or delete the
    // Drop entirely -- reload rather than trying to sync partial state
    // back into the feed (same approach as DropFeedScreen, WYN-005).
    _loadInitial();
  }

  Future<void> _openPop(HomeFeedItem item, {bool openComments = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PopSingleClipScreen(
          pop: item.toPop(),
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          dropRepository: widget.dropRepository,
          savedRepository: widget.savedRepository,
          openCommentsOnStart: openComments,
        ),
      ),
    );
    _loadInitial();
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // WYN-031's Chat entry point is a floating overlay (Positioned in
      // the Stack below), not an AppBar -- this screen's fixed-height
      // header (ClubSection + Trending + feed-mode toggle) was already
      // only ~22px away from overflowing a real AppBar's height budget
      // on a small viewport before this feature existed (confirmed by
      // adding one: it overflowed root_shell_test.dart's default test
      // surface immediately). An AppBar claims Column space no matter
      // how compact; a Stack overlay claims none, so it can't ever
      // push this already-tight layout over the edge on a short
      // screen. See .wyn/docs/design/wyn-031-chat-1to1.md, Screen 1 --
      // this is a deliberate deviation from that doc's original
      // "AppBar" placement, made during Coding once the real overflow
      // risk surfaced.
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              key: _refreshIndicatorKey,
              onRefresh: _feedMode == _HomeFeedMode.fromYourClubs
                  ? () async {}
                  : _loadInitial,
              child: CustomScrollView(
                key: const Key('home_feed_scroll_view'),
                controller: _scrollController,
                slivers: [
                  // WYNOS Home reference spec 4.2 -- sits directly under
                  // the header, above everything else (including
                  // ClubSection/Trending, which the reference doesn't
                  // have at all) so it reads as the very first thing a
                  // returning-but-not-yet-dismissed user sees.
                  if (!_bannerDismissed)
                    SliverToBoxAdapter(
                      child: WynosExplainerBanner(onDismiss: _dismissBanner),
                    ),
                  // ClubSection + Trending scroll away with the rest of the
                  // feed instead of being permanently pinned above it --
                  // the fixed-Column layout this replaces claimed that
                  // space on screen no matter how far the user scrolled,
                  // leaving barely half a real phone's height for actual
                  // feed content underneath. See the bug report this fixes
                  // (Founder, 2026-08-24): "ส่วนหัวถูกล็อกความสูงคงที่ไว้
                  // ด้านบน ทำให้เหลือพื้นที่สกิลดูเนื้อหาฟีดเพียงแค่ครึ่ง
                  // จอล่างเท่านั้น".
                  SliverToBoxAdapter(
                    child: ClubSection(
                      clubRepository: widget.clubRepository,
                      clubPostRepository: widget.clubPostRepository,
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildTrendingSection()),
                  // Pinned: stays visible at the top once the header above
                  // has scrolled out of view, so the mode toggle (สำหรับ
                  // คุณ/ติดตาม/ล่าสุด/จาก Club ของคุณ) is always reachable
                  // without scrolling back up -- same request's "Sticky
                  // Filter Bar" ask. The new-posts pill (spec 4.4) is
                  // itself part of this same pinned block, directly under
                  // the tabs, so it never scrolls away independently --
                  // the header's own height grows by _newPostsPillHeight
                  // while it's visible.
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _FeedModeToggleHeaderDelegate(
                      height: _stickyTabsHeight +
                          (_newPostsCount > 0 ? _newPostsPillHeight : 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFilterTabs(),
                          if (_newPostsCount > 0) _buildNewPostsPill(),
                        ],
                      ),
                    ),
                  ),
                  if (_feedMode == _HomeFeedMode.fromYourClubs)
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: FromYourClubsFeed(
                        key: const Key('from_your_clubs_feed'),
                        clubRepository: widget.clubRepository,
                        clubPostRepository: widget.clubPostRepository,
                      ),
                    )
                  else
                    ..._buildBodySlivers(),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: WynSpacing.space2),
                child: _buildChatAction(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Badge shape mirrors RootShell._buildNotificationsIcon exactly (cap
  // "9+", same Container/Positioned/color tokens) -- this is an
  // IconButton rather than a plain Icon since (unlike the Bottom Nav
  // destination it mirrors) this is the tap target itself, not wrapped
  // by something else that handles the tap.
  Widget _buildChatAction() {
    const icon = Icon(Icons.chat_bubble_outline);
    final count = _unreadChatCount;
    final badge = count <= 0
        ? icon
        : Stack(
            clipBehavior: Clip.none,
            children: [
              icon,
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space1, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );

    // Solid circular surface (unlike a plain AppBar action) -- this
    // floats directly over whatever ClubSection/feed content happens
    // to be underneath it, so it needs its own background to stay
    // legible rather than relying on an AppBar's.
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: badge,
        tooltip: count > 0 ? 'ข้อความ, $count บทสนทนายังไม่อ่าน' : 'ข้อความ',
        onPressed: _openChatInbox,
      ),
    );
  }

  // WYNOS Home reference spec, section 4.3 ("Filter tabs (sticky)") --
  // replaces the old SegmentedButton row (see git history for the
  // 3-rounds-of-QA truncation saga that lived here) with plain
  // underline-style tabs. That old bug ("จาก Club ของคุณ" getting
  // squeezed to 1-2 characters) doesn't even apply to this shape:
  // SegmentedButton divided the *whole row's* width evenly across all 4
  // segments regardless of each label's own length; a plain `Row` inside
  // `SingleChildScrollView` gives every tab exactly its own intrinsic
  // width instead, so nothing is ever divided down in the first place --
  // the row just scrolls horizontally if the total exceeds the screen.
  //
  // `_stickyTabsHeight` is a set of numbers this method itself commits
  // to (12+20+12 content, +1 hairline border below) via explicit
  // Padding/SizedBox, not a measured value read off the rendered
  // widget -- unlike the old SegmentedButton (a Material component whose
  // exact height wasn't under this file's control), every dimension
  // here is one this method fixes directly, so the two can never drift
  // out of sync with each other.
  Widget _buildFilterTabs() {
    const modes = [
      _HomeFeedMode.forYou,
      _HomeFeedMode.following,
      _HomeFeedMode.latest,
      _HomeFeedMode.fromYourClubs,
    ];
    const labels = {
      _HomeFeedMode.forYou: 'สำหรับคุณ',
      _HomeFeedMode.following: 'ติดตาม',
      _HomeFeedMode.latest: 'ล่าสุด',
      // Spec section 4.3 lists this tab as "จาก Club" -- kept as the
      // app's existing real copy instead ("จาก Club ของคุณ") per the
      // spec's own section 0 rule: only styling/component structure
      // changes here, real product copy stays as-is.
      _HomeFeedMode.fromYourClubs: 'จาก Club ของคุณ',
    };

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WynosHomeColors.paper,
        border: Border(
          bottom: BorderSide(color: WynosHomeColors.hairline, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: WynosHomeSpacing.pagePadding),
        child: Row(
          children: [
            for (final mode in modes)
              Padding(
                padding: const EdgeInsets.only(
                    right: WynosHomeSpacing.pagePadding),
                child: GestureDetector(
                  onTap: () => _onFilterTabSelected(mode),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            labels[mode]!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WynosHomeText.filterTab(
                                active: _feedMode == mode),
                          ),
                        ),
                        // Always present (never conditionally added/removed
                        // from the Stack) -- only its color changes with
                        // [_feedMode], painted transparent when this tab
                        // isn't the active one. A previous version only
                        // included this child `if (_feedMode == mode)`,
                        // which meant every tab switch added this widget to
                        // one Stack and removed it from another in the same
                        // frame; that shape change turned out to be what
                        // was tripping a Flutter-internal semantics
                        // invariant ('!semantics.parentDataDirty') on
                        // pretty much any pumpAndSettle() once this screen
                        // was mounted, hanging `flutter test` outright. See
                        // the isolation testing in this branch's commit
                        // history for how that was tracked down.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: SizedBox(
                            // Key name kept from the old SegmentedButton
                            // implementation this replaces -- existing
                            // tests (home_feed_screen_test.dart) already
                            // assert on it, and it's an internal test
                            // hook with no user-facing meaning to rename.
                            key: const Key('active_segment_accent'),
                            height: 2,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _feedMode == mode
                                    ? WynosHomeColors.sapphire
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(WynSpacing.radiusFull)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // WYNOS Home reference spec 4.4 -- the new-posts pill. Every
  // dimension here is one this method fixes explicitly (a 16px content
  // box inside px-16/py-8 padding, py-10 outer row padding), same
  // deterministic-construction approach _buildFilterTabs already uses,
  // so _newPostsPillHeight below can just be declared rather than
  // measured off the rendered widget.
  Widget _buildNewPostsPill() {
    return DecoratedBox(
      decoration: const BoxDecoration(color: WynosHomeColors.paper),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: GestureDetector(
            onTap: _onNewPostsPillTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: WynosHomeColors.sapphire,
                borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                boxShadow: const [
                  // rgba(27,58,107,0.3) -- sapphire at 30% alpha.
                  BoxShadow(
                    color: Color(0x4D1B3A6B),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                height: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_upward,
                      size: 13,
                      color: WynosHomeColors.paper,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'มีโพสต์ใหม่ $_newPostsCount โพสต์',
                      style: WynosHomeText.newPostsPill,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onFilterTabSelected(_HomeFeedMode mode) {
    if (mode == _feedMode) return;
    setState(() {
      _feedMode = mode;
      // Covers the fromYourClubs branch below, which never calls
      // _loadInitial (that method clears this too, but only for the
      // other 3 modes) -- a stale pill from "ล่าสุด"/"ติดตาม" must not
      // keep showing once switched away from either.
      _newPostsCount = 0;
    });

    // The new-posts poll only ever runs for these two chronological
    // modes (see _pollForNewPosts's doc comment) -- start it on
    // entering either, stop it on leaving both, rather than running it
    // unconditionally for the screen's whole lifetime regardless of
    // which mode is even active.
    if (mode == _HomeFeedMode.latest || mode == _HomeFeedMode.following) {
      _newPostsPollTimer ??=
          Timer.periodic(_newPostsPollInterval, (_) => _pollForNewPosts());
    } else {
      _newPostsPollTimer?.cancel();
      _newPostsPollTimer = null;
    }

    // "จาก Club ของคุณ" is FromYourClubsFeed's own separate widget state
    // -- only forYou/following/latest share _items and need a reload
    // when switching between (or into) them.
    if (mode != _HomeFeedMode.fromYourClubs) _loadInitial();
  }

  Widget _buildTrendingSection() {
    return SizedBox(
      height: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(
              'กำลังนิยม',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<HomeFeedItem>>(
              future: _trendingFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: WynSpacing.space3),
                    child: Center(child: Text('ยังไม่มี content กำลังนิยม')),
                  );
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: WynSpacing.space2),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return TrendingTile(
                      item: item,
                      onTap: () => item.contentType == HomeContentType.drop
                          ? _openDrop(item)
                          : _openPop(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Returns the sliver(s) for whichever state the feed is in -- loading/
  // error/empty each fill the remaining viewport below the pinned mode
  // toggle (SliverFillRemaining), same visual "centered in the space
  // under the header" result the old Expanded(child: Center(...)) gave,
  // just expressed as a sliver so it can sit inside the same
  // CustomScrollView as the scrollable header above it (see build()'s
  // doc comment on why that header no longer owns fixed Column space).
  List<Widget> _buildBodySlivers() {
    if (_isLoadingInitial) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                const SizedBox(height: WynSpacing.space3),
                TextButton(
                    onPressed: _loadInitial, child: const Text('ลองใหม่')),
              ],
            ),
          ),
        ),
      ];
    }

    if (_items.isEmpty) {
      // WYNOS Home reference spec 4.5 -- the real trigger is "this
      // account follows no one yet", not merely "this tab has zero
      // items" (an established account's "สำหรับคุณ"/"ติดตาม" could in
      // principle come back empty for other reasons, e.g. everyone they
      // follow happens to have nothing recent). _followingCount is only
      // ever compared to exactly 0, never left to a truthy/falsy check
      // on a possibly-still-loading null -- see its own doc comment.
      final isNewAccountEmptyState =
          (_feedMode == _HomeFeedMode.forYou ||
                  _feedMode == _HomeFeedMode.following) &&
              _followingCount == 0;

      if (isNewAccountEmptyState) {
        return [
          SliverToBoxAdapter(
            child: WynosEmptyFeedState(
              suggestions: _suggestedToFollow,
              onFollow: _followFromEmptyState,
              onOpenProfile: (profile) => _openProfile(profile.id),
            ),
          ),
        ];
      }

      // "ติดตาม" gets a join-prompt message (mirrors WYN-019's Drop tab
      // Following-tab wording, adapted to this screen's Thai segment
      // labels) rather than the generic "be the first" one, which reads
      // wrong when the real issue is "you aren't following anyone yet".
      // Reached for "ติดตาม" only once _followingCount is confirmed > 0
      // (they follow people, but none of those people have posted) --
      // the wording still reads fine for that rarer case too.
      final message = _feedMode == _HomeFeedMode.following
          ? 'ยังไม่ได้ follow ใครเลย ลองดู สำหรับคุณ เพื่อค้นหาคนน่าสนใจ'
          : 'ยังไม่มีใครโพสต์อะไรเลย เป็นคนแรกสิ!';
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        ),
      ];
    }

    // Interleaves a hairline divider between posts only (DS-003) -- never
    // before the loading spinner at the end, which isn't content -- the
    // same rule ListView.separated enforced, just written out by hand
    // since SliverChildBuilderDelegate has no separated variant. Each
    // real item sits at an even index, each divider at the following odd
    // index, so index~/2 recovers the item index below.
    final itemCount = _items.length + (_hasMore ? 1 : 0);
    return [
      SliverList(
        key: const Key('home_feed_list'),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i.isOdd) {
              final itemIndex = i ~/ 2;
              return itemIndex + 1 < _items.length
                  ? const Divider(height: 1)
                  : const SizedBox.shrink();
            }
            final index = i ~/ 2;

            if (index >= _items.length) {
              return const Padding(
                padding: EdgeInsets.all(WynSpacing.space4),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final item = _items[index];
            // WYN-034: id alone is no longer a unique widget key -- the
            // same Drop can appear twice (once plain, once via someone's
            // ReDrop of it), so redropId (null for a plain row) is
            // folded in too.
            final itemKey = ValueKey('${item.id}:${item.redropId ?? ''}');
            if (item.contentType == HomeContentType.drop) {
              return HomeDropCard(
                key: itemKey,
                item: item,
                onTap: () => _openDrop(item),
                onToggleLike: () => _toggleLike(index),
                onToggleSave: () => _toggleSave(index),
                onOpenProfile: () => _openProfile(item.authorId),
                onToggleRedrop: () => _toggleRedrop(index),
                onQuoteRedrop: () => _quoteRedrop(index),
                dropRepository: widget.dropRepository,
                onOpenRedropperProfile: item.redropperId == null
                    ? null
                    : () => _openProfile(item.redropperId!),
                onDeleteRedrop: () => _deleteRedrop(index),
                onVotePoll: (optionIndex) => _votePoll(index, optionIndex),
                onHide: () => _hideItem(index),
              );
            }
            return HomePopCard(
              key: itemKey,
              item: item,
              onTap: () => _openPop(item),
              onTapComment: () => _openPop(item, openComments: true),
              onToggleLike: () => _toggleLike(index),
              onToggleSave: () => _toggleSave(index),
              onOpenProfile: () => _openProfile(item.authorId),
              onHide: () => _hideItem(index),
            );
          },
          childCount: itemCount * 2 - 1,
        ),
      ),
    ];
  }
}

// The filter tabs' pinned SliverPersistentHeader wrapper (see build()'s
// "Sticky Filter Bar" doc comment). [height] must match the child's
// actual rendered height exactly -- a SliverPersistentHeader clips its
// child to min/maxExtent rather than sizing to it, so a mismatch would
// either clip the tabs or leave dead space under them (which, in turn,
// throws off how much viewport SliverFillRemaining hands the feed body
// below). _stickyTabsHeight = _buildFilterTabs()'s own fixed layout: a
// 44px SizedBox per tab (12 top padding + a 20px text box + 12 bottom
// padding, all explicit constants that method itself commits to, not
// measured off the rendered widget) + 1px hairline bottom border.
const double _stickyTabsHeight = 44 + 1;

// _buildNewPostsPill()'s own fixed layout: 10px vertical padding on the
// outer row (top+bottom) + 8px vertical padding inside the pill
// (top+bottom) + a 16px content box, all explicit constants that method
// itself commits to -- same reasoning as _stickyTabsHeight above.
const double _newPostsPillHeight = 10 + 10 + 8 + 8 + 16;

class _FeedModeToggleHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FeedModeToggleHeaderDelegate({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // No extra background/Material wrapper needed -- _buildFilterTabs's
    // own DecoratedBox already paints an opaque WynosHomeColors.paper
    // background (spec 4.3: "must be opaque paper -- never transparent,
    // or post content will show through underneath it while scrolling")
    // plus the hairline bottom border, so this delegate just passes the
    // child through.
    return child;
  }

  @override
  bool shouldRebuild(covariant _FeedModeToggleHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
