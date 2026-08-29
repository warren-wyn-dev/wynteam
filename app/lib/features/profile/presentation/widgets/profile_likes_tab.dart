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
  });

  final DropRepository dropRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final String authorId;
  final String emptyText;

  @override
  State<ProfileLikesTab> createState() => _ProfileLikesTabState();
}

class _ProfileLikesTabState extends State<ProfileLikesTab>
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
      final drops = await widget.dropRepository.fetchLikedByAuthor(
        authorId: widget.authorId,
        page: 0,
      );
      setState(() {
        _drops
          ..clear()
          ..addAll(drops);
        _page = 0;
        _hasMore = drops.length == DropRepository.pageSize;
      });
    } catch (_) {
      setState(() => _error = 'โหลดรายการที่ถูกใจไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
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
        _drops.addAll(drops);
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
    setState(() => _drops[currentIndex] = _drops[currentIndex].withExtraRedrop());
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
      child: ListView.separated(
        controller: _scrollController,
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
    );
  }
}
