import 'package:flutter/material.dart';

import '../design/wynos_home_tokens.dart';
import '../../features/profile/presentation/widgets/avatar_circle.dart';

/// [AvatarCircle] with the WYNOS Home Feed's sapphire ring (SPEC.md
/// Section 3: "Avatar ring: outer circle = inner circle size + 6px,
/// ring is `1px solid #1B3A6B33`, positioned absolutely around the
/// avatar, not affecting layout size"). A thin wrapper rather than a
/// change to [AvatarCircle] itself -- that widget is shared by many
/// screens outside this task's scope (Chat, Profile, Settings, ...),
/// and WYN-072 only re-skins the Home Feed screen. Used by both
/// HomeDropCard and HomePopCard (WYN-072).
class WynosRingedAvatar extends StatelessWidget {
  const WynosRingedAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackText,
    this.radius = 16,
  });

  final String? imageUrl;
  final String fallbackText;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final outer = radius * 2 + 6;
    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: WynosHomeTokens.sapphireRing,
                width: 1,
              ),
            ),
          ),
          AvatarCircle(
            imageUrl: imageUrl,
            fallbackText: fallbackText,
            radius: radius,
          ),
        ],
      ),
    );
  }
}
