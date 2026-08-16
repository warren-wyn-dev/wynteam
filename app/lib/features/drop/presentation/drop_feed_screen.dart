import 'package:flutter/material.dart';

import '../../follow/data/follow_repository.dart';
import '../../home/data/home_feed_item.dart';
import '../../home/presentation/widgets/home_drop_card.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../saved/data/saved_repository.dart';
import '../data/drop.dart';
import '../data/drop_repository.dart';
import 'create_drop_screen.dart';
import 'drop_detail_screen.dart';
import '../../../core/design/wyn_spacing.dart';

/// Screen 1 — Drop tab (Bottom Nav). WYN-019: a real social feed (reusing
/// HomeDropCard, WYN-007) with For You/Following/Latest tabs, replacing
/// the old 3-column grid as this tab's default view. The grid itself
/// isn't deleted -- DropGridTile still renders ProfileDropGridTab
/// (WYN-013) -- only this tab's own layout changed. See
/// .wyn/docs/design/wyn-019-drop-feed-tabs.md.
class DropFeedScreen extends StatefulWidget {
  const DropFeedScreen({
    super.key,
    required this.dropRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
  });

  final DropRepository dropRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;

  @override
  State<DropFeedScreen> createState() => _DropFeedScreenState();
}

class _DropFeedScreenState extends State<DropFeedScreen> {
  // Bumped after successfully creating a Drop, and folded into each tab's
  // key below -- forces all 3 tabs to remount and refetch so a freshly
  // created Drop shows up immediately, same "bump a key to force reload"
  // approach RootShell already uses for its Profile tab.
  int _feedVersion = 0;

  Future<void> _openCreateDrop() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateDropScreen(dropRepository: widget.dropRepository),
      ),
    );
    if (created == true) setState(() => _feedVersion++);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Drop'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined),
              tooltip: 'สร้าง Drop ใหม่',
              onPressed: _openCreateDrop,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'For You'),
              Tab(text: 'Following'),
              Tab(text: 'Latest'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DropTabFeed(
              key: ValueKey('for_you_$_feedVersion'),
              fetchPage: widget.dropRepository.fetchRankedFeed,
              emptyMessage: 'ยังไม่มีใครแชร์รูปเลย เป็นคนแรกสิ!',
              dropRepository: widget.dropRepository,
              followRepository: widget.followRepository,
              profileRepository: widget.profileRepository,
              popRepository: widget.popRepository,
              savedRepository: widget.savedRepository,
            ),
            _DropTabFeed(
              key: ValueKey('following_$_feedVersion'),
              fetchPage: widget.dropRepository.fetchFollowingFeed,
              emptyMessage: 'ยังไม่ได้ follow ใครเลย ลองดู For You เพื่อค้นหาคนน่าสนใจ',
              dropRepository: widget.dropRepository,
              followRepository: widget.followRepository,
              profileRepository: widget.profileRepository,
              popRepository: widget.popRepository,
              savedRepository: widget.savedRepository,
            ),
            _DropTabFeed(
              key: ValueKey('latest_$_feedVersion'),
              fetchPage: widget.dropRepository.fetchFeed,
              emptyMessage: 'ยังไม่มีใครแชร์รูปเลย เป็นคนแรกสิ!',
              dropRepository: widget.dropRepository,
              followRepository: widget.followRepository,
              profileRepository: widget.profileRepository,
              popRepository: widget.popRepository,
              savedRepository: widget.savedRepository,
            ),
          ],
        ),
      ),
    );
  }
}

/// One tab's independent scroll/pagination/like/save state -- each tab
/// (For You/Following/Latest) gets its own instance, so switching tabs
/// doesn't share or clobber another tab's loaded page. Renders with
/// HomeDropCard (WYN-007) via HomeFeedItem.fromDrop rather than a new
/// card, per the Design spec's reuse decision.
class _DropTabFeed extends StatefulWidget {
  const _DropTabFeed({
    super.key,
    required this.fetchPage,
    required this.emptyMessage,
    required this.dropRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
  });

  final Future<List<Drop>> Function({required int page}) fetchPage;
  final String emptyMessage;
  final DropRepository dropRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;

  @override
  State<_DropTabFeed> createState() => _DropTabFeedState();
}

class _DropTabFeedState extends State<_DropTabFeed>
    with AutomaticKeepAliveClientMixin<_DropTabFeed> {
  final _scrollController = ScrollController();

  final List<Drop> _drops = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
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
      final drops = await widget.fetchPage(page: 0);
      setState(() {
        _drops
          ..clear()
          ..addAll(drops);
        _page = 0;
        _hasMore = drops.length == DropRepository.pageSize;
      });
    } catch (_) {
      setState(() => _error = 'โหลด Drop ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final drops = await widget.fetchPage(page: nextPage);
      setState(() {
        _drops.addAll(drops);
        _page = nextPage;
        _hasMore = drops.length == DropRepository.pageSize;
      });
    } catch (_) {
      // Silent: an infinite-scroll load-more failure doesn't need a
      // blocking error state -- scrolling again just retries it.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
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
    // The detail screen can change like/comment/save state or delete the
    // Drop entirely -- reload rather than trying to sync partial state
    // back into the feed, same approach the old grid used.
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

  Future<void> _toggleLike(String dropId) async {
    final index = _drops.indexWhere((d) => d.id == dropId);
    if (index == -1) return;
    final previous = _drops[index];

    setState(() => _drops[index] = previous.toggledLike());
    try {
      await widget.dropRepository.toggleLike(
        dropId: dropId,
        currentlyLiked: previous.likedByMe,
      );
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
      await widget.dropRepository.toggleSave(
        dropId: dropId,
        currentlySaved: previous.savedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _drops[index] = previous);
    }
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
          child: Text(widget.emptyMessage, textAlign: TextAlign.center),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.separated(
        key: const Key('drop_feed_list'),
        controller: _scrollController,
        itemCount: _drops.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) =>
            index + 1 < _drops.length ? const Divider(height: 1) : const SizedBox.shrink(),
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
            onTap: () => _openDropDetail(drop),
            onToggleLike: () => _toggleLike(drop.id),
            onToggleSave: () => _toggleSave(drop.id),
            onOpenProfile: () => _openProfile(drop.authorId),
          );
        },
      ),
    );
  }
}
