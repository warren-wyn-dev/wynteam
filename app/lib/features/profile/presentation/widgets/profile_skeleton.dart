import 'package:flutter/material.dart';

import '../../../../core/design/wyn_spacing.dart';

/// Loading state for [ViewProfileScreen]'s initial fetch -- placeholder
/// shapes mirroring the eventual layout (avatar, name/username,
/// follower/following counts, action button, content grid) instead of a
/// bare CircularProgressIndicator stuck in the middle of an otherwise
/// empty screen. Static blocks, not an animated shimmer -- avoids the
/// indeterminate-animation "pumpAndSettle never settles" trap this
/// codebase has already hit and documented elsewhere (see
/// delete_account_screen_test.dart's note on why a perpetually-animating
/// CircularProgressIndicator forces plain pump()s in tests instead).
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  static const _gridPlaceholderCount = 9;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    Widget bar({required double width, double height = 14}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
          ),
        );

    Widget countPlaceholder() => Column(
          children: [
            bar(width: 28, height: 18),
            const SizedBox(height: WynSpacing.space1),
            bar(width: 60),
          ],
        );

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(WynSpacing.space6),
            child: Column(
              children: [
                CircleAvatar(radius: 40, backgroundColor: color),
                const SizedBox(height: WynSpacing.space4),
                bar(width: 140, height: 20),
                const SizedBox(height: WynSpacing.space2),
                bar(width: 90),
                const SizedBox(height: WynSpacing.space4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    countPlaceholder(),
                    const SizedBox(width: WynSpacing.space6),
                    countPlaceholder(),
                  ],
                ),
                const SizedBox(height: WynSpacing.space6),
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: _gridPlaceholderCount,
            itemBuilder: (context, index) => Container(color: color),
          ),
        ],
      ),
    );
  }
}
