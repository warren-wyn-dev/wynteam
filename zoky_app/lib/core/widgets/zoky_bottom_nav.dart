import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/zoky_colors.dart';
import '../design/zoky_tokens.dart';
import '../design/zoky_typography.dart';
import 'zoky_3d_icon.dart';
import 'zoky_nav_icon.dart';

/// One destination of [ZokyBottomNav].
class ZokyNavItem {
  const ZokyNavItem({
    required this.label,
    required this.glyph,
    this.badgeCount = 0,
    this.showDot = false,
    this.badgeSemanticLabel,
    this.appleIcons,
  });

  final String label;

  /// Drawn as a gray line icon when unselected and as the glossy 3D pink
  /// icon (same path) when selected.
  final Zoky3DGlyph glyph;

  /// Count badge ("9+" above nine). Takes precedence over [showDot].
  final int badgeCount;

  /// Small notification dot at the icon's top-right (e.g. unread messages).
  final bool showDot;

  /// Read after the label when a badge or dot shows, e.g.
  /// "{n} ออเดอร์ที่กำลังดำเนินการ" or [ZokyStrings.navMessagesUnread].
  final String? badgeSemanticLabel;

  /// CupertinoIcons pair used by the Apple [ZokyNavIconStyle]s instead of
  /// the glyph's default (e.g. [ZokyAppleNavIcons.ordersBag]).
  final ZokyAppleNavIcons? appleIcons;
}

/// Floating capsule tab bar (design 9.8, Home Phase 5 per the Founder's
/// reference 2026-10-17). Shared on every platform: deliberately not
/// CupertinoTabBar / NavigationBar because the nav is part of the brand.
///
/// A white stadium inset [sideMargin] from the screen sides and lifted
/// [bottomOffset] above the bottom edge, with a soft wide shadow. Content
/// may scroll visibly around and below it; screens reserve
/// [reservedHeight] so their resting scroll end stays above it.
///
/// The selected item sits in a soft blush capsule that slides between tabs,
/// with the glossy 3D pink icon and a bold pink label; the rest are gray
/// line icons with gray labels.
class ZokyBottomNav extends StatelessWidget {
  const ZokyBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.iconStyle = ZokyNavIconStyle.classic3d,
  });

  final List<ZokyNavItem> items;

  /// Tab icon treatment; [ZokyNavIconStyle.classic3d] is the shipped one.
  final ZokyNavIconStyle iconStyle;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Height of the capsule.
  static const double height = 64;

  /// Gap between the capsule and the screen sides (plus side safe areas).
  static const double sideMargin = ZokySpacing.s8;

  /// Capsule padding around the item row; also the selected highlight's
  /// gap to the capsule edge.
  static const double innerPadding = 6;

  /// Lift above the bottom edge when the device has no bottom inset
  /// (e.g. iPhone SE).
  static const double minBottomOffset = 12;

  /// Icon size of every item (line and 3D share it).
  static const double iconSize = 26;

  /// Labels stop growing at this text scale so the bar never overflows.
  static const double maxLabelScale = 1.2;

  /// Highlight slide between tabs.
  static const Duration highlightDuration = Duration(milliseconds: 220);

  /// Capsule surface (labels' background).
  static const Color surface = ZokyColors.surface;

  /// Selected item's soft capsule (blush tint).
  static const Color selectedFill = Color(0xFFFFEDF4);

  /// Notification dot: the semantic red, never brand pink.
  static const Color dotColor = ZokyColors.error;

  /// Faint edge so the white capsule reads on white content.
  static const Color hairline = Color(0x1416161A); // ink 8%

  /// Identifies the capsule itself (the widget also includes its margins).
  static const Key capsuleKey = ValueKey('ZokyBottomNav.capsule');

  /// Distance from the screen's bottom edge to the capsule's bottom.
  static double bottomOffset(BuildContext context) =>
      math.max(MediaQuery.paddingOf(context).bottom, minBottomOffset);

  /// Space screens must leave free at the bottom so the last content row
  /// scrolls fully clear of the nav (capsule + bottom offset + an 8pt gap).
  static double reservedHeight(BuildContext context) =>
      height + bottomOffset(context) + ZokySpacing.s4;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final n = items.length;
    final x = n <= 1 ? 0.0 : -1 + 2 * currentIndex / (n - 1);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        sideMargin + padding.left,
        0,
        sideMargin + padding.right,
        bottomOffset(context),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ZokySizes.navMaxWidth),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: DecoratedBox(
              key: capsuleKey,
              decoration: const ShapeDecoration(
                color: surface,
                shape: StadiumBorder(
                  side: BorderSide(color: hairline, width: 0.5),
                ),
                shadows: [
                  // Wide, diffuse, neutral with a faint pink tint.
                  BoxShadow(
                    color: Color(0x243B1A29),
                    offset: Offset(0, 10),
                    blurRadius: 36,
                  ),
                  BoxShadow(
                    color: Color(0x0F16161A),
                    offset: Offset(0, 1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: innerPadding,
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedAlign(
                            duration: reduceMotion
                                ? Duration.zero
                                : highlightDuration,
                            curve: ZokyMotion.standard,
                            alignment: Alignment(x, 0),
                            child: FractionallySizedBox(
                              widthFactor: n == 0 ? 1 : 1 / n,
                              heightFactor: 1,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: innerPadding,
                                ),
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: selectedFill,
                                    shape: StadiumBorder(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        MediaQuery.withClampedTextScaling(
                          maxScaleFactor: maxLabelScale,
                          child: Row(
                            children: [
                              for (var i = 0; i < n; i++)
                                Expanded(
                                  child: _NavButton(
                                    item: items[i],
                                    selected: i == currentIndex,
                                    iconStyle: iconStyle,
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
    required this.iconStyle,
    required this.duration,
    required this.onTap,
  });

  final ZokyNavItem item;
  final bool selected;
  final ZokyNavIconStyle iconStyle;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 13pt so the Thai tone marks stay legible (reference labels are large).
    final base = ZokyTextStyles.caption.copyWith(fontSize: 13);
    final labelStyle = selected
        ? ZokyTextStyles.weight(
            base.copyWith(color: ZokyColors.actionPrimary),
            FontWeight.w700,
          )
        : ZokyTextStyles.weight(
            base.copyWith(color: ZokyColors.textSecondary),
            FontWeight.w500,
          );
    final count = item.badgeCount > 0
        ? (item.badgeCount > 9 ? '9+' : '${item.badgeCount}')
        : null;
    final hasBadge = count != null || item.showDot;

    return Semantics(
      button: true,
      selected: selected,
      label: [
        item.label,
        if (hasBadge) item.badgeSemanticLabel ?? count ?? '',
      ].where((s) => s.isNotEmpty).join(', '),
      // The tap action must live on this node: excludeSemantics drops the
      // InkResponse's own action.
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        customBorder: const StadiumBorder(),
        splashColor: ZokyColors.blush.withValues(alpha: 0.6),
        highlightColor: Colors.transparent,
        // Pointer hover would paint a gray disc over the capsule.
        hoverColor: Colors.transparent,
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
                    child: ZokyNavIcon(
                      item.glyph,
                      key: ValueKey(selected),
                      selected: selected,
                      style: iconStyle,
                      size: ZokyBottomNav.iconSize,
                      appleIcons: item.appleIcons,
                      lineColor: ZokyColors.neutral600,
                    ),
                  ),
                ),
                if (count != null)
                  Positioned(right: -10, top: -5, child: _Badge(text: count))
                else if (item.showDot)
                  const Positioned(right: -6, top: -6, child: _Dot()),
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

/// 8pt red dot with a 2pt white ring (12pt overall).
class _Dot extends StatelessWidget {
  const _Dot();

  static const double size = 12;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ZokyBottomNav.dotColor,
        shape: BoxShape.circle,
        border: Border.all(color: ZokyColors.neutral0, width: 2),
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
