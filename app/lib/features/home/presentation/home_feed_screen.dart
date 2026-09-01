import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/widgets/guest_gate.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_inbox_screen.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
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
import '../data/home_feed_item.dart';
import '../data/home_repository.dart';
import 'pop_single_clip_screen.dart';
import 'widgets/from_your_clubs_feed.dart';
import 'widgets/home_drop_card.dart';
import 'widgets/home_explainer_banner.dart';
import 'widgets/home_pop_card.dart';
import 'widgets/new_posts_pill.dart';
import 'widgets/suggested_follow_list.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';

enum _HomeFeedMode { forYou, following, latest, fromYourClubs }

/// Screen 1 — Home tab (Bottom Nav, index 0). A feed mixing Drop and Pop
/// content, with the CLUB section (WYN-014) directly above the feed.
/// Default mode is "สำหรับคุณ" (ranked, WYN-018); "ติดตาม" (WYN-024)
/// absorbs the WYN-019 Drop tab's own Following capability now that Drop
/// no longer has a separate tab; "ล่าสุด" is the original WYN-007
/// chronological ordering. Search and Notifications moved out to their
/// own Bottom Nav tabs as part of WYN-024; this screen's own top row is
/// now just the WYNOS wordmark + Chat entry point (see _buildHeader),
/// not a full AppBar. See .wyn/docs/design/wyn-007-home.md,
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

  // WYN-031 -- Chat's entry point icon lives in this screen's header
  // (see _buildHeader): Master Spec section 18 requires Chat to be
  // reachable via "a separate icon", never a 6th Bottom Nav tab, and
  // this is the most natural home-screen-adjacent place for it now
  // that Search/Notifications moved out.
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

  int _unreadChatCount = 0;

  // WYNOSHomeSpec.md 4.5 -- built fresh (not threaded through the
  // constructor) since only the empty state's SuggestedFollowList uses
  // these here, same "build it locally, don't widen the constructor for
  // one secondary section" shape as ViewProfileScreen's own
  // _discoveryRepository (WYN-071 Screen 5).
  late final DiscoveryRepository _discoveryRepository = DiscoveryRepository(
    Supabase.instance.client,
    homeRepository: widget.homeRepository,
    profileRepository: widget.profileRepository,
  );
  late final FollowRequestRepository _followRequestRepository =
      FollowRequestRepository(Supabase.instance.client);

  // WYNOSHomeSpec.md 4.4 (New-posts pill) -- count of Drops/Pops
  // someone *else* has posted since this feed was last (re)loaded.
  // Never auto-prepended; only ever cleared by the user tapping the
  // pill (which reloads) or switching/reloading the feed some other
  // way (_loadInitial resets it to 0 at the start of every fetch).
  RealtimeChannel? _newPostsChannel;
  int _newPostCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
    _loadUnreadChatCount();
    widget.homeTabReselectSignal.addListener(_onHomeTabReselected);
    _newPostsChannel = widget.homeRepository.subscribeToNewPosts((authorId) {
      // Skip the viewer's own new post -- RootShell._openCreateDrop
      // already bumps _homeVersion (remounting this whole screen fresh)
      // on a successful post, so counting it again here would just
      // show a pill for content this viewer already sees.
      if (!mounted || authorId == Supabase.instance.client.auth.currentUser?.id) {
        return;
      }
      setState(() => _newPostCount++);
    });
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

  // WYN-072 (Guest Browsing): Chat is a conversation with another real
  // person -- gated the same as Profile/Drop/Notifications in RootShell.
  Future<void> _openChatInbox() async {
    if (!await requireRealAccount(context)) return;
    if (!mounted) return;
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
    final channel = _newPostsChannel;
    if (channel != null) widget.homeRepository.unsubscribe(channel);
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

  // WYNOSHomeSpec.md 4.4: tapping the new-posts pill scrolls to top and
  // reveals the new posts -- same visible spinner+reload shape as a
  // manual pull, via _refreshIndicatorKey (mirrors
  // _onHomeTabReselected's identical scroll-then-refresh shape above).
  Future<void> _onNewPostsPillTap() async {
    if (_scrollController.hasClients && _scrollController.position.pixels > 0) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    if (!mounted) return;
    _refreshIndicatorKey.currentState?.show();
  }

  // "สำหรับคุณ" (ranked, WYN-018), "ติดตาม" (WYN-024), and "ล่าสุด"
  // (chronological, WYN-007's original behavior) all share this same
  // _items/_page state and just swap which repository method feeds it --
  // "จาก Club ของคุณ" is a wholly separate widget (FromYourClubsFeed)
  // with its own state, untouched, and never reaches this method (see
  // the fromYourClubs case below and _buildFeedModeToggle's guard).
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
      // A fresh load already carries every post the pill would have
      // offered to reveal -- see _newPostCount's own doc comment.
      _newPostCount = 0;
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
    // WYNOSHomeSpec.md 4.4: the pill only makes sense for the 3 modes
    // that actually share _items/_page (see _fetchPage's own doc
    // comment) -- "จาก Club ของคุณ" is a wholly separate widget/data
    // source a new Drop/Pop insert has nothing to do with.
    final showNewPostsPill =
        _feedMode != _HomeFeedMode.fromYourClubs && _newPostCount > 0;

    return Scaffold(
      // A real header row (wordmark + chat entry point), matching
      // design-reference/01-home.tsx's header -- not the floating
      // Positioned-over-content overlay this screen used to render the
      // chat icon as (see WYN-031's original "deviation from AppBar"
      // note, since superseded). That deviation existed because
      // ClubSection/Trending/the feed-mode toggle used to be a
      // fixed-height Column claiming space above the scroll view, which
      // left a real AppBar's height with nowhere to go on a small
      // viewport (root_shell_test.dart's default test surface
      // overflowed). They're all slivers inside the CustomScrollView
      // now (2026-08-24 fix, see the ClubSection sliver's own doc
      // comment below), so a real header row above it just shrinks the
      // visible scroll area on a short screen instead of overflowing
      // it. See .wyn/docs/design/wyn-031-chat-1to1.md, Screen 1.
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                key: _refreshIndicatorKey,
                onRefresh: _feedMode == _HomeFeedMode.fromYourClubs
                    ? () async {}
                    : _loadInitial,
                child: CustomScrollView(
                  key: const Key('home_feed_scroll_view'),
                  controller: _scrollController,
                  slivers: [
                    // WYNOSHomeSpec.md item 1 -- the very first thing an
                    // account sees on Home, shown once total (see
                    // HomeExplainerBanner's own doc comment); scrolls away
                    // with everything below it rather than pinning.
                    const SliverToBoxAdapter(child: HomeExplainerBanner()),
                    // WYN-073: ClubSection/Trending (formerly here) removed
                    // from Home -- both are already reachable from the
                    // Search tab (club discovery/create, Top100), so this
                    // isn't a lost capability, just a duplicate entry point.
                    // See .wyn/docs/design/wyn-073-home-layout-tabs-restyle.md.
                    // Pinned: stays visible at the top once the header above
                    // has scrolled out of view, so the mode toggle (สำหรับ
                    // คุณ/ติดตาม/ล่าสุด/จาก Club ของคุณ) is always reachable
                    // without scrolling back up -- same request's "Sticky
                    // Filter Bar" ask.
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _FeedModeToggleHeaderDelegate(
                        height: _feedModeToggleHeight +
                            (showNewPostsPill ? _newPostsPillHeight : 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFeedModeToggle(),
                            // WYNOSHomeSpec.md 4.4: "itself part of the
                            // sticky block" -- pinned together with the
                            // toggle above, not a separate scrolling
                            // sliver of its own.
                            if (showNewPostsPill)
                              NewPostsPill(
                                count: _newPostCount,
                                onTap: _onNewPostsPillTap,
                              ),
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
          ],
        ),
      ),
    );
  }

  // WYNOS wordmark + chat entry point, matching design-reference/01-
  // home.tsx's header row (hamburger/wordmark/search there). The
  // reference's hamburger is left out on purpose rather than added as a
  // dead button: this app's destinations already all live in the Bottom
  // Nav (Settings itself is reachable from Profile), and there's no
  // second menu for a hamburger here to open. The reference's search
  // icon becomes chat, matching what this icon already opens everywhere
  // else in the app (WYN-031).
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          WynSpacing.space2, WynSpacing.space1, WynSpacing.space2, WynSpacing.space1),
      child: Row(
        children: [
          // Balances the chat IconButton's own ~48px width so the
          // wordmark sits visually centered rather than drifting left.
          const SizedBox(width: 48),
          Expanded(
            child: Center(
              child: Text(
                'WYNOS',
                style: WynTypography.screenTitle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          _buildChatAction(),
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

    return IconButton(
      icon: badge,
      tooltip: count > 0 ? 'ข้อความ, $count บทสนทนายังไม่อ่าน' : 'ข้อความ',
      onPressed: _openChatInbox,
    );
  }

  // WYN-073: replaces the bordered/filled SegmentedButton (see the
  // superseded history this comment used to carry, .wyn/docs/design/
  // wyn-073-home-layout-tabs-restyle.md) with plain text tabs + a thin
  // underline indicator, matching design-reference/01-home.tsx's tab
  // style -- but keeping DS-009's approved rainbow-gradient indicator
  // color rather than reverting to the reference's plain sapphire,
  // since that color choice is a separate, still-current Founder
  // decision this task doesn't touch.
  //
  // Still wrapped in `SingleChildScrollView(horizontal)` for the same
  // reason WYN-024 needed it: "จาก Club ของคุณ" doesn't fit next to the
  // other 3 labels on a narrow phone. Unlike the old SegmentedButton,
  // a plain `Row` never forces equal-width segments in the first place
  // (that clamping was `SegmentedButton`-specific), so there's no
  // `IntrinsicWidth` workaround needed here -- each tab just sizes to
  // its own label.
  Widget _buildFeedModeToggle() {
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
      _HomeFeedMode.fromYourClubs: 'จาก Club ของคุณ',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in modes)
              Padding(
                padding: const EdgeInsets.only(right: WynSpacing.space6),
                child: _buildFeedModeTab(mode, labels[mode]!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedModeTab(_HomeFeedMode mode, String label) {
    final selected = mode == _feedMode;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = (Theme.of(context).textTheme.bodyMedium ??
            const TextStyle())
        .copyWith(
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
    );

    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () {
          if (selected) return;
          setState(() => _feedMode = mode);
          // "จาก Club ของคุณ" is FromYourClubsFeed's own separate
          // widget state -- only forYou/following/latest share _items
          // and need a reload when switching between (or into) them.
          if (mode != _HomeFeedMode.fromYourClubs) _loadInitial();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
                const SizedBox(height: WynSpacing.space1),
                // Reserves the same 2px of height whether selected or
                // not (opacity-only animation), so switching tabs never
                // shifts the row's height -- same approach the old
                // strip indicator used.
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  opacity: selected ? 1 : 0,
                  child: Container(
                    key: selected ? const Key('active_segment_accent') : null,
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: WynColors.rainbowAccent,
                      borderRadius: BorderRadius.all(
                          Radius.circular(WynSpacing.radiusFull)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
      // WYNOSHomeSpec.md 4.5: "ติดตาม" empty is the one real "the
      // account follows no one yet" case -- get_wynos_ranked_feed()'s
      // own candidate pool ("สำหรับคุณ"/"ล่าสุด") is never scoped to
      // following, so either being empty means the *platform* has no
      // recent content at all (the existing "เป็นคนแรกสิ!" message is
      // already the right one for that), not "go follow someone".
      if (_feedMode == _HomeFeedMode.following) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: WynSpacing.space6,
                  vertical: WynSpacing.space4,
                ),
                child: SuggestedFollowList(
                  fetchSuggestedUsers: _discoveryRepository.fetchSuggestedUsers,
                  followRepository: widget.followRepository,
                  followRequestRepository: _followRequestRepository,
                  onOpenProfile: _openProfile,
                ),
              ),
            ),
          ),
        ];
      }
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: WynSpacing.space4),
              child: Text(
                'ยังไม่มีใครโพสต์อะไรเลย เป็นคนแรกสิ!',
                textAlign: TextAlign.center,
              ),
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
// widths when this was first guessed at 64 instead of measured).
// WYN-073: measured against the real widget tree via
// tester.getSize(find.byType(DecoratedBox).first) in
// home_feed_screen_test.dart, not assumed -- same "not assumed"
// discipline the SegmentedButton-era value above followed. The
// DecoratedBox wraps the whole tab row (border + text + gap + indicator
// + vertical padding), so its rendered height is the single source of
// truth rather than re-deriving it from font metrics by hand.
const double _feedModeToggleHeight = 51;

// NewPostsPill's own measured height (54 -- tester.getSize against the
// real widget tree, same "not assumed" discipline as
// _feedModeToggleHeight above) -- added on top of _feedModeToggleHeight
// only while the pill is actually shown (see build()'s
// showNewPostsPill), so the pinned block's extent grows/shrinks exactly
// in step with the pill's own visibility instead of always reserving
// dead space for it.
const double _newPostsPillHeight = 54;

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
    // show through the toggle bar.
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _FeedModeToggleHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
