import 'package:flutter/material.dart';

import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/drop_detail_screen.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../home/data/home_feed_item.dart';
import '../../../home/presentation/pop_single_clip_screen.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../saved/data/saved_repository.dart';
import '../../../saved/presentation/widgets/saved_grid_tile.dart';
import '../../data/profile_repository.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Saved tab on a profile (WYN-013) -- only ever shown for the current
/// user's own profile (see ViewProfileScreen). Drop and Pop mixed in one
/// grid sorted by save time, same 3-column layout as the other two
/// profile tabs.
class ProfileSavedTab extends StatefulWidget {
  const ProfileSavedTab({
    super.key,
    required this.savedRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
  });

  final SavedRepository savedRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;

  @override
  State<ProfileSavedTab> createState() => _ProfileSavedTabState();
}

class _ProfileSavedTabState extends State<ProfileSavedTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final List<HomeFeedItem> _items = [];
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
      final items = await widget.savedRepository.fetchFeed(page: 0);
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _page = 0;
        _hasMore = items.length == SavedRepository.pageSize;
      });
    } catch (_) {
      setState(() => _error = 'โหลดรายการที่บันทึกไว้ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final items = await widget.savedRepository.fetchFeed(page: nextPage);
      setState(() {
        _items.addAll(items);
        _page = nextPage;
        _hasMore = items.length == SavedRepository.pageSize;
      });
    } catch (_) {
      // Silent: an infinite-scroll load-more failure doesn't need a
      // blocking error state -- scrolling again just retries it.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openItem(HomeFeedItem item) async {
    if (item.contentType == HomeContentType.drop) {
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
    } else {
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
    }
    _loadInitial();
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

    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Text(
            'ยังไม่มีอะไรที่บันทึกไว้ ลองกดบันทึก Drop หรือ Pop ที่ชอบดูสิ',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _items[index];
                return SavedGridTile(
                  item: item,
                  onTap: () => _openItem(item),
                );
              },
              childCount: _items.length,
            ),
          ),
          if (_hasMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(WynSpacing.space4),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
