import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

import '../../drop/data/drop_repository.dart';
import '../../follow/data/follow_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../data/pop.dart';
import '../data/pop_mute_preference.dart';
import '../data/pop_repository.dart';
import 'create_pop_screen.dart';
import 'widgets/pop_clip_view.dart';
import '../../../core/design/wyn_spacing.dart';

/// Screen 1 — Pop tab (Bottom Nav). A full-screen vertical swipe feed,
/// one clip at a time. See .wyn/docs/design/wyn-006-pop.md for why this
/// deliberately isn't a straight TikTok layout copy (horizontal
/// interaction row instead of a right-edge vertical rail, persisted mute
/// preference instead of resetting every launch). Per-clip rendering
/// lives in PopClipView (extracted for WYN-007 so a single clip can also
/// be shown standalone from a Home Pop card).
class PopFeedScreen extends StatefulWidget {
  const PopFeedScreen({
    super.key,
    required this.popRepository,
    required this.followRepository,
    required this.dropRepository,
    required this.profileRepository,
    required this.savedRepository,
  });

  final PopRepository popRepository;
  final FollowRepository followRepository;
  final DropRepository dropRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;

  @override
  State<PopFeedScreen> createState() => _PopFeedScreenState();
}

class _PopFeedScreenState extends State<PopFeedScreen> {
  final _pageController = PageController();
  final List<Pop> _pops = [];
  int _page = 0;
  int _currentIndex = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  bool _muted = false;
  bool _mutedPrefLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _loadMutedPref();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMutedPref() async {
    final muted = await loadPopMutedPreference();
    if (!mounted) return;
    setState(() {
      _muted = muted;
      _mutedPrefLoaded = true;
    });
  }

  Future<void> _toggleMuted() async {
    final previous = _muted;
    setState(() => _muted = !previous);
    try {
      await savePopMutedPreference(_muted);
    } catch (_) {
      if (!mounted) return;
      setState(() => _muted = previous);
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final pops = await widget.popRepository.fetchFeed(page: 0);
      if (!mounted) return;
      setState(() {
        _pops
          ..clear()
          ..addAll(pops);
        _page = 0;
        _hasMore = pops.length == PopRepository.pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลด Pop ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final pops = await widget.popRepository.fetchFeed(page: nextPage);
      if (!mounted) return;
      setState(() {
        _pops.addAll(pops);
        _page = nextPage;
        _hasMore = pops.length == PopRepository.pageSize;
      });
    } catch (_) {
      // Silent: reaching the end of a partially-loaded feed just stops
      // advancing -- swiping back doesn't need a blocking error state.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    if (index >= _pops.length - 2) _loadMore();
  }

  Future<void> _openCreatePop() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePopScreen(popRepository: widget.popRepository),
      ),
    );
    if (!mounted) return;
    if (created == true) _loadInitial();
  }

  void _removePop(String popId) {
    if (!mounted) return;
    setState(() => _pops.removeWhere((p) => p.id == popId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitial || !_mutedPrefLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrowserSystemText(_error!,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: WynSpacing.space3),
            TextButton(
                onPressed: _loadInitial,
                child: const BrowserSystemText('ลองใหม่')),
          ],
        ),
      );
    }

    if (_pops.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrowserSystemText(
              'ยังไม่มีใครโพสต์คลิปเลย เป็นคนแรกสิ!',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: WynSpacing.space3),
            FilledButton(
              onPressed: _openCreatePop,
              child: const BrowserSystemText('สร้าง Pop'),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      itemCount: _pops.length,
      itemBuilder: (context, index) {
        final pop = _pops[index];
        return PopClipView(
          key: ValueKey(pop.id),
          initialPop: pop,
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          dropRepository: widget.dropRepository,
          savedRepository: widget.savedRepository,
          isActive: index == _currentIndex,
          muted: _muted,
          onMutedToggle: _toggleMuted,
          onDeleted: () => _removePop(pop.id),
          topLeading: BrowserSystemTooltip(
              message: 'สร้าง Pop ใหม่',
              child: BrowserSystemTooltip(
                  message: null,
                  child: IconButton(
                    icon:
                        const Icon(Icons.add_box_outlined, color: Colors.white),
                    onPressed: _openCreatePop,
                  ))),
        );
      },
    );
  }
}
