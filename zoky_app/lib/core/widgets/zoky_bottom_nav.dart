import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../design/zoky_colors.dart';
import '../design/zoky_tokens.dart';
import '../design/zoky_typography.dart';

/// One destination of [ZokyBottomNav].
class ZokyNavItem {
  const ZokyNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badgeCount = 0,
    this.badgeSemanticLabel,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int badgeCount;

  /// e.g. "{n} ออเดอร์ที่กำลังดำเนินการ" for the orders tab.
  final String? badgeSemanticLabel;
}

/// Floating pill bottom navigation (design 9.8, web `fx-nav`). Shared on
/// every platform: deliberately not CupertinoTabBar / NavigationBar because
/// the nav is part of the brand. Labels clamp at 1.3x text scale.
class ZokyBottomNav extends StatelessWidget {
  const ZokyBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<ZokyNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Distance from the bottom edge: max(8, safe-area - 12) (design 9.8).
  static double bottomOffset(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return math.max(8, safe - 12);
  }

  /// Space screens must leave free at the bottom so content can scroll
  /// clear of the floating nav.
  static double reservedHeight(BuildContext context) =>
      ZokySizes.bottomNav + bottomOffset(context) + ZokySpacing.s4;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final navWidth = math.min(width - 24, ZokySizes.navMaxWidth);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomOffset(context)),
      child: Center(
        heightFactor: 1,
        child: SizedBox(
          width: navWidth,
          height: ZokySizes.bottomNav,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: ZokyRadius.full,
              boxShadow: ZokyShadows.e4,
            ),
            child: ClipRRect(
              borderRadius: ZokyRadius.full,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ZokyColors.surface.withValues(alpha: 0.94),
                    borderRadius: ZokyRadius.full,
                    border: Border.all(
                      color: ZokyColors.neutral900.withValues(alpha: 0.06),
                    ),
                  ),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavButton(
                              item: items[i],
                              selected: i == currentIndex,
                              onTap: () => onSelected(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ZokyNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ZokyColors.actionPrimary : ZokyColors.neutral600;
    final labelStyle = selected
        ? ZokyTextStyles.weight(
            ZokyTextStyles.caption.copyWith(color: ZokyColors.actionPrimary),
            FontWeight.w700,
          )
        : ZokyTextStyles.caption.copyWith(color: ZokyColors.textSecondary);
    final badge = item.badgeCount > 0
        ? (item.badgeCount > 9 ? '9+' : '${item.badgeCount}')
        : null;

    return Semantics(
      button: true,
      selected: selected,
      label: [
        item.label,
        if (badge != null) item.badgeSemanticLabel ?? badge,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : ZokyMotion.base,
                  width: 48,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? ZokyColors.blush : Colors.transparent,
                    borderRadius: ZokyRadius.full,
                  ),
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    size: ZokySizes.iconMd,
                    color: color,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: 2,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: BoxDecoration(
                        color: ZokyColors.brandDeep,
                        borderRadius: ZokyRadius.full,
                        border: Border.all(
                          color: ZokyColors.neutral0,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge,
                        style: ZokyTextStyles.weight(
                          ZokyTextStyles.caption.copyWith(
                            color: ZokyColors.neutral0,
                            height: 1,
                          ),
                          FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
