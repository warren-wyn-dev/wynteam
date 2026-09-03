import 'package:flutter/material.dart';

import '../design/wyn_spacing.dart';

/// A tappable icon+count pair used in a feed card's action bar --
/// WYNOSHomeSpec.md 4.9 (icon size, per-metric color, and the `gap-1.5`
/// 6px gap between icon and count are all spec'd per-metric, not left
/// to Material's default 48x48 IconButton hit box, which is too wide
/// to fit several evenly-`gap-5`-spaced metrics on one row). Shared by
/// [HomeDropCard] (heart/comment/repost/eye) and [HomePopCard]
/// (heart/comment/eye -- Pop has no ReDrop concept).
class ActionMetric extends StatelessWidget {
  const ActionMetric({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.count,
    required this.color,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;

  /// Nullable because HomeFeedItem.viewCount can be null (view tracking
  /// not yet backfilled for an older Drop) -- rendered as 0 either way.
  final int? count;
  final Color color;
  final String semanticsLabel;

  /// Null for a display-only, non-tappable metric (e.g. view count).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: color),
        const SizedBox(width: 6),
        Text(
          '${count ?? 0}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );

    if (onTap == null) {
      return Semantics(
        label: semanticsLabel,
        excludeSemantics: true,
        child: content,
      );
    }

    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      // The tap target is [WynSpacing.touchTargetMin] tall while the
      // *visible* icon+count stays exactly the size the spec calls for:
      // the extra height is transparent padding around the same content,
      // so nothing moves on screen.
      //
      // Before this, the action row's own math (a 17px icon plus 4px of
      // padding) gave the most-tapped controls in the whole product --
      // Like, comment, ReDrop on every feed card -- a ~25px tall target,
      // 43% under the minimum this app's own design system defines and
      // already honours in 27 other places. A row of small targets is
      // where mis-taps come from, and a mis-tapped Like is a mis-tap the
      // user has to notice and undo.
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: WynSpacing.touchTargetMin,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WynSpacing.space1,
              vertical: WynSpacing.space1,
            ),
            child: Center(widthFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}
