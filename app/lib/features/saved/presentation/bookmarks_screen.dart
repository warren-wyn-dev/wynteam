import 'package:flutter/material.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/widgets/empty_state_block.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_detail_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../home/data/home_feed_item.dart';
import '../../home/presentation/pop_single_clip_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../data/saved_repository.dart';
import 'widgets/saved_post_row.dart';

/// 15-bookmarks.tsx -- the real destination behind Side Menu's "บันทึกไว้"
/// row and Profile's own bookmark icon (`ViewProfileScreen._openSaved`).
///
/// Renders the mockup's own full-width post-row list (avatar+name+time+
/// caption+like/comment/repost, with a per-row bookmark button that
/// unsaves immediately) via [SavedPostRow] -- its own pagination against
/// [SavedRepository], separate from [ProfileSavedTab]'s 3-column grid on
/// a profile's own Saved tab, which stays exactly as it was (see
/// SavedPostRow's own doc comment for why this isn't a shared widget).
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({
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
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final _scrollController = ScrollController();
  final List<HomeFeedItem> _items = [];
  /// Keys of every row already shown this load cycle. Offset pagination
  /// re-reads a list that can have grown at the top since the previous
  /// page -- one new row shifts everything down by one, so the last row
  /// of page N comes back as the first row of page N+1. Appended
  /// blindly that showed the row twice *and* put two identical
  /// [ValueKey]s in one list, which Flutter rejects outright: the
  /// screen throws rather than merely looking wrong. Home already
  /// guards its feed this way (see HomeFeedScreen's own _seenKeys);
  /// this list never got the same treatment.
  final Set<String> _seenKeys = {};

  /// The identity of a row -- `id` alone isn't unique, since the same
  /// Drop can appear both plainly and via someone's ReDrop of it
  /// (WYN-034). Matches the [ValueKey] the itemBuilder builds.
  static String _keyFor(HomeFeedItem item) =>
      '${item.id}:${item.redropId ?? ''}';

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
      final items = await widget.savedRepository.fetchFeed(page: 0);
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _seenKeys
          ..clear()
          ..addAll(items.map(_keyFor));
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
        // _hasMore is still driven by what the server returned, not
        // by what survived the filter: a full page that happens to be
        // all duplicates still means there is more behind it.
        for (final item in items) {
          if (_seenKeys.add(_keyFor(item))) _items.add(item);
        }
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

  /// Unsaves [item] (the row's bookmark button) -- removes it from the
  /// list optimistically, same revert-on-failure shape as HomeFeedScreen's
  /// own `_toggleLike`/`_toggleSave`, except this removes the row outright
  /// rather than flipping a field: a Bookmarks screen only ever shows
  /// saved items, so "unsaved" has nothing left to render here.
  Future<void> _unsave(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];

    setState(() => _items.removeAt(index));
    try {
      if (item.contentType == HomeContentType.drop) {
        await widget.dropRepository.toggleSave(
          dropId: item.id,
          currentlySaved: true,
        );
      } else {
        await widget.popRepository.toggleSave(
          popId: item.id,
          currentlySaved: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _items.insert(index, item));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('บันทึกไว้', style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: _buildBody(),
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
        child: EmptyStateBlock(
          icon: Icons.bookmark_border,
          title: 'ยังไม่มีโพสต์ที่บันทึกไว้',
          subtitle: 'กดไอคอนบันทึกที่โพสต์ไหนก็ได้ เพื่อเก็บไว้ดูทีหลัง',
        ),
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
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = _items[index];
          return SavedPostRow(
            key: ValueKey(item.id),
            item: item,
            isLast: index == _items.length - 1,
            onTap: () => _openItem(item),
            onOpenProfile: () => _openProfile(item.authorId),
            onUnsave: () => _unsave(index),
          );
        },
      ),
    );
  }
}
