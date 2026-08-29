import 'package:flutter/material.dart';

import '../design/wynos_home_tokens.dart';

/// WYNOS Home reference spec, section 3 -- wraps an avatar (any circular
/// widget of diameter [size]) with the one shared avatar ring: an outer
/// circle 6px wider than the avatar itself, drawn as a 1px sapphire-at-
/// 20%-opacity border positioned absolutely around it so it never
/// affects layout size. Shared by the post avatar (Feature 6+) and the
/// empty state's suggested-follow rows (Feature 3) -- built once here
/// instead of duplicating the ring math at each call site.
class WynosAvatarRing extends StatelessWidget {
  const WynosAvatarRing({super.key, required this.size, required this.child});

  /// Diameter of [child] itself, not including the ring.
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final outer = size + WynosHomeSpacing.avatarRingExtra;
    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: WynosHomeColors.sapphireRing, width: 1),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
