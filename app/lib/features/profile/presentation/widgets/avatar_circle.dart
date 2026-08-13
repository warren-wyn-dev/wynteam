import 'package:flutter/material.dart';

/// A circular avatar image, falling back to the first letter of
/// [fallbackText] on a primary-colored background when [imageUrl] is null
/// -- per the WYN-003 design spec, never a broken-image placeholder.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.imageUrl,
    required this.fallbackText,
    this.radius = 40,
  });

  final String? imageUrl;
  final String fallbackText;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial =
        fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?';

    return Semantics(
      label: 'รูปโปรไฟล์ของ $fallbackText',
      image: true,
      // The placeholder letter is purely decorative once the label above
      // describes the avatar -- without this, screen readers announce the
      // letter a second time as redundant, confusing extra semantics.
      excludeSemantics: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primary,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        child: imageUrl == null
            ? Text(
                initial,
                style: TextStyle(
                  fontSize: radius * 0.8,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
    );
  }
}
