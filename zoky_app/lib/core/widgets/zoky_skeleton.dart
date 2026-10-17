import 'package:flutter/material.dart';

import '../design/zoky_colors.dart';
import '../design/zoky_tokens.dart';

/// Shimmering placeholder block (design 9.12, web `fx-skel`). Becomes a
/// static block when the platform asks for reduced motion.
class ZokySkeleton extends StatefulWidget {
  const ZokySkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = ZokyRadius.sm,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<ZokySkeleton> createState() => _ZokySkeletonState();
}

class _ZokySkeletonState extends State<ZokySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ZokyMotion.shimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              gradient: LinearGradient(
                begin: Alignment(-1 + 2 * t - 1, 0),
                end: Alignment(-1 + 2 * t + 1, 0),
                colors: const [
                  ZokyColors.skeletonBase,
                  ZokyColors.skeletonHighlight,
                  ZokyColors.skeletonBase,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton matching [ZokyStoreCard]'s shape (4:3 photo + two lines).
class ZokyStoreCardSkeleton extends StatelessWidget {
  const ZokyStoreCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AspectRatio(
          aspectRatio: 4 / 3,
          child: ZokySkeleton(borderRadius: ZokyRadius.lg),
        ),
        const SizedBox(height: ZokySpacing.s4),
        const ZokySkeleton(height: 16),
        const SizedBox(height: ZokySpacing.s3),
        FractionallySizedBox(
          widthFactor: 0.6,
          child: const ZokySkeleton(height: 12),
        ),
      ],
    );
  }
}
