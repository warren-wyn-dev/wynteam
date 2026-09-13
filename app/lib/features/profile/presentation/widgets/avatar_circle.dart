import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_typography.dart';
import '../../../../core/widgets/network_thumbnail.dart';
import '../../../home/presentation/widgets/home_card_metrics.dart'
    show homeCardAvatarDiameter, homeCardAvatarTopInset;

/// A circular avatar image, falling back to the first letter of
/// [fallbackText] on a primary-colored background -- per the WYN-003
/// design spec, never a broken-image placeholder.
///
/// On iOS Web the image deliberately goes through [Image.network] with
/// WYNOS's HTML-image strategy rather than CircleAvatar.backgroundImage.
/// That keeps full-size profile/Club uploads out of CanvasKit texture memory,
/// which is the same mitigation used by post images in the feed.
class AvatarCircle extends StatefulWidget {
  const AvatarCircle({
    super.key,
    required this.imageUrl,
    required this.fallbackText,
    this.radius = 40,
    this.ring = false,
  });

  final String? imageUrl;
  final String fallbackText;
  final double radius;

  /// design-reference SPEC.md, Section 3: draws the 1px sapphire-at-20%
  /// ring around the avatar (outer diameter = avatar diameter + 6px,
  /// positioned around the avatar without changing its own layout size).
  /// Defaults to false so every existing call site keeps its current,
  /// ring-less look unless a screen opts in.
  final bool ring;

  @override
  State<AvatarCircle> createState() => _AvatarCircleState();
}

class _AvatarCircleState extends State<AvatarCircle> {
  bool _imageFailed = false;

  @override
  void didUpdateWidget(covariant AvatarCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new URL deserves a fresh attempt -- e.g. the viewer just changed
    // their own photo (uploadAvatar appends a `?v=` cache-buster, so the
    // URL really does change) after a previous one failed to load.
    if (oldWidget.imageUrl != widget.imageUrl) _imageFailed = false;
  }

  void _onImageError() {
    if (!mounted || _imageFailed) return;
    // The image stream can report an error while a frame is being built
    // or painted, where setState is illegal -- defer to the end of the
    // frame in that case rather than only sometimes working.
    switch (SchedulerBinding.instance.schedulerPhase) {
      case SchedulerPhase.persistentCallbacks:
      case SchedulerPhase.midFrameMicrotasks:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _imageFailed = true);
        });
      case SchedulerPhase.idle:
      case SchedulerPhase.transientCallbacks:
      case SchedulerPhase.postFrameCallbacks:
        setState(() => _imageFailed = true);
    }
  }

  bool _isHomeFeedPostAvatar(BuildContext context) {
    // Home feed cards already expose a card-level Semantics label. Use that
    // existing context to apply the Founder-approved vertical alignment only
    // to the 40px post avatar, leaving every other AvatarCircle untouched.
    var isHomePost = false;
    context.visitAncestorElements((element) {
      final ancestor = element.widget;
      if (ancestor is Semantics) {
        final label = ancestor.properties.label;
        final isPostLabel = label != null &&
            (label.startsWith('รูปของ ') || label.startsWith('วิดีโอของ '));
        if (ancestor.properties.button == true && isPostLabel) {
          isHomePost = true;
          return false;
        }
      }
      return true;
    });
    return isHomePost &&
        (widget.radius - (homeCardAvatarDiameter / 2)).abs() < 0.001;
  }

  Widget _fallbackAvatar(
    BuildContext context, {
    required String initial,
    required double radius,
  }) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.primary,
      child: Center(
        child: BrowserSystemText(
          initial,
          // design-reference SPEC.md, Section 2: the avatar initial is
          // one of the few spots outside the header wordmark/empty-
          // state headline that every reference screen (Profile,
          // Edit Profile, Notifications, ...) independently renders
          // in the screen-title style.
          style: WynTypography.screenTitle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallbackText = widget.fallbackText;
    final radius = widget.radius;
    final initial =
        fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?';
    final imageUrl = _imageFailed ? null : widget.imageUrl;

    // Native/engine-backed images still get a physical-pixel decode bound.
    // Flutter Web ignores cacheWidth, so iOS Web instead uses the shared HTML
    // image strategy below and never promotes these avatars to CanvasKit
    // textures. This matters because avatar uploads are stored at source size
    // and a feed can show many different users/Clubs while scrolling.
    final decodeWidth = decodeWidthFor(
      radius * 2,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );

    final fallback = _fallbackAvatar(
      context,
      initial: initial,
      radius: radius,
    );

    final avatar = SizedBox.square(
      dimension: radius * 2,
      child: ClipOval(
        child: imageUrl == null
            ? fallback
            : ColoredBox(
                color: Theme.of(context).colorScheme.primary,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  webHtmlElementStrategy: wynNetworkImageStrategy,
                  cacheWidth: decodeWidth,
                  errorBuilder: (context, error, stackTrace) {
                    _onImageError();
                    // Keep the same solid primary placeholder for this frame;
                    // the scheduled state update swaps in the initial next.
                    return ColoredBox(
                      color: Theme.of(context).colorScheme.primary,
                    );
                  },
                ),
              ),
      ),
    );

    final semanticAvatar = Semantics(
      label: 'รูปโปรไฟล์ของ $fallbackText',
      image: true,
      // The placeholder letter is purely decorative once the label above
      // describes the avatar -- without this, screen readers announce the
      // letter a second time as redundant, confusing extra semantics.
      excludeSemantics: true,
      child: widget.ring
          ? Container(
              width: radius * 2 + 6,
              height: radius * 2 + 6,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: WynColors.sapphireRing),
                ),
              ),
              child: avatar,
            )
          : avatar,
    );

    if (!_isHomeFeedPostAvatar(context)) return semanticAvatar;
    return Padding(
      padding: const EdgeInsets.only(top: homeCardAvatarTopInset),
      child: semanticAvatar,
    );
  }
}
