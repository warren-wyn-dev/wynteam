import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_glossy_heart_button.dart';
import '../../../core/widgets/zoky_glossy_surface.dart';
import '../../../core/widgets/zoky_nav_icon.dart';
import '../../home/widgets/zoky_home_header.dart';

/// Food landing page header (Founder, 2026-10-18; layout inspired by the
/// food pages of delivery super-apps, ZOKY branding only): the same "ZOKY
/// Glossy 3D" pink surface, gloss and waves as the Home header, but
/// shorter and without the logo. One row: the adaptive back button, the
/// [address] pill ("จัดส่งที่ ... ▾"), then the white glossy heart
/// ("ร้านโปรด") and, when [onOrders] is set, the orders shortcut. Pink
/// [bottomSpace] under the row leaves room for the search field the page
/// floats over the pink/white seam.
///
/// Contrast: the back arrow is white on #F93384 (3.6:1, enough for a
/// non-text control); every text sits on a white glossy control.
class ZokyFoodHeader extends StatelessWidget {
  const ZokyFoodHeader({
    super.key,
    required this.address,
    required this.onFavorites,
    required this.onOrders,
    required this.bottomSpace,
  });

  final Widget address;
  final VoidCallback onFavorites;

  /// Orders shortcut; hidden when null.
  final VoidCallback? onOrders;

  /// Space under the row, the white sheet ([sheetRadius]) included.
  final double bottomSpace;

  /// Same white sheet radius as Home.
  static const double sheetRadius = ZokyHomeHeader.sheetRadius;

  static const double _circle = ZokyHomeHeader.heartDiameter;
  static const double _tapTarget = ZokyHomeHeader.tapTarget;

  /// Back button key (tests).
  static const Key backKey = ValueKey('zoky-food-back');

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final edge = (_tapTarget - _circle) / 2;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ZokyHomeHeader.systemOverlayStyle,
      child: ZokyGlossySurface(
        glossHeight: ZokyHomeHeader.glossHeight(topInset),
        glossOpacity: ZokyHomeHeader.glossOpacity,
        glossInset: 0,
        rim: false,
        shadow: false,
        child: CustomPaint(
          painter: const ZokyHeaderWavesPainter(),
          child: Stack(
            // Let the white sheet overlap 1px past the bottom (no seam).
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  ZokySpacing.s2,
                  topInset + ZokySpacing.s4,
                  ZokySpacing.gutter - edge,
                  bottomSpace,
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: backKey,
                      icon: Icon(ZokyIcons.back(context)),
                      color: ZokyColors.onAction,
                      tooltip: ZokyStrings.back,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: ZokySpacing.s1),
                    Expanded(child: address),
                    const SizedBox(width: ZokySpacing.s4),
                    ZokyGlossyHeartButton(
                      label: ZokyStrings.favoriteStores,
                      onPressed: onFavorites,
                      diameter: _circle,
                      tapTarget: _tapTarget,
                    ),
                    if (onOrders != null) ...[
                      const SizedBox(width: ZokySpacing.s2),
                      ZokyGlossyHeartButton(
                        label: ZokyStrings.navOrders,
                        onPressed: onOrders!,
                        diameter: _circle,
                        tapTarget: _tapTarget,
                        icon: const ZokyNavIcon(
                          ZokyNavGlyph.orders,
                          selected: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                height: sheetRadius + 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ZokyColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(sheetRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
