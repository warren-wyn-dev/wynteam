import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/zoky_colors.dart';
import '../design/zoky_tokens.dart';
import '../design/zoky_typography.dart';
import 'zoky_3d_icon.dart';

/// One destination of [ZokyBottomNav].
class ZokyNavItem {
  const ZokyNavItem({
    required this.label,
    required this.glyph,
    this.badgeCount = 0,
    this.badgeSemanticLabel,
  });

  final String label;

  /// Drawn as a gray line icon when unselected and as the glossy 3D pink
  /// icon (same path) when selected.
  final Zoky3DGlyph glyph;
  final int badgeCount;

  /// e.g. "{n} ออเดอร์ที่กำลังดำเนินการ" for the orders tab.
  final String? badgeSemanticLabel;
}

/// Full-width bottom tab bar (design 9.8, Home Phase 5). Shared on every
/// platform: deliberately not CupertinoTabBar / NavigationBar because the
/// nav is part of the brand.
///
/// White "glossy control" surface (white -> faint pink, pink hairline on
/// top, soft pink shadow upward). It extends under the home indicator and
/// pads its items by the bottom safe-area inset. Unselected: gray line
/// icon + gray label; selected: glossy 3D pink icon + bold pink label.
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

  /// Height of the item row, above the bottom safe-area inset.
  static const double contentHeight = 56;

  /// Icon size of every item (line and 3D share it).
  static const double iconSize = 26;

  /// Labels stop growing at this text scale so the bar never overflows.
  static const double maxLabelScale = 1.2;

  /// Bottom of the bar's surface gradient (labels' worst-case background).
  static const Color surfaceBottom = Color(0xFFFFF7FA);

  /// Pink-tinted hairline along the top edge.
  static const Color hairline = Color(0x80F9C0DE);

  /// Total painted height: items + bottom safe-area inset.
  static double barHeight(BuildContext context) =>
      contentHeight + MediaQuery.paddingOf(context).bottom;

  /// Space screens must leave free at the bottom so the last content row
  /// scrolls fully clear of the nav (bar height + an 8pt gap).
  static double reservedHeight(BuildContext context) =>
      barHeight(context) + ZokySpacing.s4;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ZokyColors.surface, surfaceBottom],
          ),
          border: Border(top: BorderSide(color: hairline, width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14EE226E), // #EE226E @ 8%
              offset: Offset(0, -2),
              blurRadius: 16,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ZokySizes.navMaxWidth,
              ),
              child: SizedBox(
                height: contentHeight,
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: maxLabelScale,
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavButton(
                            item: items[i],
                            selected: i == currentIndex,
                            duration: reduceMotion
                                ? Duration.zero
                                : ZokyMotion.base,
                            onTap: () {
                              if (i != currentIndex) {
                                HapticFeedback.selectionClick();
                              }
                              onSelected(i);
                            },
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
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final ZokyNavItem item;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 12pt (one step above caption) so the Thai tone marks stay legible.
    final base = ZokyTextStyles.caption.copyWith(fontSize: 12);
    final labelStyle = selected
        ? ZokyTextStyles.weight(
            base.copyWith(color: ZokyColors.actionPrimary),
            FontWeight.w700,
          )
        : ZokyTextStyles.weight(
            base.copyWith(color: ZokyColors.textSecondary),
            FontWeight.w500,
          );
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
      // The tap action must live on this node: excludeSemantics drops the
      // InkResponse's own action.
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        splashColor: ZokyColors.blush.withValues(alpha: 0.6),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox.square(
                  dimension: ZokyBottomNav.iconSize,
                  child: AnimatedSwitcher(
                    duration: duration,
                    switchInCurve: ZokyMotion.standard,
                    switchOutCurve: ZokyMotion.exit,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.85,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Zoky3DIcon(
                      item.glyph,
                      key: ValueKey(selected),
                      size: ZokyBottomNav.iconSize,
                      style: selected
                          ? Zoky3DIconStyle.glossy
                          : Zoky3DIconStyle.line,
                      lineColor: ZokyColors.neutral600,
                    ),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -10,
                    top: -5,
                    child: _Badge(text: badge),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedDefaultTextStyle(
                duration: duration,
                curve: ZokyMotion.standard,
                style: labelStyle,
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: ZokyColors.brandDeep,
        borderRadius: ZokyRadius.full,
        border: Border.all(color: ZokyColors.neutral0, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: ZokyTextStyles.weight(
          ZokyTextStyles.caption.copyWith(
            color: ZokyColors.neutral0,
            height: 1,
          ),
          FontWeight.w700,
        ),
      ),
    );
  }
}
