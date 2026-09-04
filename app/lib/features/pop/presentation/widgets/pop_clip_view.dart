import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/widgets/hashtag_text.dart';
import '../../../drop/data/drop_repository.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/view_profile_screen.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../../saved/data/saved_repository.dart';
import '../../data/pop.dart';
import '../../data/pop_repository.dart';
import 'confirm_delete_pop_dialog.dart';
import 'pop_comment_sheet.dart';
import '../../../../core/design/wyn_spacing.dart';

/// wynos.online is the real, owned domain (see .wyn/company/DECISIONS.md,
/// "live ที่ https://wynos.online แล้ว") -- wyn.app was never WYN's, and
/// sharing it sent people to a GoDaddy domain-parking page instead of
/// this content. Pop itself is unmounted from normal navigation
/// (WYN-102), so this link currently resolves to the "not available"
/// message in content_link.dart, same as a push notification for old
/// Pop activity.
String popShareLink(String popId) => 'https://wynos.online/pop/$popId';

/// One full-screen clip: video playback, scrim overlay, and the
/// Like/Comment/Share/Save/View interaction row. Extracted out of
/// PopFeedScreen (WYN-006) so a single clip can also be shown standalone
/// -- e.g. from a Pop card tapped in Home (WYN-007) -- without duplicating
/// this widget's video-controller-lifecycle logic and interaction
/// handlers. See .wyn/docs/design/wyn-006-pop.md and
/// .wyn/docs/design/wyn-007-home.md.
class PopClipView extends StatefulWidget {
  const PopClipView({
    super.key,
    required this.initialPop,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.dropRepository,
    required this.savedRepository,
    required this.isActive,
    required this.muted,
    required this.onMutedToggle,
    required this.onDeleted,
    this.topLeading,
    this.openCommentsOnStart = false,
  });

  /// Only read once, in initState -- see _PopClipViewState._pop for why.
  final Pop initialPop;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final DropRepository dropRepository;
  final SavedRepository savedRepository;
  final bool isActive;
  final bool muted;
  final VoidCallback onMutedToggle;
  final VoidCallback onDeleted;

  /// Shown top-left instead of nothing -- PopFeedScreen passes a "create
  /// Pop" button (it owns the whole tab), a standalone single-clip screen
  /// (opened from a Home Pop card) passes a back button instead. Null
  /// renders nothing there.
  final Widget? topLeading;

  /// WYN-023 (R2): when true, opens the comment sheet immediately
  /// instead of waiting for the viewer to tap the Comment icon
  /// themselves -- set by [PopSingleClipScreen] only when it was
  /// opened from a Home Pop card's Comment icon specifically (never
  /// from tapping the card itself, and never by PopFeedScreen's own
  /// callers, which never pass this at all -- default false leaves
  /// them unaffected).
  final bool openCommentsOnStart;

  @override
  State<PopClipView> createState() => _PopClipViewState();
}

class _PopClipViewState extends State<PopClipView> {
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

  // Whether the *current viewer* follows the Pop's author -- null until
  // the real status has loaded from the backend. See
  // DropDetailScreen._isFollowing (WYN-008) for why this stays hidden
  // rather than defaulting to false.
  bool? _isFollowing;

  @override
  void initState() {
    super.initState();
    _pop = widget.initialPop;
    if (widget.isActive) _initController();
    if (_pop.authorId != Supabase.instance.client.auth.currentUser!.id) {
      _loadFollowStatus();
    }
    if (widget.openCommentsOnStart) {
      // showModalBottomSheet needs a BuildContext attached to a built
      // widget tree -- calling _openComments() directly here would run
      // before this widget has actually built. See PATTERNS.md's
      // postFrameCallback entries for the same reasoning elsewhere.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openComments();
      });
    }
  }

  Future<void> _loadFollowStatus() async {
    try {
      final isFollowing =
          await widget.followRepository.isFollowing(userId: _pop.authorId);
      if (!mounted) return;
      setState(() => _isFollowing = isFollowing);
    } catch (_) {
      // Leave _isFollowing null -- the button stays hidden rather than
      // showing a possibly-wrong state.
    }
  }

  Future<void> _toggleFollow() async {
    final previous = _isFollowing;
    if (previous == null) return;
    setState(() => _isFollowing = !previous);
    try {
      await widget.followRepository.toggleFollow(
        userId: _pop.authorId,
        currentlyFollowing: previous,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFollowing = previous);
    }
  }

  @override
  void didUpdateWidget(covariant PopClipView oldWidget) {
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
      if (!mounted) return;
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
        text: popShareLink(_pop.id),
        title: 'Pop บน WYN',
      ),
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: popShareLink(_pop.id)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
    );
  }

  void _openAuthorProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: _pop.authorId,
        ),
      ),
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
                SizedBox(height: WynSpacing.space2),
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
                colors: [Colors.transparent, WynColors.imageScrimStrong],
              ),
            ),
          ),
        ),

        if (widget.topLeading != null)
          Positioned(top: 8, left: 8, child: widget.topLeading!),

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
                  Flexible(
                    child: InkWell(
                      onTap: _openAuthorProfile,
                      borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AvatarCircle(
                            imageUrl: _pop.authorAvatarUrl,
                            fallbackText: _pop.authorUsername,
                            radius: 16,
                          ),
                          const SizedBox(width: WynSpacing.space2),
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
                        ],
                      ),
                    ),
                  ),
                  if (!isOwnPop && _isFollowing != null) ...[
                    const SizedBox(width: WynSpacing.space2),
                    Semantics(
                      label: _isFollowing!
                          ? 'กำลังติดตาม กดเพื่อเลิกติดตาม'
                          : 'กดเพื่อติดตาม',
                      excludeSemantics: true,
                      child: SizedBox(
                        height: 28,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: _toggleFollow,
                          child: Text(_isFollowing! ? 'กำลังติดตาม' : 'ติดตาม'),
                        ),
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
                const SizedBox(height: WynSpacing.space2),
                HashtagText(
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
                    color: _pop.likedByMe ? WynColors.iconLikeActive : Colors.white,
                  ),
                  onPressed: _toggleLike,
                ),
              ),
              Text('${_pop.likeCount}', style: const TextStyle(color: Colors.white)),
              const SizedBox(width: WynSpacing.space2),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined, color: Colors.white),
                tooltip: 'ความคิดเห็น',
                onPressed: _openComments,
              ),
              Text('${_pop.commentCount}',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(width: WynSpacing.space2),
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
              const SizedBox(width: WynSpacing.space1),
              Text('${_pop.viewCount}', style: const TextStyle(color: Colors.white)),
              const SizedBox(width: WynSpacing.space2),
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
