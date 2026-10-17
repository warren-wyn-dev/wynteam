import 'package:flutter/material.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_3d_icon.dart';
import '../../../core/widgets/zoky_glossy_surface.dart';
import '../domain/deal_models.dart';
import 'zoky_deal_illustration.dart';

/// Soft card tints of the deal row (mockup: pink-tinted and peach-tinted).
///
/// Contrast (WCAG 2.x) of the [ZokyColors.brandDeep] headline on the darker
/// bottom stop: pink 4.09:1, peach 4.28:1 -- passes for *large* text only,
/// so the headline is [ZokyDealCard.headlineSize] bold (>= 18.66px bold).
/// Small text on the tint is ink (>= 14:1); the "ตัวอย่าง" badge text sits
/// on a white glossy control (brandDeep 5.15 / 4.70:1).
enum ZokyDealTint {
  pink(Color(0xFFFFF1F6), Color(0xFFFFDCEA)),
  peach(Color(0xFFFFF7EF), Color(0xFFFFE4D1));

  const ZokyDealTint(this.top, this.bottom);

  final Color top;
  final Color bottom;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [top, bottom],
  );

  /// Alternating tints along the row, like the mockup.
  static ZokyDealTint forIndex(int index) => values[index % values.length];
}

/// One deal: illustration left, demo badge, bold promo headline in brand
/// pink, a short description and a small 3D arrow bottom-right. A single
/// button for assistive tech ("ตัวอย่างดีล: ลด 50% ชานมไข่มุก").
///
/// "ZOKY Glossy 3D" (design 7.1) on a light surface: tinted gradient base,
/// a subtle white gloss band, a white inner rim and a soft pink shadow.
class ZokyDealCard extends StatelessWidget {
  const ZokyDealCard({
    super.key,
    required this.deal,
    required this.width,
    required this.onTap,
    this.tint = ZokyDealTint.pink,
  });

  final ZokyDeal deal;
  final double width;
  final VoidCallback onTap;
  final ZokyDealTint tint;

  static const BorderRadius radius = ZokyRadius.xl;
  static const double minHeight = 112;
  static const double headlineSize = 20;

  /// Soft pink-tinted drop shadow (lighter than the brand card's, since
  /// this card is light).
  static const List<BoxShadow> shadow = [
    BoxShadow(color: Color(0x29EE226E), offset: Offset(0, 6), blurRadius: 16),
  ];

  /// Row card width: ~56% of the screen so the next card peeks in at the
  /// right edge, clamped for very small and large phones.
  static double rowWidth(double viewportWidth) =>
      (viewportWidth * 0.56).clamp(184.0, 260.0);

  /// Illustration column width for a card [width] wide.
  static double artWidth(double width) => (width * 0.42).clamp(72.0, 108.0);

  static TextStyle get headlineStyle => ZokyTextStyles.weight(
    ZokyTextStyles.titleMd.copyWith(
      fontSize: headlineSize,
      height: 1.2,
      color: ZokyColors.brandDeep,
    ),
    FontWeight.w800,
  );

  /// Accessible name of the card.
  static String semanticLabel(ZokyDeal deal) {
    final prefix = deal.isDemo ? '${ZokyStrings.demoDealPrefix}: ' : '';
    return '$prefix${deal.headline} ${deal.description}';
  }

  @override
  Widget build(BuildContext context) {
    final art = artWidth(width);
    return Semantics(
      button: true,
      label: semanticLabel(deal),
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        // Shadow outside the Material: ink is clipped to the Material's
        // box, which would cut the soft shadow square.
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: radius,
            boxShadow: shadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: tint.gradient,
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: CustomPaint(
                  painter: const ZokyGlossPainter(
                    gradient: null,
                    borderRadius: radius,
                    glossHeight: 44,
                    glossOpacity: 0.55,
                    rimTop: Color(0xE6FFFFFF),
                    rimBottom: Color(0x40FFFFFF),
                  ),
                  // Intrinsic height so the stretched Row also works in a
                  // vertical list; a row parent may still force a taller,
                  // shared height (equal cards).
                  child: IntrinsicHeight(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: minHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          ZokySpacing.s4,
                          ZokySpacing.s6,
                          ZokySpacing.s5,
                          ZokySpacing.s5,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: art,
                              child: Center(
                                child: ZokyDealIllustration(
                                  art: deal.art,
                                  size: art,
                                ),
                              ),
                            ),
                            const SizedBox(width: ZokySpacing.s4),
                            Expanded(child: _copy()),
                          ],
                        ),
                      ),
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

  Widget _copy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (deal.isDemo) ...[
              const ZokyDemoBadge(),
              const SizedBox(height: ZokySpacing.s3),
            ],
            Text(deal.headline, style: headlineStyle),
            const SizedBox(height: ZokySpacing.s1),
            Text(
              deal.description,
              style: ZokyTextStyles.bodySm.copyWith(
                color: ZokyColors.textPrimary,
                height: 1.35,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZokySpacing.s2),
        const Align(
          alignment: Alignment.centerRight,
          child: Zoky3DIcon(Zoky3DGlyph.arrowRight, size: 24),
        ),
      ],
    );
  }
}

/// Small white glossy "ตัวอย่าง" badge (same control recipe as the hero
/// pill): marks sample data that is not a real promotion.
class ZokyDemoBadge extends StatelessWidget {
  const ZokyDemoBadge({super.key});

  static const BorderRadius _radius = ZokyRadius.full;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: _radius,
        gradient: ZokyGloss.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x24EE226E),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: CustomPaint(
        painter: const ZokyGlossPainter(
          gradient: null,
          borderRadius: _radius,
          glossHeight: 0,
          rimTop: ZokyGloss.controlRimTop,
          rimBottom: ZokyGloss.controlRimBottom,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ZokySpacing.s4,
            vertical: ZokySpacing.s1,
          ),
          child: Text(
            ZokyStrings.demoBadge,
            style: ZokyTextStyles.weight(
              ZokyTextStyles.caption.copyWith(color: ZokyColors.brandDeep),
              FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
