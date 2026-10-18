import 'package:flutter/material.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_3d_icon.dart';
import '../../../core/widgets/zoky_glossy_surface.dart';
import 'zoky_bento_illustration.dart';

/// Home Phase 2 hero (Founder mockup "เฟส 2 การ์ดสั่งอาหาร"): a "ZOKY
/// Glossy 3D" brand card -- the same gradient, gloss band and rim as the
/// Phase 1 header via [ZokyGlossySurface] -- with a white glossy "FOOD
/// DELIVERY" pill, the main question, a subtitle, a bento illustration on a
/// frosted disc and a full-width white glossy search button.
///
/// Tapping the card or its button calls [onSearch]: Home opens the food
/// landing page (Founder, 2026-10-18). The card-wide tap is a convenience
/// for touch; assistive tech gets the one labelled button.
///
/// Contrast (WCAG 2.x): the card is #F93384 -> #EE226E, so white text is
/// 3.6-4.1:1 and only *large* text may be white on it: the title (28/700)
/// and the subtitle ([subtitleSize] bold, >= 18.66px bold). The gloss band
/// ends above the title ([glossHeight]). Small text sits on white glossy
/// controls in [ZokyColors.brandDeep]: 5.15:1 on white, 4.70:1 on
/// [ZokyGloss.whiteBottom].
class ZokyFoodHeroCard extends StatelessWidget {
  const ZokyFoodHeroCard({super.key, required this.onSearch});

  /// Card or "ค้นหาของอร่อย" tapped.
  final VoidCallback onSearch;

  static const double padding = ZokySpacing.s10;
  static const BorderRadius radius = ZokyRadius.xxl;

  /// Visible button height (>= the 44pt iOS / 48pt Android tap target).
  static const double buttonHeight = ZokySizes.buttonMd;

  /// Card surface: identical to the header's (one brand surface).
  static const LinearGradient background = ZokyGloss.brand;

  /// Gloss band height: covers the white pill and fades out before the
  /// title, so no white text sits on the lightened top.
  static const double glossHeight = padding + 34;

  /// Subtitle: bold and >= 18.66px, i.e. WCAG "large text" (3:1 needed).
  static const double subtitleSize = 19;

  /// Subtitle split at its spaces (space kept on the earlier phrase).
  static List<String> get subtitlePhrases {
    final words = ZokyStrings.heroSubtitle.split(' ');
    return [
      for (var i = 0; i < words.length; i++)
        i < words.length - 1 ? '${words[i]} ' : words[i],
    ];
  }

  static TextStyle get subtitleStyle => ZokyTextStyles.weight(
    ZokyTextStyles.bodyMd.copyWith(fontSize: subtitleSize, height: 1.35),
    FontWeight.w700,
  );

  /// Illustration circle: ~33% of the card's inner width, clamped, and a
  /// little smaller when the user enlarges text so the copy keeps room.
  static double illustrationSize(double innerWidth, double textScale) {
    final base = (innerWidth * 0.34).clamp(76.0, 124.0);
    return textScale > 1.15 ? base * 0.82 : base;
  }

  @override
  Widget build(BuildContext context) {
    final white = ZokyColors.onAction;
    final card = ZokyGlossySurface(
      borderRadius: radius,
      glossHeight: glossHeight,
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final circle = illustrationSize(constraints.maxWidth, scale);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Pill(),
                          const SizedBox(height: ZokySpacing.s7),
                          Semantics(
                            header: true,
                            label: ZokyStrings.heroTitle,
                            excludeSemantics: true,
                            child: Text(
                              ZokyStrings.heroTitleLines,
                              style: ZokyTextStyles.display.copyWith(
                                color: white,
                              ),
                            ),
                          ),
                          const SizedBox(height: ZokySpacing.s3),
                          // Wrap only between phrases: Thai has no spaces
                          // inside words, so a narrow card must not leave
                          // "นี่" alone on a line.
                          Semantics(
                            label: ZokyStrings.heroSubtitle,
                            excludeSemantics: true,
                            child: Wrap(
                              children: [
                                for (final phrase in subtitlePhrases)
                                  Text(
                                    phrase,
                                    style: subtitleStyle.copyWith(color: white),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: ZokySpacing.s4),
                    _IllustrationCircle(size: circle),
                  ],
                ),
                const SizedBox(height: ZokySpacing.s10),
                _SearchButton(onPressed: onSearch),
              ],
            );
          },
        ),
      ),
    );
    return GestureDetector(
      onTap: onSearch,
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      child: card,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill();

  static const BorderRadius _radius = ZokyRadius.full;

  @override
  Widget build(BuildContext context) {
    final style = ZokyTextStyles.labelSm.copyWith(
      color: ZokyColors.brandDeep,
      letterSpacing: 1.4,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: _radius,
        gradient: ZokyGloss.white,
        boxShadow: ZokyGloss.controlShadow,
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
          padding: const EdgeInsets.fromLTRB(
            ZokySpacing.s4,
            ZokySpacing.s2,
            ZokySpacing.s6,
            ZokySpacing.s2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Zoky3DIcon(Zoky3DGlyph.sparkle, size: 16),
              const SizedBox(width: ZokySpacing.s2),
              Flexible(
                child: Text(
                  ZokyStrings.heroFoodDelivery,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted, glossy lighter-pink disc holding the decorative bento drawing.
class _IllustrationCircle extends StatelessWidget {
  const _IllustrationCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 2);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: ZokyGlossPainter(
            gradient: ZokyGloss.frost,
            borderRadius: radius,
            glossHeight: size * 0.46,
            glossOpacity: 0.30,
            glossInset: size * 0.08,
            rimTop: const Color(0x73FFFFFF),
            rimBottom: const Color(0x1FFFFFFF),
          ),
          child: Center(child: ZokyBentoIllustration(size: size * 0.9)),
        ),
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onPressed});

  final VoidCallback onPressed;

  static const BorderRadius _radius = ZokyRadius.md;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: ZokyStrings.heroSearchButton,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: const BoxDecoration(
            borderRadius: _radius,
            gradient: ZokyGloss.white,
            boxShadow: ZokyGloss.controlShadow,
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: _radius,
            child: CustomPaint(
              painter: const ZokyGlossPainter(
                gradient: null,
                borderRadius: _radius,
                glossHeight: 0,
                rimTop: ZokyGloss.controlRimTop,
                rimBottom: ZokyGloss.controlRimBottom,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: ZokyFoodHeroCard.buttonHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ZokySpacing.s8,
                    ZokySpacing.s3,
                    ZokySpacing.s4,
                    ZokySpacing.s3,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ZokyStrings.heroSearchButton,
                          style: ZokyTextStyles.labelLg.copyWith(
                            color: ZokyColors.brandDeep,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZokySpacing.s4),
                      const Zoky3DIcon(Zoky3DGlyph.arrowRight, size: 32),
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
