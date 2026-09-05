import 'package:flutter/material.dart';

import '../../../drop/data/drop.dart';
import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/drop_detail_screen.dart';
import '../../../drop/presentation/quote_redrop_screen.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../home/data/home_feed_item.dart';
import '../../../home/presentation/widgets/home_drop_card.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../saved/data/saved_repository.dart';
import '../../data/profile_repository.dart';
import '../view_profile_screen.dart';
import '../../../../core/design/wyn_spacing.dart';

/// "Likes" tab on a profile -- WYN-071 Design, Screen 6; restyled to
/// 05-profile.tsx's full-width PostRow (same [HomeDropCard] reuse as
/// [ProfileDropGridTab] -- see that file's own doc comment) instead of
/// the old 3-column grid. Backed by DropRepository.fetchLikedByAuthor.
/// Public to any viewer (Founder decision 2026-08-24) -- see that
/// method's own doc comment on why no new RLS was needed for this.
class ProfileLikesTab extends StatefulWidget {
  const ProfileLikesTab({
    super.key,
    required this.dropRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
    required this.authorId,
    required this.emptyText,
    this.onRefreshHeader,
  });

  final DropRepository dropRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final String authorId;
  final String emptyText;

  // WYN-081 (Wynos V1.0.0 Beta2, item 16): see ProfileDropGridTab's
  // identical field for why this exists.
  final VoidCallback? onRefreshHeader;

  @override
  State<ProfileLikesTab> createState() => _ProfileLikesTabState();
}

class _ProfileLikesTabState extends State<ProfileLikesTab>
    with AutomaticKeepAliveClientMixin {
  final List<Drop> _drops = [];

  /// Keys of every row already shown this load cycle. Offset pagination
  /// re-reads a list that can have grown at the top since the previous
  /// page -- one new row shifts everything down by one, so the last row
  /// of page N comes back as the first row of page N+1. Appended
  /// blindly that showed the row twice *and* put two identical
  /// [ValueKey]s in one list, which Flutter rejects outright: the tab
  /// throws rather than merely looking wrong. Home already guards its
  /// feed this way (see HomeFeedScreen's own _seenKeys); these lists
  /// never got the same treatment.
  final Set<String> _seenKeys = {};

  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  // WYN-099: only meaningful (and only fetched) when _drops comes back
  // empty on the initial load -- distinguishes "no Likes yet" (true,
  // the ordinary/default case for literally every profile before this
  // task) from "not allowed to see this tab" (false) per that
  // profile's own likes_visibility. Left null until that one extra
  // check actually runs, so a non-empty tab never pays for it at all.
  bool? _canViewLikes;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  // WYN-110: see ProfileDropGridTab's identical doc comment -- this
  // tab is now one of NestedScrollView's inner scrollables, which owns
  // the controller itself, so pagination detection moved from a
  // private ScrollController's listener to notification bubbling.
  bool _onScrollNotification(ScrollNotification notification) {
    if (_isLoadingMore || !_hasMore) return false;
    if (notification.metrics.pixels >
        notification.metrics.maxScrollExtent - 300) {
      // Not called directly: this notification can fire mid-layout (a
      // ballistic correction dispatches ScrollStartNotification from
      // inside RenderViewport.performLayout when the content shrinks
      // under an active scroll position), and setState from inside
      // layout is illegal ("Build scheduled during frame"). Deferring
      // one frame is what every NotificationListener-driven infinite
      // scroll needs for exactly this reason.
      // QA-WYN-110-001: the guard above reads _isLoadingMore at
      // notification time, but a single drag can dispatch several
      // ScrollUpdateNotifications before the frame boundary the
      // callback below waits for -- each one would see the same
      // not-yet-true guard and schedule its own _loadMore(), firing
      // the same page fetch several times over for one crossing of
      // the threshold. Setting the field here, synchronously, closes
      // that window; _loadMore() still does its own setState (needed
      // for anything that actually renders from this flag) once the
      // deferred call runs.
      _isLoadingMore = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
    }
    return false;
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final drops = await widget.dropRepository.fetchLikedByAuthor(
        authorId: widget.authorId,
        page: 0,
      );
      bool? canView = _canViewLikes;
      if (drops.isEmpty) {
        try {
          canView =
              await widget.profileRepository.canViewLikes(widget.authorId);
        } catch (_) {
          // Fails open to "true" (shows the ordinary "no Likes yet"
          // empty text) -- same fail-open posture as every other
          // best-effort identity-summary fetch in this codebase, and
          // strictly less alarming than falsely claiming a privacy
          // block that isn't real.
          canView = true;
        }
      }
      setState(() {
        _drops
          ..clear()
          ..addAll(drops);
        _seenKeys
          ..clear()
          ..addAll(drops.map((d) => d.id));
        _page = 0;
        _hasMore = drops.length == DropRepository.pageSize;
        _canViewLikes = canView;
      });
    } catch (_) {
      setState(() => _error = 'โหลดรายการที่ถูกใจไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  // Only used by RefreshIndicator's pull gesture, not initState's own
  // first load -- see [onRefreshHeader]'s doc comment.
  Future<void> _onPullToRefresh() async {
    widget.onRefreshHeader?.call();
    await _loadInitial();
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final drops = await widget.dropRepository.fetchLikedByAuthor(
        authorId: widget.authorId,
        page: nextPage,
      );
      setState(() {
        for (final drop in drops) {
          if (_seenKeys.add(drop.id)) _drops.add(drop);
        }
        _page = nextPage;
        _hasMore = drops.length == DropRepository.pageSize;
      });
    } catch (_) {
      // Silent -- same posture as ProfileDropGridTab's own load-more.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _toggleLike(String dropId) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final previous = _drops[index];
    setState(() => _drops[index] = previous.toggledLike());
    try {
      await widget.dropRepository
          .toggleLike(dropId: dropId, currentlyLiked: previous.likedByMe);
    } catch (_) {
      if (!mounted) return;
      setState(() => _drops[index] = previous);
    }
  }

  Future<void> _toggleSave(String dropId) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final previous = _drops[index];
    setState(() => _drops[index] = previous.toggledSave());
    try {
      await widget.dropRepository
          .toggleSave(dropId: dropId, currentlySaved: previous.savedByMe);
    } catch (_) {
      if (!mounted) return;
      setState(() => _drops[index] = previous);
    }
  }

  Future<void> _toggleRedrop(String dropId) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final previous = _drops[index];
    setState(() => _drops[index] = previous.toggledRedrop());
    try {
      await widget.dropRepository.toggleRedrop(
        dropId: dropId,
        currentlyRedropped: previous.redroppedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _drops[index] = previous);
    }
  }

  Future<void> _votePoll(String dropId, int optionIndex) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final previous = _drops[index];
    setState(() => _drops[index] = previous.votedPoll(optionIndex));
    try {
      await widget.dropRepository.votePoll(
        pollId: previous.pollId!,
        optionIndex: optionIndex,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _drops[index] = previous);
    }
  }

  Future<void> _quoteRedrop(String dropId) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final drop = _drops[index];

    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuoteRedropScreen(
          dropRepository: widget.dropRepository,
          drop: drop,
        ),
      ),
    );
    if (posted != true || !mounted) return;
    final currentIndex = _drops.indexWhere((d) => d.id == dropId);
    if (currentIndex == -1) return;
    setState(
        () => _drops[currentIndex] = _drops[currentIndex].withExtraRedrop());
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

  Future<void> _openDropDetail(Drop drop) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          dropRepository: widget.dropRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          drop: drop,
        ),
      ),
    );
    await _refreshRow(drop.id);
  }

  /// Brings one row back in sync after Detail instead of rebuilding the
  /// whole tab -- see ProfileDropGridTab._refreshRow's doc comment for
  /// the full reasoning (this tab had the identical `_loadInitial()`
  /// call, and lost scroll position the same way).
  ///
  /// One extra rule here that the Posts tab doesn't need: this is the
  /// *Likes* tab, so a post the viewer unliked while in Detail no
  /// longer belongs in it and is removed, exactly as a deleted post is.
  Future<void> _refreshRow(String dropId) async {
    final Drop? fresh;
    try {
      fresh = await widget.dropRepository.fetchById(dropId);
    } catch (_) {
      return;
    }
    if (!mounted) return;

    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index < 0) return;
    setState(() {
      if (fresh == null || !fresh.likedByMe) {
        _drops.removeAt(index);
      } else {
        _drops[index] = fresh;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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

    if (_drops.isEmpty) {
      // WYN-099: "not allowed to see this" is a distinct, intentional
      // state -- not an error, and not the ordinary "no Likes yet"
      // empty text (see [_canViewLikes]'s own doc comment).
      return Center(
        child: Text(
          _canViewLikes == false
              ? 'บัญชีนี้ซ่อนรายการที่ถูกใจไว้'
              : widget.emptyText,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onPullToRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        // WYN-110: see ProfileDropGridTab's identical doc comment on
        // why no SliverOverlapAbsorber/Injector pair is needed here.
        child: CustomScrollView(
          slivers: [
            SliverList.separated(
              itemCount: _drops.length + (_hasMore ? 1 : 0),
              separatorBuilder: (context, index) => index + 1 < _drops.length
                  ? const Divider(height: 1)
                  : const SizedBox.shrink(),
              itemBuilder: (context, index) {
                if (index >= _drops.length) {
                  return const Padding(
                    padding: EdgeInsets.all(WynSpacing.space4),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final drop = _drops[index];
                return HomeDropCard(
                  key: ValueKey(drop.id),
                  item: HomeFeedItem.fromDrop(drop),
                  dropRepository: widget.dropRepository,
                  onTap: () => _openDropDetail(drop),
                  onToggleLike: () => _toggleLike(drop.id),
                  onToggleSave: () => _toggleSave(drop.id),
                  onOpenProfile: () => _openProfile(drop.authorId),
                  onToggleRedrop: () => _toggleRedrop(drop.id),
                  onQuoteRedrop: () => _quoteRedrop(drop.id),
                  onVotePoll: (optionIndex) => _votePoll(drop.id, optionIndex),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
