import 'package:flutter/material.dart';

import '../design/wynos_home_tokens.dart';

/// WYNOS Home reference spec 4.6 -- an official account's verified
/// badge: a sapphire-filled check, no border. Uses Material's own
/// `Icons.verified` (a badge outline with the checkmark cut out of the
/// glyph itself) rather than a two-tone icon library asset -- rendered
/// in a single color, that cutout already reads as "sapphire badge,
/// paper-colored check" against this feature's paper background,
/// without needing separate fill/stroke layering no icon font in this
/// app's dependencies actually supports.
class WynosVerifiedBadge extends StatelessWidget {
  const WynosVerifiedBadge({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'บัญชีที่ยืนยันแล้ว',
      image: true,
      excludeSemantics: true,
      child: Icon(
        Icons.verified,
        size: size,
        color: WynosHomeColors.sapphire,
      ),
    );
  }
}
