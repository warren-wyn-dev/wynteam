import 'package:flutter/material.dart';

import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_detail_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../data/home_feed_item.dart';
import '../data/home_repository.dart';
import 'pop_single_clip_screen.dart';
import 'search_placeholder_screen.dart';
import 'widgets/home_drop_card.dart';
import 'widgets/home_pop_card.dart';

/// Screen 1 — Home tab (Bottom Nav, index 0). A single chronological feed
/// mixing Drop and Pop content. See .wyn/docs/design/wyn-007-home.md.
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({
    super.key,
    required this.homeRepository,
    required this.dropRepository,
    required this.popRepository,
  });

  final HomeRepository homeRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;

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
        ),
      ),
    );
    _loadInitial();
  }

  void _openSearchPlaceholder() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchPlaceholderScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(context),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Semantics(
        label: 'ค้นหา ยังไม่พร้อมใช้งาน',
        button: true,
        excludeSemantics: true,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _openSearchPlaceholder,
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
                    'ค้นหา (เร็ว ๆ นี้)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
            );
          }
          return HomePopCard(
            key: ValueKey(item.id),
            item: item,
            onTap: () => _openPop(item),
            onToggleLike: () => _toggleLike(item.id),
            onToggleSave: () => _toggleSave(item.id),
          );
        },
      ),
    );
  }
}
