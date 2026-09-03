import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_typography.dart';
import '../../../../core/widgets/network_thumbnail.dart';

/// A circular avatar image, falling back to the first letter of
/// [fallbackText] on a primary-colored background -- per the WYN-003
/// design spec, never a broken-image placeholder.
///
/// The fallback covers a failed load, not just a null [imageUrl]. It
/// used to only cover the null case, so an avatar whose file 404s or
/// whose request dies on a poor connection painted as an empty colored
/// circle: a follower list on bad wifi was a column of blank discs. The
/// letter can't simply be drawn underneath, because CircleAvatar paints
/// `child` *over* `backgroundImage` -- hence the small piece of state
/// below, flipped by the image's own error callback.
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

  @override
  Widget build(BuildContext context) {
    final fallbackText = widget.fallbackText;
    final radius = widget.radius;
    final initial =
        fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?';
    final imageUrl = _imageFailed ? null : widget.imageUrl;

    // An avatar is at most ~80 logical pixels across anywhere in the
    // app, but the file behind it is a full-size upload -- decoding it
    // at source size costs megabytes of bitmap per face on a follower
    // list. The ResizeImage bound is in *physical* pixels, so the avatar
    // stays sharp at every screen density; see decodeWidthFor.
    final decodeWidth = decodeWidthFor(
      radius * 2,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      backgroundImage: imageUrl == null
          ? null
          : ResizeImage.resizeIfNeeded(
              decodeWidth,
              null,
              NetworkImage(imageUrl),
            ),
      onBackgroundImageError: imageUrl == null ? null : (_, __) => _onImageError(),
      child: imageUrl == null
          ? Text(
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
            )
          : null,
    );

    return Semantics(
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
  }
}
