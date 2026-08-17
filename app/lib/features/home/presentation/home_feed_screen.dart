import 'package:flutter/material.dart';

import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../club/presentation/widgets/club_section.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_detail_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../notification/data/notification_repository.dart';
import '../../notification/presentation/notification_list_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../saved/data/saved_repository.dart';
import '../../search/presentation/search_screen.dart';
import '../../zoky/data/zoky_repository.dart';
import '../data/home_feed_item.dart';
import '../data/home_repository.dart';
import 'pop_single_clip_screen.dart';
import 'widgets/from_your_clubs_feed.dart';
import 'widgets/home_drop_card.dart';
import 'widgets/home_pop_card.dart';
import 'widgets/trending_tile.dart';
import '../../../core/design/wyn_spacing.dart';

enum _HomeFeedMode { forYou, latest, fromYourClubs }

/// Screen 1 — Home tab (Bottom Nav, index 0). A feed mixing Drop and Pop
/// content, with the CLUB section (WYN-014) between the top row and the
/// feed. Default mode is "สำหรับคุณ" (ranked, WYN-018); "ล่าสุด" is the
/// original WYN-007 chronological ordering, still one tap away. See
/// .wyn/docs/design/wyn-007-home.md, .wyn/docs/design/wyn-014-club-core.md
/// (Screen 1), and .wyn/docs/design/wyn-018-home-feed-ranking.md.
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({
    super.key,
    required this.homeRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.savedRepository,
    required this.notificationRepository,
    required this.clubRepository,
    required this.clubPostRepository,
    required this.zokyRepository,
  });

  final HomeRepository homeRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;
  final NotificationRepository notificationRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;
  final ZokyRepository zokyRepository;

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
  int _unreadNotificationCount = 0;

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
    _loadUnreadNotificationCount();
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

  // "สำหรับคุณ" (ranked, WYN-018) and "ล่าสุด" (chronological, WYN-007's
  // original behavior) share this same _items/_page state and just swap
  // which repository method feeds it -- "จาก Club ของคุณ" is a wholly
  // separate widget (FromYourClubsFeed) with its own state, untouched.
  Future<List<HomeFeedItem>> _fetchPage(int page) => _feedMode == _HomeFeedMode.forYou
      ? widget.homeRepository.fetchRankedFeed(page: page)
      : widget.homeRepository.fetchFeed(page: page);

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

  Future<void> _openPop(HomeFeedItem item, {bool openCommentsOnStart = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PopSingleClipScreen(
          pop: item.toPop(),
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          dropRepository: widget.dropRepository,
          savedRepository: widget.savedRepository,
          openCommentsOnStart: openCommentsOnStart,
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

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await widget.notificationRepository.countUnread();
      if (!mounted) return;
      setState(() => _unreadNotificationCount = count);
    } catch (_) {
      // Silent: a failed badge-count fetch just leaves the badge showing
      // its last known value (or none) -- not worth a blocking error UI
      // for a number in the corner of an icon.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationListScreen(
          notificationRepository: widget.notificationRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          savedRepository: widget.savedRepository,
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
          zokyRepository: widget.zokyRepository,
        ),
      ),
    );
    // NotificationListScreen marks everything as read on open -- refresh
    // the badge so it reflects that the moment we're back on Home.
    _loadUnreadNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopRow(context),
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

  // SegmentedButton (a view toggle on one feed), not a TabBar (a switch
  // between independent content sections) -- see the Design spec's
  // reasoning in .wyn/docs/design/wyn-015-club-discovery-integration.md,
  // Screen 5.
  Widget _buildFeedModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space1),
      child: SegmentedButton<_HomeFeedMode>(
        segments: const [
          ButtonSegment(value: _HomeFeedMode.forYou, label: Text('สำหรับคุณ')),
          ButtonSegment(value: _HomeFeedMode.latest, label: Text('ล่าสุด')),
          ButtonSegment(value: _HomeFeedMode.fromYourClubs, label: Text('จาก Club ของคุณ')),
        ],
        selected: {_feedMode},
        onSelectionChanged: (selection) {
          final newMode = selection.first;
          setState(() => _feedMode = newMode);
          // "จาก Club ของคุณ" is FromYourClubsFeed's own separate widget
          // state -- only forYou/latest share _items and need a reload
          // when switching between (or into) them.
          if (newMode != _HomeFeedMode.fromYourClubs) _loadInitial();
        },
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

  Widget _buildTopRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(child: _buildSearchBar(context)),
          const SizedBox(width: WynSpacing.space2),
          _buildNotificationButton(context),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Semantics(
      label: 'ค้นหา',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _openSearch,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space3),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: WynSpacing.space2),
                Text(
                  'ค้นหา',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    final count = _unreadNotificationCount;
    final badgeText = count > 9 ? '9+' : '$count';

    return Semantics(
      label: count > 0 ? 'การแจ้งเตือน มี $count รายการที่ยังไม่อ่าน' : 'การแจ้งเตือน',
      button: true,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _openNotifications,
          ),
          if (count > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space1, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                ),
                child: Text(
                  badgeText,
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
      return const Center(
        child: Text('ยังไม่มีใครโพสต์อะไรเลย เป็นคนแรกสิ!'),
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
            onComment: () => _openPop(item, openCommentsOnStart: true),
            onToggleLike: () => _toggleLike(item.id),
            onToggleSave: () => _toggleSave(item.id),
            onOpenProfile: () => _openProfile(item.authorId),
          );
        },
      ),
    );
  }
}
