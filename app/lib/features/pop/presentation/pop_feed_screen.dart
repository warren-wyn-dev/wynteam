import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/pop.dart';
import '../data/pop_repository.dart';
import 'create_pop_screen.dart';
import 'widgets/confirm_delete_pop_dialog.dart';
import 'widgets/pop_comment_sheet.dart';

/// Placeholder share link -- there's no real hosting/domain yet, same
/// situation as Drop's share link (see .wyn/tasks/approved/WYN-005-drop-post-image.md
/// Risks). Not a reachable URL; revisit once Founder confirms a real
/// domain before Deploy.
String _popShareLink(String popId) => 'https://wyn.app/pop/$popId';

const _mutedPrefKey = 'pop_muted';

/// Screen 1 — Pop tab (Bottom Nav). A full-screen vertical swipe feed,
/// one clip at a time. See .wyn/docs/design/wyn-006-pop.md for why this
/// deliberately isn't a straight TikTok layout copy (horizontal
/// interaction row instead of a right-edge vertical rail, persisted mute
/// preference instead of resetting every launch).
class PopFeedScreen extends StatefulWidget {
  const PopFeedScreen({super.key, required this.popRepository});

  final PopRepository popRepository;

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

  // Muted defaults to false (sound on) the very first time WYN is ever
  // opened, since most short-form content needs audio to make sense --
  // but from then on the user's last choice is remembered instead of
  // resetting every launch. See .wyn/docs/design/wyn-006-pop.md.
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
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _muted = prefs.getBool(_mutedPrefKey) ?? false;
      _mutedPrefLoaded = true;
    });
  }

  Future<void> _toggleMuted() async {
    setState(() => _muted = !_muted);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mutedPrefKey, _muted);
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final pops = await widget.popRepository.fetchFeed(page: 0);
      setState(() {
        _pops
          ..clear()
          ..addAll(pops);
        _page = 0;
        _hasMore = pops.length == PopRepository.pageSize;
      });
    } catch (_) {
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
    setState(() => _currentIndex = index);
    if (index >= _pops.length - 2) _loadMore();
  }

  Future<void> _openCreatePop() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePopScreen(popRepository: widget.popRepository),
      ),
    );
    if (created == true) _loadInitial();
  }

  void _removePop(String popId) {
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
            Text(_error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_pops.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ยังไม่มีใครโพสต์คลิปเลย เป็นคนแรกสิ!',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _openCreatePop,
              child: const Text('สร้าง Pop'),
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
        return _PopClipView(
          key: ValueKey(pop.id),
          initialPop: pop,
          popRepository: widget.popRepository,
          isActive: index == _currentIndex,
          muted: _muted,
          onMutedToggle: _toggleMuted,
          onOpenCreatePop: _openCreatePop,
          onDeleted: () => _removePop(pop.id),
        );
      },
    );
  }
}

class _PopClipView extends StatefulWidget {
  const _PopClipView({
    super.key,
    required this.initialPop,
    required this.popRepository,
    required this.isActive,
    required this.muted,
    required this.onMutedToggle,
    required this.onOpenCreatePop,
    required this.onDeleted,
  });

  /// Only read once, in initState -- see _PopClipViewState._pop for why.
  final Pop initialPop;
  final PopRepository popRepository;
  final bool isActive;
  final bool muted;
  final VoidCallback onMutedToggle;
  final VoidCallback onOpenCreatePop;
  final VoidCallback onDeleted;

  @override
  State<_PopClipView> createState() => _PopClipViewState();
}

class _PopClipViewState extends State<_PopClipView> {
  // Owned locally (like DropDetailScreen._drop, WYN-005) rather than read
  // from widget.initialPop on every interaction -- this widget is keyed
  // by pop id and stays mounted while inactive (only its video controller
  // gets disposed), so a captured widget-level field would go stale
  // between a rapid double-tap and the next parent rebuild. See
  // .wyn/learning/PATTERNS.md.
  late Pop _pop;
  VideoPlayerController? _controller;
  bool _initError = false;
  bool _viewRecorded = false;
  bool _isFollowing = false; // UI-only for now -- see WYN-008.

  @override
  void initState() {
    super.initState();
    _pop = widget.initialPop;
    if (widget.isActive) _initController();
  }

  @override
  void didUpdateWidget(covariant _PopClipView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initController();
    } else if (!widget.isActive && oldWidget.isActive) {
      // Dispose the moment this clip scrolls off-screen -- a vertical
      // feed that keeps every controller alive leaks memory/battery clip
      // after clip. See .wyn/docs/design/wyn-006-pop.md, Design Rules.
      _disposeController();
    }
    if (widget.muted != oldWidget.muted) {
      _controller?.setVolume(widget.muted ? 0 : 1);
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _initController() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_pop.videoUrl),
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      // Only an explicit call when starting muted -- initialize() already
      // applies the controller's default volume (1.0, i.e. unmuted) via
      // its own internal _applyVolume(), so calling setVolume(1) again
      // here would just be a redundant duplicate call in the common case.
      if (widget.muted) await controller.setVolume(0);
      await controller.play();
      setState(() {});
      _recordViewOnce();
    } catch (_) {
      if (!mounted) return;
      setState(() => _initError = true);
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    _initError = false;
    await controller?.dispose();
  }

  void _recordViewOnce() {
    if (_viewRecorded) return;
    _viewRecorded = true;
    setState(() => _pop = _pop.withExtraView());
    widget.popRepository.recordView(_pop.id).catchError((_) {
      // A failed view-count RPC isn't worth surfacing to the user --
      // the optimistic UI bump already happened and isn't rolled back.
    });
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  // Reads/mutates the local _pop field fresh each call instead of a
  // parameter captured at the last build -- same double-tap-safety
  // pattern as DropDetailScreen._toggleLike. See .wyn/learning/PATTERNS.md.
  Future<void> _toggleLike() async {
    final previous = _pop;
    setState(() => _pop = _pop.toggledLike());
    try {
      await widget.popRepository.toggleLike(
        popId: previous.id,
        currentlyLiked: previous.likedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pop = previous);
    }
  }

  Future<void> _toggleSave() async {
    final previous = _pop;
    setState(() => _pop = _pop.toggledSave());
    try {
      await widget.popRepository.toggleSave(
        popId: previous.id,
        currentlySaved: previous.savedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pop = previous);
    }
  }

  Future<void> _deletePop() async {
    final confirmed = await confirmDeletePop(context);
    if (!confirmed) return;

    try {
      await widget.popRepository.deletePop(_pop.id);
      widget.onDeleted();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบ Pop ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text: _popShareLink(_pop.id),
        title: 'Pop บน WYN',
      ),
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _popShareLink(_pop.id)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
    );
  }

  void _openComments() {
    showPopCommentSheet(
      context,
      popRepository: widget.popRepository,
      popId: _pop.id,
      onCommentCountChanged: (delta) {
        if (!mounted) return;
        setState(() {
          _pop = delta > 0 ? _pop.withExtraComment() : _pop.withRemovedComment();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final isOwnPop = _pop.authorId == currentUserId;
    final controller = _controller;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        if (controller != null && controller.value.isInitialized)
          GestureDetector(
            onTap: _togglePlayPause,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          )
        else if (_initError)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.white70, size: 40),
                SizedBox(height: 8),
                Text('โหลดคลิปไม่สำเร็จ', style: TextStyle(color: Colors.white70)),
              ],
            ),
          )
        else
          const Center(child: CircularProgressIndicator()),

        // Bottom scrim -- opaque gradient, not a blurred/translucent
        // Liquid Glass surface, per the Founder's color-direction rule.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 220,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
              ),
            ),
          ),
        ),

        Positioned(
          top: 8,
          left: 8,
          child: IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Colors.white),
            tooltip: 'สร้าง Pop ใหม่',
            onPressed: widget.onOpenCreatePop,
          ),
        ),

        Positioned(
          top: 8,
          right: 8,
          child: Semantics(
            label: widget.muted ? 'ปิดเสียงอยู่ กดเพื่อเปิดเสียง' : 'กดเพื่อปิดเสียง',
            excludeSemantics: true,
            child: IconButton(
              icon: Icon(
                widget.muted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
              ),
              onPressed: widget.onMutedToggle,
            ),
          ),
        ),

        Positioned(
          left: 12,
          right: 72,
          bottom: 72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AvatarCircle(
                    imageUrl: _pop.authorAvatarUrl,
                    fallbackText: _pop.authorUsername,
                    radius: 16,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _pop.authorNameOrUsername,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isOwnPop) ...[
                    const SizedBox(width: 8),
                    // UI-only for now -- not wired to a real Follow
                    // backend until WYN-008 ships. See
                    // .wyn/docs/design/wyn-006-pop.md, Design Rules.
                    SizedBox(
                      height: 28,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () =>
                            setState(() => _isFollowing = !_isFollowing),
                        child: Text(_isFollowing ? 'กำลังติดตาม' : 'ติดตาม'),
                      ),
                    ),
                  ],
                  if (isOwnPop)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white),
                      tooltip: 'ลบ Pop',
                      onPressed: _deletePop,
                    ),
                ],
              ),
              if (_pop.caption != null && _pop.caption!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _pop.caption!,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        // Horizontal interaction row anchored at the bottom -- reuses
        // DropDetailScreen's own interaction-row pattern instead of
        // TikTok's vertical right-edge rail. See
        // .wyn/docs/design/wyn-006-pop.md ("ทิศทางภาพรวม").
        Positioned(
          left: 12,
          right: 12,
          bottom: 16,
          child: Row(
            children: [
              Semantics(
                label:
                    _pop.likedByMe ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ' : 'กดเพื่อถูกใจ',
                excludeSemantics: true,
                child: IconButton(
                  icon: Icon(
                    _pop.likedByMe ? Icons.favorite : Icons.favorite_border,
                    color: _pop.likedByMe ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleLike,
                ),
              ),
              Text('${_pop.likeCount}', style: const TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined, color: Colors.white),
                tooltip: 'ความคิดเห็น',
                onPressed: _openComments,
              ),
              Text('${_pop.commentCount}',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                tooltip: 'แชร์',
                onPressed: _share,
              ),
              IconButton(
                icon: const Icon(Icons.link, color: Colors.white),
                tooltip: 'คัดลอกลิงก์',
                onPressed: _copyLink,
              ),
              const Spacer(),
              const Icon(Icons.visibility_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text('${_pop.viewCount}', style: const TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              Semantics(
                label: _pop.savedByMe
                    ? 'บันทึกแล้ว กดเพื่อเอาออกจาก Saved'
                    : 'กดเพื่อบันทึก',
                excludeSemantics: true,
                child: IconButton(
                  icon: Icon(
                    _pop.savedByMe ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
                  ),
                  onPressed: _toggleSave,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
