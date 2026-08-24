import 'package:flutter/material.dart';

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
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../saved/data/saved_repository.dart';
import '../data/home_feed_item.dart';
import '../data/home_repository.dart';
import 'pop_single_clip_screen.dart';
import 'widgets/from_your_clubs_feed.dart';
import 'widgets/home_drop_card.dart';
import 'widgets/home_pop_card.dart';
import 'widgets/trending_tile.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';

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
  });

  final HomeRepository homeRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

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

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _trendingFuture = widget.homeRepository.fetchTrending();
    _scrollController.addListener(_onScroll);
    _loadUnreadChatCount();
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
            child: Column(
              children: [
                ClubSection(
                  clubRepository: widget.clubRepository,
                  clubPostRepository: widget.clubPostRepository,
                ),
                _buildTrendingSection(),
                _buildFeedModeToggle(),
                Expanded(
                  child: _feedMode == _HomeFeedMode.fromYourClubs
                      ? FromYourClubsFeed(
                          key: const Key('from_your_clubs_feed'),
                          clubRepository: widget.clubRepository,
                          clubPostRepository: widget.clubPostRepository,
                        )
                      : _buildBody(),
                ),
              ],
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

  // Fixed 3 times now for variations of the same root cause. QA rounds
  // 2-4 (.wyn/tasks/bugs/WYN-024-segmented-button-active-label-
  // illegible-all-segments.md) measured that `SegmentedButton` always
  // clamps every segment's width to `constraints.maxWidth / childCount`
  // when given a bounded incoming width (confirmed by reading Flutter's
  // own segmented_button.dart -- `_calculateHorizontalChildSize`'s
  // `math.min(childWidth, constraints.maxWidth / childCount)`), so no
  // amount of padding/icon trimming inside the widget can ever fully
  // solve legibility for a label whose natural width exceeds 1/4 of a
  // real phone's screen. AI Design's decision (.wyn/docs/design/wyn-024-
  // segmented-feed-mode-scrollable.md): stop giving it a bounded width
  // at all -- `SingleChildScrollView` gives its child an UNBOUNDED
  // width, and `IntrinsicWidth` resolves that to the widget's true
  // intrinsic width (`computeMaxIntrinsicWidth` sums the *widest single
  // segment's* natural width, uniform across all 4 -- SegmentedButton
  // does not support per-segment varying widths, only uniform), so
  // `constraints.maxWidth / childCount` in the clamp above becomes a
  // no-op: every segment gets exactly as much width as the widest one
  // (currently "จาก Club ของคุณ") needs, guaranteeing none are ever
  // truncated again. The row simply scrolls horizontally once that
  // total width exceeds the screen -- on anything wide enough to fit
  // all 4 without scrolling, this is visually identical to before.
  //
  // The Design spec (.wyn/docs/design/ds-009-rainbow-accent.md, point 2)
  // specifies the active-segment indicator as a thin line placed "นอก
  // touch target เดิมของปุ่ม ไม่ทับตัวหนังสือ" -- a separate strip below
  // the button. Since every segment is now genuinely, exactly equal-
  // width (not just approximately, as when this was still `_isExpanded`-
  // stretched to the screen), the indicator's own even-split formula
  // stays correct -- `CrossAxisAlignment.stretch` on the wrapping Column
  // forces the indicator strip's own LayoutBuilder to measure the exact
  // same width `SegmentedButton` resolved to (both are stretched to the
  // Column's IntrinsicWidth-resolved width), so the two never drift out
  // of sync with each other.
  Widget _buildFeedModeToggle() {
    const modes = [
      _HomeFeedMode.forYou,
      _HomeFeedMode.following,
      _HomeFeedMode.latest,
      _HomeFeedMode.fromYourClubs,
    ];
    final activeIndex = modes.indexOf(_feedMode);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space3, vertical: WynSpacing.space1),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_HomeFeedMode>(
                // Bug fix (QA round 3, 2026-08-22): the Material selected-
                // checkmark icon (`Icons.check`, shown by default whenever a
                // segment is selected) eats a fixed chunk of whichever
                // segment happens to be active, on top of SegmentedButton's
                // already-equal 4-way width division -- QA round 3 measured
                // that this squeezes EVERY segment's label to ~1-3 visible
                // characters at real phone widths when it's the active one,
                // including "สำหรับคุณ" (the default active segment on first
                // load, no tap needed). Selection state is already shown by
                // each segment's own fill/outline color change (Material's
                // default `SegmentedButton` styling), so the checkmark icon is
                // redundant here -- turning it off gives that reclaimed width
                // back to the label instead.
                showSelectedIcon: false,
                style: const ButtonStyle(
                  padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 2)),
                  visualDensity: VisualDensity.compact,
                ),
                // Bug fix (QA round 2, 2026-08-22): plain Text with no
                // maxLines/overflow wraps to multiple lines rather than
                // overflowing horizontally when a segment's width is tight --
                // Flutter only ever throws the layout-overflow assertion for
                // the *last* line once `maxLines` caps it, never for
                // unbounded wrapping. Every segment (not just the widest one)
                // gets `maxLines: 1` + ellipsis so all 4 stay a single line
                // and the same height regardless of which one is active,
                // instead of "จาก Club ของคุณ" ballooning the whole row's
                // height into a tall column of 1-2-character lines whenever
                // it's selected on a narrow phone (confirmed via screenshot
                // at 360px before this fix).
                segments: const [
                  ButtonSegment(
                    value: _HomeFeedMode.forYou,
                    label: Text('สำหรับคุณ',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  ButtonSegment(
                    value: _HomeFeedMode.following,
                    label: Text('ติดตาม',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  ButtonSegment(
                    value: _HomeFeedMode.latest,
                    label: Text('ล่าสุด',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  ButtonSegment(
                    value: _HomeFeedMode.fromYourClubs,
                    label: Text('จาก Club ของคุณ',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
                selected: {_feedMode},
                onSelectionChanged: (selection) {
                  final newMode = selection.first;
                  setState(() => _feedMode = newMode);
                  // "จาก Club ของคุณ" is FromYourClubsFeed's own separate
                  // widget state -- only forYou/following/latest share
                  // _items and need a reload when switching between (or
                  // into) them.
                  if (newMode != _HomeFeedMode.fromYourClubs) _loadInitial();
                },
              ),
              const SizedBox(height: WynSpacing.space1),
              // `LayoutBuilder` deliberately avoided here -- it doesn't
              // support being asked for intrinsic dimensions
              // (`IntrinsicWidth` above needs every descendant to answer
              // that), so a `LayoutBuilder` anywhere inside this subtree
              // throws. A `Row` of `Expanded` children divides its own
              // resolved width evenly by construction, matching
              // `SegmentedButton`'s 4 equal-width segments (see the fix
              // comment above) without ever needing to read
              // `constraints.maxWidth` directly.
              SizedBox(
                height: 2,
                child: Row(
                  children: [
                    for (var i = 0; i < modes.length; i++)
                      Expanded(
                        child: Center(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            opacity: i == activeIndex ? 1 : 0,
                            child: Container(
                              key: i == activeIndex
                                  ? const Key('active_segment_accent')
                                  : null,
                              width: 24,
                              height: 2,
                              decoration: const BoxDecoration(
                                gradient: WynColors.rainbowAccent,
                                borderRadius: BorderRadius.all(
                                    Radius.circular(WynSpacing.radiusFull)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildBody() {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      // "ติดตาม" gets a join-prompt message (mirrors WYN-019's Drop tab
      // Following-tab wording, adapted to this screen's Thai segment
      // labels) rather than the generic "be the first" one, which reads
      // wrong when the real issue is "you aren't following anyone yet".
      final message = _feedMode == _HomeFeedMode.following
          ? 'ยังไม่ได้ follow ใครเลย ลองดู สำหรับคุณ เพื่อค้นหาคนน่าสนใจ'
          : 'ยังไม่มีใครโพสต์อะไรเลย เป็นคนแรกสิ!';
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.separated(
        key: const Key('home_feed_list'),
        controller: _scrollController,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        // A hairline divider between posts only (DS-003) -- never before
        // the loading spinner at the end, which isn't content. Material
        // 3's default Divider colors itself from colorScheme.outlineVariant
        // (WynColors.borderSubtleLight/Dark), so no color is hardcoded here.
        separatorBuilder: (context, index) => index + 1 < _items.length
            ? const Divider(height: 1)
            : const SizedBox.shrink(),
        itemBuilder: (context, index) {
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
      ),
    );
  }
}
