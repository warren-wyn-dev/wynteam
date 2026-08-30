import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../data/drop.dart';
import '../../data/drop_repository.dart';
import '../drop_detail_screen.dart' show dropShareLink;

/// Full-screen, swipeable, pinch-to-zoom image viewer -- WYN-071 Design,
/// Screen 4. Opened by tapping a multi-image Drop's gallery in
/// DropDetailScreen (see DropImageGallery). Always an ink background
/// regardless of the app's light theme -- 20-image-viewer.tsx's own doc
/// comment: "the one screen in the app that intentionally breaks from
/// the light palette, the way a lightbox does in most apps."
///
/// Also renders the reference's like/share/save action row. This is a
/// separate pushed route from DropDetailScreen, so rather than calling
/// back into DropDetailScreen's own [DropDetailScreen] state (which
/// would leave this viewer's icons stale if a toggle fails and reverts
/// while the viewer is still open), like/save get their own optimistic
/// toggle + revert-on-failure here -- the same shape DropDetailScreen
/// and HomeFeedScreen each already keep their own copy of for the same
/// reason (see those files' own `_toggleLike`/`_toggleSave`). [onDropChanged]
/// fires after every local update (including a revert) so the caller can
/// keep its own `Drop` in sync in real time, regardless of how this
/// route eventually closes.
class DropImageViewer extends StatefulWidget {
  const DropImageViewer({
    super.key,
    required this.drop,
    required this.imageUrls,
    required this.dropRepository,
    required this.onDropChanged,
    this.initialIndex = 0,
  });

  final Drop drop;
  final List<String> imageUrls;
  final DropRepository dropRepository;

  /// Called with the updated [Drop] every time this viewer's own local
  /// like/save state changes (optimistic toggle or a failed-call revert)
  /// -- lets the caller (DropDetailScreen) keep its own copy in sync
  /// live, rather than only once when this route closes.
  final ValueChanged<Drop> onDropChanged;

  final int initialIndex;

  @override
  State<DropImageViewer> createState() => _DropImageViewerState();
}

class _DropImageViewerState extends State<DropImageViewer> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;
  late Drop _drop = widget.drop;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final previous = _drop;
    setState(() => _drop = _drop.toggledLike());
    widget.onDropChanged(_drop);
    try {
      await widget.dropRepository.toggleLike(
        dropId: previous.id,
        currentlyLiked: previous.likedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _drop = previous);
      widget.onDropChanged(_drop);
    }
  }

  Future<void> _toggleSave() async {
    final previous = _drop;
    setState(() => _drop = _drop.toggledSave());
    widget.onDropChanged(_drop);
    try {
      await widget.dropRepository.toggleSave(
        dropId: previous.id,
        currentlySaved: previous.savedByMe,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _drop = previous);
      widget.onDropChanged(_drop);
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: dropShareLink(_drop.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Semantics(
                    label: 'ปิด',
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 22, color: WynColors.paper),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: WynColors.paper.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) => InteractiveViewer(
                  child: Center(
                    child: Image.network(widget.imageUrls[index]),
                  ),
                ),
              ),
            ),
            if (widget.imageUrls.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),
                child: Semantics(
                  label:
                      'รูปที่ ${_currentIndex + 1} จาก ${widget.imageUrls.length}',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.imageUrls.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _currentIndex ? 14 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2.5),
                            color: i == _currentIndex
                                ? WynColors.paper
                                : WynColors.paper.withValues(alpha: 0.33),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                WynSpacing.space6, 0, WynSpacing.space6, WynSpacing.space8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    label: _drop.likedByMe
                        ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ'
                        : 'กดเพื่อถูกใจ',
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: Icon(
                        _drop.likedByMe ? Icons.favorite : Icons.favorite_border,
                        size: 22,
                        color: _drop.likedByMe ? Colors.red : WynColors.paper,
                      ),
                      onPressed: _toggleLike,
                    ),
                  ),
                  const SizedBox(width: WynSpacing.space6),
                  Semantics(
                    label: 'แชร์',
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(Icons.send_outlined, size: 20, color: WynColors.paper),
                      onPressed: _share,
                    ),
                  ),
                  const SizedBox(width: WynSpacing.space6),
                  Semantics(
                    label: _drop.savedByMe
                        ? 'บันทึกแล้ว กดเพื่อเอาออกจาก Saved'
                        : 'กดเพื่อบันทึก',
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: Icon(
                        _drop.savedByMe ? Icons.bookmark : Icons.bookmark_border,
                        size: 20,
                        color: _drop.savedByMe ? WynColors.sapphire : WynColors.paper,
                      ),
                      onPressed: _toggleSave,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
