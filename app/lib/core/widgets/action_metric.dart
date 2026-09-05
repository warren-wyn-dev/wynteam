import 'package:flutter/material.dart';

import '../design/wyn_spacing.dart';
import '../interaction/wyn_feedback.dart';
import '../interaction/wyn_press_scale.dart';
import '../interaction/wyn_state_pop.dart';

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

class _ActionMetricState extends State<ActionMetric> {
  /// Held while the finger is down -- WYNOS's standard press feedback
  /// (WynPressScale), which is separate from the state-change pop
  /// below: the press scale answers the touch, the pop answers the
  /// state change, and on a Like the user gets both because both things
  /// really happened.
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    // Every metric on this row is a reversible toggle (or, for comment,
    // an open) -- light, per the Interaction Feedback System's rules.
    // The generic [WynFeedback.toggle] rather than [WynFeedback.like]
    // because this one widget is the heart, the comment button, the
    // ReDrop arrows and the view count; routing it through WynFeedback
    // at all is what stops the row drifting away from the Like haptic
    // DoubleTapLike fires on the very same card.
    WynFeedback.toggle();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.count;
    final color = widget.color;
    final semanticsLabel = widget.semanticsLabel;
    final onTap = widget.onTap;

    // The short pop when the metric's *state* changes -- the heart
    // filling on Like, the arrows filling on ReDrop -- now the shared
    // [WynStatePop] rather than this widget's own controller, so the Pop
    // rail and the Club card get the exact same 220ms instead of three
    // copies that drift apart.
    Widget icon = WynStatePop(state: widget.iconState, child: widget.icon);
    // Press feedback only where there is a press to feed back: the view
    // count is display-only, and every feed card carries one, so it does
    // not need an AnimatedScale that can never move.
    if (onTap != null) {
      icon = WynPressScale(pressed: _pressed, child: icon);
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
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
          // Press state comes off the same InkWell that already owns the
          // tap -- no second gesture recogniser competing for it.
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
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
