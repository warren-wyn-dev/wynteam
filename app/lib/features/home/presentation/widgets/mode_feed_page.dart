import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/drop_detail_screen.dart';
import '../../../drop/presentation/quote_redrop_screen.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../follow/data/follow_request_repository.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/view_profile_screen.dart';
import '../../../saved/data/saved_repository.dart';
import '../../../search/data/discovery_repository.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/interaction/wyn_feedback.dart';
import '../../../../core/network_error.dart';
import '../../data/home_feed_item.dart';
import '../../data/home_repository.dart';
import '../pop_single_clip_screen.dart';
import 'add_to_home_screen_banner.dart';
import 'home_drop_card.dart';
import 'home_feed_skeleton.dart';
import 'home_pop_card.dart';
import 'new_posts_pill.dart';
import 'suggested_follow_list.dart';

/// Which ranked-feed source a [ModeFeedPage] pulls from -- "จาก Club
/// ของคุณ" is not one of these (it stays FromYourClubsFeed, which was
/// already this same shape -- its own self-contained state -- before
/// this change existed).
enum HomeFeedRankMode { forYou, following }

/// WYN-140 (2026-09-08, "อยากให้ Swipe หลายๆหน้า เหมือนแพตฟอมใหญ่ๆ"
/// follow-up): extracted from HomeFeedScreen's own State, which used to
/// hold ONE shared `_items`/`_page`/... and swap what fed it depending on
/// the active tab -- switching tabs discarded and reloaded that shared
/// state every time, and there was nowhere to hold two tabs' state at
/// once. A real swipe that shows the destination tab's own content
/// sliding in as you drag (the way Threads/IG/X do it) needs "สำหรับคุณ"
/// and "ติดตาม" each to have their OWN independent pagination/scroll
/// state, alive at the same time -- exactly the shape "Club"
/// (FromYourClubsFeed) already had as its own self-contained widget.
/// This is that same shape, applied to the other two modes.
/// HomeFeedScreen now hosts one instance of this per mode inside a real
/// PageView instead of switching a single shared list.
///
/// Every method below is a straight move from the old
/// `_HomeFeedScreenState` (same names, same logic, same doc comments
/// where still accurate) -- deliberately mechanical, not a rewrite, to
/// keep this refactor's actual behavioral risk limited to "does the
/// PageView wiring work", not "did some interaction subtly change too".
class ModeFeedPage extends StatefulWidget {
  const ModeFeedPage({
    super.key,
    required this.mode,
    required this.homeRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.savedRepository,
  });

  final HomeFeedRankMode mode;
  final HomeRepository homeRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;

  @override
  State<ModeFeedPage> createState() => ModeFeedPageState();
}

/// Public (not `_State`) so HomeFeedScreen can hold a `GlobalKey` to it
/// and forward the Home-tab-reselect scroll-to-top/refresh gesture to
/// whichever page is currently active -- see HomeFeedScreen's own
/// `_onHomeTabReselected`, which used to do this directly since there
/// was only ever one shared scroll position to forward it to.
class ModeFeedPageState extends State<ModeFeedPage>
    with AutomaticKeepAliveClientMixin<ModeFeedPage> {
  // AutomaticKeepAliveClientMixin: a PageView (unlike the single
  // CustomScrollView this used to live inside) may not keep every page
  // built once it's scrolled a couple of pages away -- without this, a
  // page swiped away from and back to would silently reset to empty and
  // reload, the exact loss-of-scroll-position problem [_refreshRow]'s own
  // doc comment already exists to avoid within a single page.
  @override
  bool get wantKeepAlive => true;

  final _scrollController = ScrollController();
  final _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final List<HomeFeedItem> _items = [];

  /// Keys of every row already shown this load cycle -- see [_loadMore]
  /// for why offset pagination can hand back a row twice. Cleared and
  /// rebuilt by [_loadInitial] along with [_items].
  final Set<String> _seenKeys = {};

  /// The tail of each row's in-flight like/save/ReDrop write chain,
  /// keyed by `action:rowKey` -- see [_serializeWrite].
  final Map<String, Future<void>> _pendingWrites = {};

  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;

  /// True when the most recent [_loadMore] failed -- swaps the trailing
  /// spinner for a tappable retry (see [_buildBodySlivers]).
  bool _loadMoreFailed = false;
  bool _hasMore = true;
  String? _error;

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
  // someone *else* has posted since this page was last (re)loaded.
  // Never auto-prepended; only ever cleared by the user tapping the
  // pill (which reloads) or reloading some other way (_loadInitial
  // resets it to 0 at the start of every fetch). Each mode now keeps
  // its own count/subscription -- forYou and ติดตาม used to share one,
  // which was accurate only because they also shared _items/_page and
  // could never disagree about what "new" meant.
  RealtimeChannel? _newPostsChannel;
  int _newPostCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
    _newPostsChannel = widget.homeRepository.subscribeToNewPosts((authorId) {
      if (!mounted || authorId == Supabase.instance.client.auth.currentUser?.id) {
        return;
      }
      setState(() => _newPostCount++);
    });
  }

  @override
  void dispose() {
    final channel = _newPostsChannel;
    if (channel != null) widget.homeRepository.unsubscribe(channel);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // _loadMoreFailed: after a failure the user asks again with the
    // retry button, rather than every scroll tick re-firing a request
    // that just failed.
    if (_isLoadingMore || !_hasMore || _loadMoreFailed) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  // WYN-064 (Tap Home Tab to Scroll to Top & Refresh): called by
  // HomeFeedScreen when the Home tab is reselected while this page is
  // the currently active PageView page.
  // Case 1 -- scrolled down (pixels > 0): animate back to the top only,
  // no refetch (matches a plain "scroll to top" tap, not a refresh).
  // Case 2 -- already at the top: trigger the same pull-to-refresh the
  // user could do manually, guarded against overlapping calls while a
  // fetch triggered by this or another interaction (initial load,
  // manual pull, "ลองใหม่" retry) is already in flight.
  void scrollToTopAndRefresh() {
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
  // scrollToTopAndRefresh's identical scroll-then-refresh shape above).
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

  Future<List<HomeFeedItem>> _fetchPage(int page) {
    switch (widget.mode) {
      case HomeFeedRankMode.forYou:
        return widget.homeRepository.fetchRankedFeed(page: page);
      case HomeFeedRankMode.following:
        return widget.homeRepository.fetchFollowingFeed(page: page);
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
      _loadMoreFailed = false;
      // A fresh load already carries every post the pill would have
      // offered to reveal -- see _newPostCount's own doc comment.
      _newPostCount = 0;
    });
    try {
      final items = await _fetchPage(0);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _seenKeys
          ..clear()
          ..addAll(items.map(_keyFor));
        _page = 0;
        _hasMore = items.length == HomeRepository.pageSize;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error =
          errorMessageFor(error, serverMessage: 'โหลด Home ไม่สำเร็จ'));
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _isLoadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final nextPage = _page + 1;
      final items = await _fetchPage(nextPage);
      if (!mounted) return;
      setState(() {
        // Offset pagination re-reads a list that may have grown at the
        // top since the previous page: someone posting while the viewer
        // scrolls shifts every row down one, so the last item of page N
        // comes back as the first item of page N+1. Appending blindly
        // showed that post twice in a row and put two identical
        // ValueKeys in one SliverList. Dropping already-present keys is
        // enough -- and cheap, since _seenKeys is maintained alongside
        // _items rather than rescanned per page.
        //
        // _hasMore is still driven by what the server returned, not by
        // what survived the filter: a full page that happens to be all
        // duplicates still means there is more behind it.
        _hasMore = items.length == HomeRepository.pageSize;
        for (final item in items) {
          if (_seenKeys.add(_keyFor(item))) _items.add(item);
        }
        _page = nextPage;
      });
    } catch (_) {
      // Not a blocking error state -- the rows already loaded stay
      // exactly as they are -- but not silent either. It used to be:
      // the spinner at the bottom simply stopped, leaving the user
      // staring at a feed that had quietly stopped growing with no way
      // to tell whether it had ended or failed, and no way to ask again
      // except to guess and scroll. [_onScroll] also won't retry on its
      // own while the list is already at its maximum extent, so without
      // a tap target a failure here can be genuinely terminal.
      if (mounted) setState(() => _loadMoreFailed = true);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// The identity of a feed row -- `id` alone isn't unique, since the
  /// same Drop can appear both plainly and via someone's ReDrop of it
  /// (WYN-034). Matches the ValueKey the itemBuilder builds, and the
  /// composite key HomeRepository uses for the same reason.
  static String _keyFor(HomeFeedItem item) =>
      '${item.id}:${item.redropId ?? ''}';

  /// Runs [write] only once every earlier write of [action] on the same
  /// row has settled, and reports whether it succeeded.
  ///
  /// Taps are never dropped -- a fast like/unlike/like is three real
  /// intentions and all three reach the server -- but they no longer
  /// *overlap*. They used to: three taps fired INSERT, DELETE, INSERT
  /// concurrently, so whichever request reached Postgres last decided
  /// the stored state, and a second INSERT racing the first hit the
  /// `(drop_id, user_id)` primary key, whose error rolled the card back
  /// to "not liked" while the like was in fact saved. Serializing per
  /// row means the last tap is always the last write. The optimistic
  /// flip the user sees still happens at tap time, before this is even
  /// called, so the card stays exactly as responsive as before.
  Future<bool> _serializeWrite(
    HomeFeedItem item,
    String action,
    Future<void> Function() write,
  ) async {
    final key = '$action:${_keyFor(item)}';
    final previous = _pendingWrites[key];
    var ok = true;
    Future<void> run() async {
      try {
        await write();
      } catch (_) {
        ok = false;
      }
    }

    // Called straight through when nothing is queued, so the very first
    // tap still issues its request synchronously rather than waiting for
    // an event-loop turn -- only a tap that actually has a predecessor
    // pays for the wait.
    final chained = previous == null ? run() : previous.then((_) => run());
    _pendingWrites[key] = chained;
    await chained;
    // Only the tail of the chain clears the entry -- an earlier link
    // finishing must not let a later tap jump the queue.
    if (identical(_pendingWrites[key], chained)) _pendingWrites.remove(key);
    return ok;
  }

  Future<void> _toggleLike(int index) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];

    setState(() => _items[index] = _withToggledLike(previous));
    final ok = await _serializeWrite(previous, 'like', () {
      if (previous.contentType == HomeContentType.drop) {
        return widget.dropRepository.toggleLike(
          dropId: previous.id,
          currentlyLiked: previous.likedByMe,
        );
      }
      return widget.popRepository.toggleLike(
        popId: previous.id,
        currentlyLiked: previous.likedByMe,
      );
    });
    if (ok || !mounted) return;
    setState(() => _items[index] = previous);
  }

  Future<void> _toggleSave(int index) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];

    setState(() => _items[index] = _withToggledSave(previous));
    // Save is reached from the card's overflow sheet, which -- unlike
    // the action row's Like -- has no haptic of its own. Fired next to
    // the optimistic state change so the buzz matches what the user
    // already sees, and rolled back silently below if the write fails.
    WynFeedback.save();
    final ok = await _serializeWrite(previous, 'save', () {
      if (previous.contentType == HomeContentType.drop) {
        return widget.dropRepository.toggleSave(
          dropId: previous.id,
          currentlySaved: previous.savedByMe,
        );
      }
      return widget.popRepository.toggleSave(
        popId: previous.id,
        currentlySaved: previous.savedByMe,
      );
    });
    if (ok || !mounted) return;
    setState(() => _items[index] = previous);
  }

  /// Standard ReDrop toggle (WYN-034) -- Pop content has no ReDrop, so
  /// unlike [_toggleLike]/[_toggleSave] this never branches on
  /// [HomeContentType]; [onToggleRedrop] is only ever wired up for
  /// drop-typed cards (see the itemBuilder below).
  Future<void> _toggleRedrop(int index) async {
    if (index < 0 || index >= _items.length) return;
    final previous = _items[index];

    setState(() => _items[index] = _withToggledRedrop(previous));
    final ok = await _serializeWrite(previous, 'redrop', () {
      return widget.dropRepository.toggleRedrop(
        dropId: previous.id,
        currentlyRedropped: previous.redroppedByMe,
      );
    });
    if (ok || !mounted) return;
    setState(() => _items[index] = previous);
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
  /// [_deleteRedrop]).
  ///
  /// WYN-079 (Wynos V1.0.0 Beta2, item 8): Founder wants a way back after
  /// hiding by mistake, so a successful hide now offers a Snackbar
  /// "เลิกทำ" (Undo) action for a few seconds -- tapping it re-inserts
  /// the item at its original position and reverses the signal via
  /// [HomeRepository.unhideContent]. Letting the Snackbar time out (or
  /// dismissing it) leaves the hide in place, same as before this task.
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
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('ไม่สนใจโพสต์นี้แล้ว'),
        action: SnackBarAction(
          label: 'เลิกทำ',
          onPressed: () => _undoHideItem(index, item),
        ),
      ),
    );
  }

  /// Reverses a hide [item] was doing right after [_hideItem] recorded
  /// it -- see that method's own doc comment. Re-inserts at [index]
  /// (nothing removes items ahead of it in that window other than more
  /// hides, which this same guard already protects against) and deletes
  /// the "hide" feed_signals row via HomeRepository.unhideContent so a
  /// later refresh doesn't exclude it again.
  Future<void> _undoHideItem(int index, HomeFeedItem item) async {
    if (!mounted) return;
    setState(() {
      final insertAt = index <= _items.length ? index : _items.length;
      _items.insert(insertAt, item);
    });
    try {
      await widget.homeRepository.unhideContent(
        contentType: item.contentType,
        contentId: item.id,
      );
    } catch (_) {
      // The item is back in the feed either way (the whole point of
      // Undo) -- a failed unhideContent just means the next fetch may
      // exclude it again, not that this tap silently did nothing.
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
    await _refreshRow(item);
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
    await _refreshRow(item);
  }

  /// Brings one card back in sync after Detail, which can change its
  /// like/save/ReDrop state and its comment count, or delete the post
  /// outright.
  ///
  /// This used to be a whole-feed `_loadInitial()`, which also reset the
  /// scroll position: the user opened the 40th post, came back, and
  /// found themselves at the top of a feed that had been rebuilt around
  /// them. Refreshing the one row they were looking at keeps everything
  /// else -- position, the rows already loaded, the pages already paged
  /// -- exactly where they left it.
  ///
  /// Located by key rather than by a captured index, because a hide or
  /// an Undo can shift positions while Detail is open. A row that is
  /// gone server-side (deleted, or newly out of view for this viewer) is
  /// removed here too. A failed refresh leaves the card as it was: a
  /// stale count is a much smaller problem than a feed that empties
  /// itself because one request timed out.
  Future<void> _refreshRow(HomeFeedItem item) async {
    final HomeFeedItem? fresh;
    try {
      fresh = await widget.homeRepository.fetchItemById(
        id: item.id,
        redropId: item.redropId,
      );
    } catch (_) {
      return;
    }
    if (!mounted) return;

    final key = _keyFor(item);
    final index = _items.indexWhere((candidate) => _keyFor(candidate) == key);
    if (index < 0) return;
    setState(() {
      if (fresh == null) {
        _items.removeAt(index);
      } else {
        _items[index] = fresh;
      }
    });
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

  // forYou keeps the pre-PageView key exactly -- it's the default tab
  // nearly every existing test already pumps against, so this is the
  // one key string this refactor does not rename. following gets a
  // distinct key since, once a PageView has both pages built, two
  // widgets sharing one Key string would make find.byKey ambiguous.
  Key get _scrollViewKey => Key(
        widget.mode == HomeFeedRankMode.forYou
            ? 'home_feed_scroll_view'
            : 'home_feed_scroll_view_following',
      );

  @override
  Widget build(BuildContext context) {
    // AutomaticKeepAliveClientMixin requires this call every build.
    super.build(context);
    final showNewPostsPill = _newPostCount > 0;

    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: _loadInitial,
      child: CustomScrollView(
        key: _scrollViewKey,
        controller: _scrollController,
        slivers: [
          // Founder feedback, 2026-09-05: removed HomeExplainerBanner
          // ("ดู → แชร์ → ค้นพบ → ซื้อ") -- the widget itself
          // (WYNOSHomeSpec.md item 1) is left in place, unmounted rather
          // than deleted, same "screens/data untouched, just no longer
          // wired up" posture as Pop/ZOKY in case Product wants it back
          // in a different spot later.
          // Founder feedback: users didn't know WYNOS (the Flutter Web
          // build) could be added to their home screen like a real app
          // icon -- renders nothing at all on native/desktop/
          // already-installed, see the widget's own doc comment.
          const SliverToBoxAdapter(child: AddToHomeScreenBanner()),
          if (showNewPostsPill)
            SliverPersistentHeader(
              pinned: true,
              delegate: _NewPostsPillHeaderDelegate(
                child: NewPostsPill(
                  count: _newPostCount,
                  onTap: _onNewPostsPillTap,
                ),
              ),
            ),
          ..._buildBodySlivers(),
        ],
      ),
    );
  }

  // Returns the sliver(s) for whichever state the page is in --
  // loading/error/empty each fill the remaining viewport (
  // SliverFillRemaining), the same visual "centered in the space below"
  // result the old Expanded(child: Center(...)) gave, just expressed as
  // a sliver so it can sit inside the same CustomScrollView as the
  // scrollable content above it.
  List<Widget> _buildBodySlivers() {
    if (_isLoadingInitial) {
      // A sliver of card-shaped placeholders rather than a spinner in an
      // empty viewport -- see HomeFeedSkeleton.
      return [
        const SliverToBoxAdapter(child: HomeFeedSkeleton()),
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
      if (widget.mode == HomeFeedRankMode.following) {
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
        key: Key(widget.mode == HomeFeedRankMode.forYou
            ? 'home_feed_list'
            : 'home_feed_list_following'),
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
              if (_loadMoreFailed) {
                return Padding(
                  padding: const EdgeInsets.all(WynSpacing.space4),
                  child: Center(
                    child: TextButton.icon(
                      key: Key(widget.mode == HomeFeedRankMode.forYou
                          ? 'home_feed_load_more_retry'
                          : 'home_feed_load_more_retry_following'),
                      onPressed: _loadMore,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('โหลดเพิ่มไม่สำเร็จ แตะเพื่อลองใหม่'),
                    ),
                  ),
                );
              }
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
                dropRepository: widget.dropRepository,
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
                // WYN-088 (Wynos V1.0.0 Beta2, item 27): Founder wants
                // the eye/view-count icon off the Home feed specifically
                // (every tab -- this widget serves both ranked modes),
                // while Profile keeps it (HomeDropCard's other call
                // sites -- profile_drop_grid_tab.dart etc. -- don't pass
                // this, so they keep the default true).
                showViewCount: false,
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
              // WYN-088 -- same reasoning as HomeDropCard's identical
              // param above.
              showViewCount: false,
            );
          },
          childCount: itemCount * 2 - 1,
        ),
      ),
    ];
  }
}

// NewPostsPill's own measured height (54 -- tester.getSize against the
// real widget tree; see home_feed_screen.dart's git history for the
// original "not assumed" measurement this constant came from) -- a
// SliverPersistentHeader clips its child to min/maxExtent rather than
// sizing to it, so this has to match the widget's real rendered height
// exactly, the same constraint _FeedModeToggleHeaderDelegate documents
// in home_feed_screen.dart.
const double _newPostsPillHeight = 54;

class _NewPostsPillHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _NewPostsPillHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => _newPostsPillHeight;

  @override
  double get maxExtent => _newPostsPillHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // A Material surface, not a transparent passthrough -- once pinned
    // above feed cards scrolling underneath, this needs its own opaque
    // background rather than letting them show through.
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _NewPostsPillHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
