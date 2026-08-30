import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_typography.dart';

/// A circular avatar image, falling back to the first letter of
/// [fallbackText] on a primary-colored background when [imageUrl] is null
/// -- per the WYN-003 design spec, never a broken-image placeholder.
class AvatarCircle extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final initial =
        fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?';

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
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
      child: ring
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
