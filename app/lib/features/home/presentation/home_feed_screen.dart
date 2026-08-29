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
import '../../follow/data/follow_request_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../saved/data/saved_repository.dart';
import '../../search/data/discovery_repository.dart';
import '../../search/presentation/search_screen.dart';
import '../data/home_feed_item.dart';
import '../data/home_preferences_repository.dart';
import '../data/home_repository.dart';
import 'pop_single_clip_screen.dart';
import 'widgets/from_your_clubs_feed.dart';
import 'widgets/home_drop_card.dart';
import 'widgets/home_pop_card.dart';
import 'widgets/trending_tile.dart';
import 'widgets/wynos_empty_feed_state.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wynos_home_tokens.dart';

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
    required this.discoveryRepository,
    required this.followRequestRepository,
    required this.homePreferencesRepository,
  });

  final HomeRepository homeRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  // WYN-072 (WYNOS Design Reference Rollout, Screen 01): SPEC.md Section
  // 4.5's empty state needs a real suggested-accounts list --
  // DiscoveryRepository.fetchSuggestedUsers is the same RPC-backed
  // source Search/Profile already use (see WynosEmptyFeedState's own
  // doc comment) -- and FollowRequestRepository is what
  // FollowActionButton (reused as-is for the Follow button there) needs
  // to handle a private suggested account correctly.
  final DiscoveryRepository discoveryRepository;
  final FollowRequestRepository followRequestRepository;

  // WYN-072: SPEC.md Section 4.2's first-time explainer banner --
  // persists its dismissal permanently per-account (see
  // HomePreferencesRepository's own doc comment).
  final HomePreferencesRepository homePreferencesRepository;

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

  // WYN-072 (SPEC.md Section 4.5): null until [_loadFollowingCount]
  // resolves -- _buildBodySlivers falls back to the pre-existing plain-
  // text empty messages until/unless this is known, same fail-open
  // posture as every other non-essential fetch on this screen (e.g.
  // [_loadUnreadChatCount]).
  int? _followingCount;

  // WYN-072 (SPEC.md Section 4.4, "New-posts indicator pill"): the UI
  // and its tap interaction (scroll to top + refresh, see
  // [_onTapNewPostsPill]) are fully wired below, but the *trigger*
  // condition is deliberately never flipped to `true` anywhere in this
  // file this round -- there is no existing realtime/poll infra in this
  // codebase that can reliably answer "a new post now ranks at the top
  // of whichever feed mode is currently active" (Chat's own realtime
  // channel, chat_repository.dart, is scoped to chat threads only, and
  // "สำหรับคุณ" specifically is server-ranked via an RPC, not a simple
  // created_at filter, so even a naive "any row newer than my top row"
  // poll wouldn't reliably predict what the ranking RPC would actually
  // place at the top). Hardcoding this to `true` is explicitly
  // forbidden by this task -- see this task's Known Issues in
  // .wyn/tasks/active/WYN-072-wynos-design-reference-home-feed.md.
  bool _showNewPostsPill = false;
  int _newPostsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _trendingFuture = widget.homeRepository.fetchTrending();
    _scrollController.addListener(_onScroll);
    _loadUnreadChatCount();
    _loadFollowingCount();
    widget.homeTabReselectSignal.addListener(_onHomeTabReselected);
  }

  // WYN-072 (SPEC.md Section 4.5): the empty state's real trigger
  // condition is "this account follows 0 people", not a mock toggle --
  // see [_buildBodySlivers].
  Future<void> _loadFollowingCount() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final count =
          await widget.followRepository.countFollowing(userId: userId);
      if (mounted) setState(() => _followingCount = count);
    } catch (_) {
      // Leave null -- see the field's doc comment above.
    }
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

  // WYN-072 (SPEC.md Section 4.1): the header's right-side icon pushes
  // SearchScreen -- same "push the existing tab's own screen" shortcut
  // [_openChatInbox] above already uses for Chat, reusing the exact
  // repositories this screen already holds. Distinct from Search's own
  // Bottom Nav destination (WYN-024) -- both remain reachable, same as
  // how the reference's own header search icon coexists with a separate
  // dedicated Search experience in a typical app.
  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
        ),
      ),
    );
  }

  // WYN-072 (SPEC.md Section 4.1): the header's hamburger icon has no
  // real destination yet -- the reference's own nav map (00-prototype.
  // tsx) opens a Side Menu (Screen 10, "10-side-menu.tsx") with
  // "โปรไฟล์"/"Club ของฉัน"/"บันทึกไว้" entries, but that screen doesn't
  // exist anywhere in this Flutter app yet (confirmed: no Drawer/side-
  // menu widget anywhere in app/lib), and building one is Screen 10's
  // own future task in this rollout, not this task's Home-Feed-only
  // scope. Rather than guessing at a whole new navigation surface, this
  // mirrors the reference's own precedent for a not-yet-wired
  // destination (00-prototype.tsx's SideMenu itself does the same thing
  // for "Club ของฉัน": `onToast("... ยังไม่พร้อมใช้งานในตัวอย่างนี้")`)
  // -- an honest "not ready yet" message, not a fake/no-op button. See
  // this task's Known Issues.
  void _openSideMenuPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('เมนูนี้จะพร้อมใช้งานเร็ว ๆ นี้')),
    );
  }

  @override
  void dispose() {
    widget.homeTabReselectSignal.removeListener(_onHomeTabReselected);
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
  // the fromYourClubs case below and _selectFeedMode's guard).
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
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final items = await _fetchPage(0);
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _page = 0;
        _hasMore = items.length == HomeRepository.pageSize;
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
                  // WYN-072 (SPEC.md Section 4.1): the "WYNOS" header --
                  // brand new, no prior position to preserve, so it's
                  // simply the first thing in the scroll view. Not
                  // pinned -- SPEC 4.3 only pins the tabs+pill block
                  // below.
                  SliverToBoxAdapter(child: _buildWynosHeader()),
                  // WYN-072 (SPEC.md Section 4.2): first-time explainer
                  // banner, also new -- renders nothing once
                  // permanently dismissed (see _ExplainerBanner).
                  SliverToBoxAdapter(
                    child: _ExplainerBanner(
                      homePreferencesRepository: widget.homePreferencesRepository,
                    ),
                  ),
                  // ClubSection + Trending scroll away with the rest of the
                  // feed instead of being permanently pinned above it --
                  // the fixed-Column layout this replaces claimed that
                  // space on screen no matter how far the user scrolled,
                  // leaving barely half a real phone's height for actual
                  // feed content underneath. See the bug report this fixes
                  // (Founder, 2026-08-24): "ส่วนหัวถูกล็อกความสูงคงที่ไว้
                  // ด้านบน ทำให้เหลือพื้นที่สกิลดูเนื้อหาฟีดเพียงแค่ครึ่ง
                  // จอล่างเท่านั้น". WYN-072: not depicted in the design
                  // reference at all -- left completely untouched (same
                  // position, same styling, same logic) per this task's
                  // own scope decision, see the class doc comment.
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
                  // Filter Bar" ask. WYN-072 (SPEC.md Section 4.3/4.4):
                  // restyled to an underline-tab row + (when triggered)
                  // the new-posts pill directly under it, both part of
                  // this same pinned block -- see _buildStickyTabsAndPill.
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _FeedModeToggleHeaderDelegate(
                      height: _stickyTabsAndPillHeight,
                      child: _buildStickyTabsAndPill(),
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
                // WYN-072 regression fix: this floating badge used to sit
                // flush with the top-right corner, which was safe while
                // nothing else occupied that corner. The new WYNOS header
                // (SPEC.md Section 4.1) now puts its own tappable search
                // icon in that exact same corner (see _buildWynosHeader,
                // Row(mainAxisAlignment: spaceBetween)) -- without this
                // [top] offset the two tap targets physically overlap, so
                // taps meant for the search icon land on this Material
                // instead (confirmed via a real widget-test hit-test
                // failure). [_wynosHeaderRowHeight] pushes this badge
                // below the header row so both stay independently
                // reachable, on Home (where the header exists above it)
                // and anywhere else this same floating action might be
                // reused.
                padding: const EdgeInsets.only(
                  right: WynSpacing.space2,
                  top: _wynosHeaderRowHeight,
                ),
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

  // WYN-072 (SPEC.md Section 4.3): replaces the old rainbow-gradient
  // `SegmentedButton` (DS-009) with an underline-tab row -- active tab:
  // weight 600 ink text + a 2px sapphire underline; inactive: weight 400
  // faint text. No `SegmentedButton` anymore, so the WYN-024 bug class
  // it was prone to (QA rounds 2-4, .wyn/tasks/bugs/WYN-024-segmented-
  // button-active-label-illegible-all-segments.md -- `SegmentedButton`
  // always clamps every segment to `constraints.maxWidth / childCount`
  // when given a bounded width, truncating whichever label is widest)
  // structurally can't recur here: each tab's `IntrinsicWidth` wrapper
  // sizes it to its own label's natural width (never divided by 4), and
  // the whole row still sits inside a horizontal `SingleChildScrollView`
  // (same fix WYN-024 already established) so even a viewport too
  // narrow to fit all 4 tabs at their natural width scrolls instead of
  // ever compressing/truncating one.
  Widget _buildTabsRow() {
    const tabs = [
      (_HomeFeedMode.forYou, 'สำหรับคุณ'),
      (_HomeFeedMode.following, 'ติดตาม'),
      (_HomeFeedMode.latest, 'ล่าสุด'),
      // Label kept exactly as the app's existing real copy ("...ของคุณ")
      // rather than SPEC.md's own shorter mock label ("จาก Club") --
      // this task only restyles the *look* of these 4 tabs, per this
      // task's own notes ("4 filter tabs ตรงกับ... เปลี่ยนแค่ visual").
      (_HomeFeedMode.fromYourClubs, 'จาก Club ของคุณ'),
    ];

    return Container(
      color: WynosHomeTokens.paper,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6),
        child: Row(
          children: [
            for (final (mode, label) in tabs) _buildTab(mode, label),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(_HomeFeedMode mode, String label) {
    final active = _feedMode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: WynSpacing.space6),
      child: InkWell(
        onTap: () => _selectFeedMode(mode),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WynosHomeTokens.filterTab(active: active),
                ),
              ),
              Container(
                key: active ? const Key('active_tab_underline') : null,
                height: 2,
                margin: const EdgeInsets.only(bottom: 1),
                decoration: BoxDecoration(
                  color: active ? WynosHomeTokens.sapphire : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(WynSpacing.radiusFull),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectFeedMode(_HomeFeedMode mode) {
    if (mode == _feedMode) return;
    setState(() => _feedMode = mode);
    // "จาก Club ของคุณ" is FromYourClubsFeed's own separate widget
    // state -- only forYou/following/latest share _items and need a
    // reload when switching between (or into) them.
    if (mode != _HomeFeedMode.fromYourClubs) _loadInitial();
  }

  // WYN-072 (SPEC.md Section 4.4): sits directly under the tab row,
  // inside the *same* pinned block (see this class's build() method) --
  // only rendered while [_showNewPostsPill] is true, which nothing in
  // this file currently ever sets (see that field's own doc comment).
  Widget _buildNewPostsPill() {
    return Container(
      color: WynosHomeTokens.paper,
      padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2 + 2),
      child: Center(
        child: Semantics(
          label: 'มีโพสต์ใหม่ $_newPostsCount โพสต์ กดเพื่อโหลด',
          button: true,
          excludeSemantics: true,
          child: InkWell(
            onTap: _onTapNewPostsPill,
            borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
              decoration: BoxDecoration(
                color: WynosHomeTokens.sapphire,
                borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D1B3A6B),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward,
                      size: 13, color: WynosHomeTokens.paper),
                  const SizedBox(width: WynSpacing.space1),
                  Text('มีโพสต์ใหม่ $_newPostsCount โพสต์',
                      style: WynosHomeTokens.label()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // SPEC.md Section 4.4: "tapping it scrolls to top and reveals the new
  // posts ... wire up the real scroll-to-top + prepend in production".
  // The scroll-to-top + refresh half is real (same _loadInitial the
  // pull-to-refresh/WYN-064 reselect-Home paths already use); only the
  // *trigger* that makes the pill appear in the first place is deferred
  // (see [_showNewPostsPill]'s doc comment).
  void _onTapNewPostsPill() {
    setState(() => _showNewPostsPill = false);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _loadInitial();
  }

  Widget _buildStickyTabsAndPill() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTabsRow(),
        const Divider(
            height: 1, thickness: 1, color: WynosHomeTokens.hairline),
        if (_showNewPostsPill) _buildNewPostsPill(),
      ],
    );
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

  // WYN-072: replaces the old top-level `_feedModeToggleHeight` constant
  // -- must now vary with [_showNewPostsPill] (the new-posts pill adds
  // its own row height to the pinned block only while visible), so it's
  // an instance getter rather than a fixed constant. Deliberately
  // generous/rounded-up estimates rather than a `tester.getSize()`-
  // measured exact value (the approach the constant this replaces used)
  // -- a SliverPersistentHeader clips its child to this height, so
  // erring tall risks a little dead space under the tabs/pill rather
  // than clipping the sapphire underline or the pill itself.
  double get _stickyTabsAndPillHeight =>
      _tabsRowHeight + 1 + (_showNewPostsPill ? _newPostsPillRowHeight : 0);

  // py-3 (12) top + py-3 (12) bottom + ~18px label line height + ~4px
  // for the 2px underline strip and its own small margins.
  static const double _tabsRowHeight = 46;

  // py-2.5 (10) top + py-2.5 (10) bottom + the pill button's own
  // py-2 (8+8) vertical padding + ~16px label line height.
  static const double _newPostsPillRowHeight = 52;

  // _buildWynosHeader's own row: WynSpacing.space2 (8) top padding +
  // WynSpacing.space1 (4) bottom padding + the tallest child (the menu/
  // search icons' own WynSpacing.space1 (4) all-around padding + their
  // ~20px icon size) -- same deliberately-generous-estimate approach as
  // [_tabsRowHeight]/[_newPostsPillRowHeight] above. Used to keep the
  // floating chat badge (see build()'s second SafeArea) clear of this
  // row's search icon, which now shares its top-right corner.
  static const double _wynosHeaderRowHeight = 40;

  // WYN-072 (SPEC.md Section 4.1): hamburger — "WYNOS" wordmark — search
  // icon. No border under this row itself (SPEC 4.1: "the visual
  // separation comes from the banner/tabs below it, not a line here").
  Widget _buildWynosHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space6, WynSpacing.space2, WynSpacing.space6, WynSpacing.space1,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            label: 'เมนู',
            button: true,
            excludeSemantics: true,
            child: InkWell(
              onTap: _openSideMenuPlaceholder,
              borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
              child: const Padding(
                padding: EdgeInsets.all(WynSpacing.space1),
                child: Icon(Icons.menu, size: 20, color: WynosHomeTokens.ink),
              ),
            ),
          ),
          Text('WYNOS', style: WynosHomeTokens.wordmark),
          Semantics(
            label: 'ค้นหา',
            button: true,
            excludeSemantics: true,
            child: InkWell(
              onTap: _openSearch,
              borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
              child: const Padding(
                padding: EdgeInsets.all(WynSpacing.space1),
                child: Icon(Icons.search, size: 19, color: WynosHomeTokens.ink),
              ),
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
      // WYN-072 (SPEC.md Section 4.5): the real "brand-new/follows no
      // one" empty state only replaces the plain-text messages below on
      // the 2 tabs SPEC 4.5 actually names ("สำหรับคุณ"/"ติดตาม"), and
      // only once [_followingCount] has actually resolved to a real 0 --
      // while it's still null (loading, or a failed fetch) this falls
      // through to the pre-existing messages rather than guessing.
      if ((_feedMode == _HomeFeedMode.forYou ||
              _feedMode == _HomeFeedMode.following) &&
          _followingCount == 0) {
        return [
          SliverFillRemaining(
            hasScrollBody: true,
            child: WynosEmptyFeedState(
              discoveryRepository: widget.discoveryRepository,
              followRepository: widget.followRepository,
              followRequestRepository: widget.followRequestRepository,
            ),
          ),
        ];
      }

      // "ติดตาม" gets a join-prompt message (mirrors WYN-019's Drop tab
      // Following-tab wording, adapted to this screen's Thai segment
      // labels) rather than the generic "be the first" one, which reads
      // wrong when the real issue is "you aren't following anyone yet".
      final String message;
      if (_feedMode == _HomeFeedMode.following) {
        // WYN-072: once [_followingCount] is known and > 0, SPEC 4.5's
        // own trigger doesn't apply (this account already follows
        // people) -- the real remaining reason the feed is still empty
        // is that whoever they follow just hasn't posted yet, a
        // distinct message from "you haven't followed anyone" (which
        // stays the fallback while [_followingCount] is still null/
        // unresolved, same as before this task).
        message = (_followingCount ?? 0) > 0
            ? 'คนที่คุณติดตามยังไม่ได้โพสต์อะไรเลย'
            : 'ยังไม่ได้ follow ใครเลย ลองดู สำหรับคุณ เพื่อค้นหาคนน่าสนใจ';
      } else {
        message = 'ยังไม่มีใครโพสต์อะไรเลย เป็นคนแรกสิ!';
      }
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

// The feed-mode toggle's pinned SliverPersistentHeader wrapper (see
// build()'s "Sticky Filter Bar" doc comment). [height] must match the
// child's actual rendered height exactly -- a SliverPersistentHeader
// clips its child to min/maxExtent rather than sizing to it, so a
// mismatch would either clip the toggle or leave dead space under it
// (which, in turn, throws off how much viewport SliverFillRemaining
// hands the feed body below -- confirmed by a test regression at wider
// widths when this was first guessed at 64 instead of measured). See
// _HomeFeedScreenState._stickyTabsAndPillHeight for how [height] is
// derived (WYN-072 -- this used to be a fixed top-level constant sized
// to the old `SegmentedButton`; it's an instance getter now since the
// new-posts pill can add its own row height on top of the tab row's).
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
    // A Material surface, not a transparent passthrough -- once pinned
    // above the scrolled-away ClubSection/Trending content, this needs
    // its own opaque background so feed cards scrolling underneath don't
    // show through the toggle bar. WYN-072 (SPEC.md Section 4.3):
    // explicitly `paper`, not the ambient theme's own surface color --
    // "must be opaque paper (#FAF9F6) -- never transparent, or post
    // content will show through underneath it while scrolling".
    return Material(
      color: WynosHomeTokens.paper,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _FeedModeToggleHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}

// WYN-072 (SPEC.md Section 4.2): the first-time explainer banner --
// renders nothing until the dismissed-state fetch resolves (avoids a
// dismissed-then-flashes-visible flicker for a returning user, same
// posture as PrivacyNoticeBanner, WYN-071) and, once resolved, nothing
// at all if already permanently dismissed.
class _ExplainerBanner extends StatefulWidget {
  const _ExplainerBanner({required this.homePreferencesRepository});

  final HomePreferencesRepository homePreferencesRepository;

  @override
  State<_ExplainerBanner> createState() => _ExplainerBannerState();
}

class _ExplainerBannerState extends State<_ExplainerBanner> {
  // Null while loading. Treated the same as `true` (hidden) on a failed
  // fetch -- same fail-closed posture PrivacyNoticeBanner (WYN-071)
  // already established for this exact kind of one-time informational
  // banner, rather than risking showing a banner whose dismiss action
  // might not actually persist.
  bool? _dismissed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dismissed =
          await widget.homePreferencesRepository.fetchExplainerBannerDismissed();
      if (!mounted) return;
      setState(() => _dismissed = dismissed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _dismissed = true);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      await widget.homePreferencesRepository.dismissExplainerBanner();
    } catch (_) {
      // Worst case it shows again next time -- not worth surfacing an
      // error for a one-time informational banner (mirrors
      // PrivacyNoticeBanner's identical posture, WYN-071).
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed != false) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space6, WynSpacing.space3, WynSpacing.space6, WynSpacing.space1,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: WynSpacing.space4, vertical: 14),
        decoration: BoxDecoration(
          color: WynosHomeTokens.ink,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ดู → แชร์ → ค้นพบ → ซื้อ',
                      style: WynosHomeTokens.bannerHeadline),
                  const SizedBox(height: 2),
                  Text(
                    'WYNOS คือพื้นที่โซเชียลที่ต่อยอดจากสิ่งที่คุณชอบเห็น',
                    style: WynosHomeTokens.bodySmall(color: WynosHomeTokens.graphite),
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'ปิดข้อความแนะนำ',
              button: true,
              excludeSemantics: true,
              child: InkWell(
                onTap: _dismiss,
                borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                child: const Padding(
                  padding: EdgeInsets.only(left: WynSpacing.space2, top: 2),
                  child: Icon(Icons.close, size: 15, color: WynosHomeTokens.graphite),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
