import 'package:flutter/material.dart';

import '../../../drop/data/drop.dart';
import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/drop_detail_screen.dart';
import '../../../drop/presentation/widgets/drop_grid_tile.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../saved/data/saved_repository.dart';
import '../../data/profile_repository.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Drop grid tab on a profile (WYN-013) -- reuses DropGridTile as-is,
/// same 3-column layout as DropFeedScreen (WYN-005), but scoped to one
/// author via DropRepository.fetchByAuthor instead of the global feed.
class ProfileDropGridTab extends StatefulWidget {
  const ProfileDropGridTab({
    super.key,
    required this.dropRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
    required this.authorId,
    required this.emptyText,
    this.onlyWithImages = false,
  });

  final DropRepository dropRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final String authorId;
  final String emptyText;

  /// WYN-071: Profile's "Media" tab reuses this widget as-is, scoped to
  /// Drops that actually have an image (see DropRepository.
  /// fetchByAuthor's own doc comment) -- "Posts" (the default, `false`)
  /// keeps showing every Drop, image or not.
  final bool onlyWithImages;

  @override
  State<ProfileDropGridTab> createState() => _ProfileDropGridTabState();
}

class _ProfileDropGridTabState extends State<ProfileDropGridTab>
    with AutomaticKeepAliveClientMixin {
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
      final drops = await widget.dropRepository.fetchByAuthor(
        authorId: widget.authorId,
        page: 0,
        onlyWithImages: widget.onlyWithImages,
      );
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
      final drops = await widget.dropRepository.fetchByAuthor(
        authorId: widget.authorId,
        page: nextPage,
        onlyWithImages: widget.onlyWithImages,
      );
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

    if (_drops.isEmpty) {
      return Center(child: Text(widget.emptyText));
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
                final drop = _drops[index];
                return DropGridTile(
                  drop: drop,
                  onTap: () => _openDropDetail(drop),
                );
              },
              childCount: _drops.length,
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
