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
import '../data/home_feed_item.dart';
import '../data/home_repository.dart';
import 'pop_single_clip_screen.dart';
import 'widgets/from_your_clubs_feed.dart';
import 'widgets/home_drop_card.dart';
import 'widgets/home_pop_card.dart';

enum _HomeFeedMode { forYou, fromYourClubs }

/// Screen 1 — Home tab (Bottom Nav, index 0). A single chronological feed
/// mixing Drop and Pop content, with the CLUB section (WYN-014) between
/// the top row and the feed. See .wyn/docs/design/wyn-007-home.md and
/// .wyn/docs/design/wyn-014-club-core.md (Screen 1).
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

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _loadUnreadNotificationCount();
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

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final items = await widget.homeRepository.fetchFeed(page: 0);
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
      final items = await widget.homeRepository.fetchFeed(page: nextPage);
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
            _buildFeedModeToggle(),
            Expanded(
              child: _feedMode == _HomeFeedMode.forYou
                  ? _buildBody()
                  : FromYourClubsFeed(
                      key: const Key('from_your_clubs_feed'),
                      clubRepository: widget.clubRepository,
                      clubPostRepository: widget.clubPostRepository,
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SegmentedButton<_HomeFeedMode>(
        segments: const [
          ButtonSegment(value: _HomeFeedMode.forYou, label: Text('สำหรับคุณ')),
          ButtonSegment(value: _HomeFeedMode.fromYourClubs, label: Text('จาก Club ของคุณ')),
        ],
        selected: {_feedMode},
        onSelectionChanged: (selection) => setState(() => _feedMode = selection.first),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(child: _buildSearchBar(context)),
          const SizedBox(width: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 12),
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
      child: ListView.builder(
        key: const Key('home_feed_list'),
        controller: _scrollController,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
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
