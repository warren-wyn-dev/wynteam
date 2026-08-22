import 'package:flutter/material.dart';

import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../club/presentation/widgets/club_section.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_detail_screen.dart';
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
  });

  final HomeRepository homeRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

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

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _trendingFuture = widget.homeRepository.fetchTrending();
    _scrollController.addListener(_onScroll);
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

  // Takes only the id and re-reads the live _items[index] instead of a
  // HomeFeedItem captured at the last build -- same double-tap-safety
  // pattern as DropDetailScreen._toggleCommentLike. See
  // .wyn/learning/PATTERNS.md.
  Future<void> _toggleLike(String itemId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
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

  Future<void> _toggleSave(String itemId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
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

  static HomeFeedItem _withToggledLike(HomeFeedItem item) => HomeFeedItem(
        id: item.id,
        contentType: item.contentType,
        authorId: item.authorId,
        authorUsername: item.authorUsername,
        authorDisplayName: item.authorDisplayName,
        authorAvatarUrl: item.authorAvatarUrl,
        createdAt: item.createdAt,
        caption: item.caption,
        imageUrl: item.imageUrl,
        videoUrl: item.videoUrl,
        thumbnailUrl: item.thumbnailUrl,
        durationSeconds: item.durationSeconds,
        viewCount: item.viewCount,
        likeCount: item.likedByMe ? item.likeCount - 1 : item.likeCount + 1,
        commentCount: item.commentCount,
        likedByMe: !item.likedByMe,
        savedByMe: item.savedByMe,
      );

  static HomeFeedItem _withToggledSave(HomeFeedItem item) => HomeFeedItem(
        id: item.id,
        contentType: item.contentType,
        authorId: item.authorId,
        authorUsername: item.authorUsername,
        authorDisplayName: item.authorDisplayName,
        authorAvatarUrl: item.authorAvatarUrl,
        createdAt: item.createdAt,
        caption: item.caption,
        imageUrl: item.imageUrl,
        videoUrl: item.videoUrl,
        thumbnailUrl: item.thumbnailUrl,
        durationSeconds: item.durationSeconds,
        viewCount: item.viewCount,
        likeCount: item.likeCount,
        commentCount: item.commentCount,
        likedByMe: item.likedByMe,
        savedByMe: !item.savedByMe,
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

  Future<void> _openPop(HomeFeedItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PopSingleClipScreen(
          pop: item.toPop(),
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          dropRepository: widget.dropRepository,
          savedRepository: widget.savedRepository,
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
      body: SafeArea(
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
    );
  }

  // Fixed twice now for the same root cause (QA round 2, 2026-08-22):
  // the Design spec (.wyn/docs/design/ds-009-rainbow-accent.md, point 2)
  // specifies the active-segment indicator as a thin line placed
  // "นอก touch target เดิมของปุ่ม ไม่ทับตัวหนังสือ" (outside the
  // button's own touch target, not overlapping the text) -- i.e. a
  // separate element below the SegmentedButton, not something sharing
  // horizontal space with a label inside it. The original implementation
  // put a dot *inside* the active segment's label (competing with the
  // text for the same tight width budget), which is what caused both the
  // round-1 overflow and round-2's near-total text loss once Flexible
  // papered over the overflow. This version follows the spec literally
  // instead: segments go back to plain Text (matching the other 3
  // always), and the accent is a separate 2px bar in a dedicated strip
  // below the button, positioned under whichever segment is active.
  // SegmentedButton distributes width ~equally across its segments (see
  // the round-1 bug report's `BoxConstraints(0.0<=w<=140.0)` trace, equal
  // for every segment regardless of label length) -- LayoutBuilder splits
  // the available width the same way to line the bar up underneath.
  Widget _buildFeedModeToggle() {
    const modes = [
      _HomeFeedMode.forYou,
      _HomeFeedMode.following,
      _HomeFeedMode.latest,
      _HomeFeedMode.fromYourClubs,
    ];
    final activeIndex = modes.indexOf(_feedMode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space1),
      child: Column(
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
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 2)),
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
                label: Text('สำหรับคุณ', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              ButtonSegment(
                value: _HomeFeedMode.following,
                label: Text('ติดตาม', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              ButtonSegment(
                value: _HomeFeedMode.latest,
                label: Text('ล่าสุด', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              ButtonSegment(
                value: _HomeFeedMode.fromYourClubs,
                label: Text('จาก Club ของคุณ', maxLines: 1, overflow: TextOverflow.ellipsis),
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
          SizedBox(
            height: 2,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segmentWidth = constraints.maxWidth / modes.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      left: activeIndex * segmentWidth,
                      width: segmentWidth,
                      child: Center(
                        child: Container(
                          key: const Key('active_segment_accent'),
                          width: 24,
                          height: 2,
                          decoration: const BoxDecoration(
                            gradient: WynColors.rainbowAccent,
                            borderRadius: BorderRadius.all(Radius.circular(WynSpacing.radiusFull)),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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
                    padding: EdgeInsets.symmetric(horizontal: WynSpacing.space3),
                    child: Center(child: Text('ยังไม่มี content กำลังนิยม')),
                  );
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: WynSpacing.space2),
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
        separatorBuilder: (context, index) =>
            index + 1 < _items.length ? const Divider(height: 1) : const SizedBox.shrink(),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = _items[index];
          if (item.contentType == HomeContentType.drop) {
            return HomeDropCard(
              key: ValueKey(item.id),
              item: item,
              onTap: () => _openDrop(item),
              onToggleLike: () => _toggleLike(item.id),
              onToggleSave: () => _toggleSave(item.id),
              onOpenProfile: () => _openProfile(item.authorId),
            );
          }
          return HomePopCard(
            key: ValueKey(item.id),
            item: item,
            onTap: () => _openPop(item),
            onToggleLike: () => _toggleLike(item.id),
            onToggleSave: () => _toggleSave(item.id),
            onOpenProfile: () => _openProfile(item.authorId),
          );
        },
      ),
    );
  }
}
