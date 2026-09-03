import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';

/// "มีโพสต์ใหม่" -- WYNOSHomeSpec.md 4.4. Sits directly under the sticky
/// feed-mode toggle and is itself part of that same pinned block (see
/// HomeFeedScreen's own `_FeedModeToggleHeaderDelegate` usage) --
/// deliberately never auto-prepends new content on its own; tapping it
/// is what triggers the caller's own refresh.
///
/// WYN-091 (Wynos V1.0.0 Beta2 Phase 2, item 13): the visible text used
/// to be "มีโพสต์ใหม่ {N} โพสต์" -- Founder asked for the count to be
/// dropped from what's shown on screen. [count] itself is still kept
/// (still drives whether the pill shows at all, and still feeds the
/// Semantics label below for screen readers).
class NewPostsPill extends StatelessWidget {
  const NewPostsPill({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Opaque `paper` -- same "never transparent" rule as the sticky
      // tab row above it (spec 4.3), so feed cards scrolling underneath
      // don't show through this pinned block either.
      color: WynColors.paper,
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      child: Semantics(
        label: 'มีโพสต์ใหม่ $count โพสต์ กดเพื่อโหลด',
        button: true,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: WynColors.sapphire,
                borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                boxShadow: [
                  BoxShadow(
                    color: WynColors.sapphire.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_upward, size: 13, color: WynColors.paper),
                  SizedBox(width: 6),
                  // WYN-091 (Wynos V1.0.0 Beta2 Phase 2, item 13): the
                  // visible text drops the count -- Founder: "วงน้ำเงิน
                  // ที่เขียนว่า 'มีโพสต์ใหม่ 3 โพสต์' เปลี่ยนเป็น
                  // 'มีโพสต์ใหม่'". The Semantics label above still
                  // carries $count for screen readers -- see this
                  // class's own doc comment reference.
                  Text(
                    'มีโพสต์ใหม่',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: WynColors.paper,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
