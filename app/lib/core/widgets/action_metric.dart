import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/wyn_spacing.dart';

/// A tappable icon+count pair used in a feed card's action bar --
/// WYNOSHomeSpec.md 4.9 (icon size, per-metric color, and the `gap-1.5`
/// 6px gap between icon and count are all spec'd per-metric, not left
/// to Material's default 48x48 IconButton hit box, which is too wide
/// to fit several evenly-`gap-5`-spaced metrics on one row). Shared by
/// [HomeDropCard] (heart/comment/repost/eye) and [HomePopCard]
/// (heart/comment/eye -- Pop has no ReDrop concept).
class ActionMetric extends StatefulWidget {
  const ActionMetric({
    super.key,
    required this.icon,
    required this.iconState,
    required this.count,
    required this.color,
    required this.semanticsLabel,
    required this.onTap,
  });

  /// The glyph itself, already sized and coloured by the caller.
  ///
  /// WYN-108: was an [IconData], which could only ever be a Material
  /// icon. The Like heart is WYN's own shape now ([WynHeartIcon]), and a
  /// widget is the only thing both it and a plain [Icon] are.
  final Widget icon;

  /// What "the state this metric is in" means for the pop animation --
  /// `likedByMe` for the heart, the icon for everything else.
  ///
  /// The animation used to fire on the [IconData] changing, which worked
  /// only because Like was the one metric whose glyph swapped. A widget
  /// cannot be compared that way (two identically-configured widgets are
  /// not equal), so the thing that actually changed is now passed
  /// explicitly rather than inferred.
  final Object iconState;

  /// Nullable because HomeFeedItem.viewCount can be null (view tracking
  /// not yet backfilled for an older Drop) -- rendered as 0 either way.
  final int? count;
  final Color color;
  final String semanticsLabel;

  /// Null for a display-only, non-tappable metric (e.g. view count).
  final VoidCallback? onTap;

  @override
  State<ActionMetric> createState() => _ActionMetricState();
}

class _ActionMetricState extends State<ActionMetric>
    with SingleTickerProviderStateMixin {
  // A single, short pop when the metric's *state* changes -- the heart
  // filling on Like, the arrows filling on ReDrop. Tapping Like was the
  // most-used interaction in the product and had no feedback at all
  // beyond the colour swapping instantly; every mature feed acknowledges
  // it. Driven off the icon changing (rather than fired from the tap)
  // so it plays for the real state change, including one that arrives
  // from elsewhere, and does NOT play while scrolling builds new cards.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.75, end: 1)
      .animate(CurvedAnimation(parent: _pop, curve: Curves.easeOutBack));

  @override
  void didUpdateWidget(covariant ActionMetric oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.iconState != widget.iconState) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Matches ViewProfileScreen's own Follow button, which already
    // pairs its state change with a light impact.
    HapticFeedback.lightImpact();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.count;
    final color = widget.color;
    final semanticsLabel = widget.semanticsLabel;
    final onTap = widget.onTap;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(scale: _scale, child: widget.icon),
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
          onTap: _handleTap,
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
