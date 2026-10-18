import 'package:flutter/material.dart';

import 'zoky_3d_icon.dart';
import 'zoky_glossy_surface.dart';

/// White glossy circular button with the 3D heart ("ZOKY Glossy 3D" white
/// control): the Home header's "ร้านโปรด" button (Phase 1) and the smaller
/// heart on store cards (Phase 4). The visible circle is [diameter]; the
/// tap target is [tapTarget] (>= 44). One button node labelled [label].
///
/// [icon] replaces the heart (the food page's orders shortcut uses the
/// same white glossy circle).
class ZokyGlossyHeartButton extends StatelessWidget {
  const ZokyGlossyHeartButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.diameter = 44,
    this.tapTarget = 48,
    this.shadow = ZokyGloss.controlShadow,
    this.icon,
  }) : assert(tapTarget >= 44 && tapTarget >= diameter);

  final String label;
  final VoidCallback onPressed;
  final double diameter;
  final double tapTarget;
  final List<BoxShadow> shadow;

  /// Decorative glyph inside the circle; null = the 3D heart.
  final Widget? icon;

  /// Heart size relative to the circle (26 on the 44pt header button).
  static const double iconRatio = 26 / 44;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: tapTarget,
            child: Center(
              child: Ink(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  gradient: ZokyGloss.white,
                  shape: BoxShape.circle,
                  boxShadow: shadow,
                ),
                child: CustomPaint(
                  painter: ZokyGlossPainter(
                    gradient: null,
                    borderRadius: BorderRadius.all(
                      Radius.circular(diameter / 2),
                    ),
                    glossHeight: diameter * 0.5,
                    glossOpacity: 0.9,
                    glossInset: 3,
                    rimTop: ZokyGloss.controlRimTop,
                    rimBottom: ZokyGloss.controlRimBottom,
                  ),
                  child: Center(
                    child:
                        icon ??
                        Zoky3DIcon(
                          Zoky3DGlyph.heart,
                          size: (diameter * iconRatio).roundToDouble(),
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
