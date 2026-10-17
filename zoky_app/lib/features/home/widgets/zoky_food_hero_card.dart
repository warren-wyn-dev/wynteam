import 'package:flutter/material.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import 'zoky_bento_illustration.dart';

/// Home Phase 2 hero (Founder mockup "เฟส 2 การ์ดสั่งอาหาร"): vivid pink
/// brand card with a "FOOD DELIVERY" pill, the main question, a subtitle,
/// a bento illustration in a soft circle and a full-width white search
/// button.
///
/// Contrast (WCAG 2.x, white text): the background is a brand banner
/// gradient (design 9.10) from [ZokyColors.brandDeep] #D61256 (5.15:1) at
/// the bottom-left to [ZokyColors.brand] #F21967 (4.11:1) at the top-right,
/// with the deep stop held to 35% so every small-text area (pill, subtitle)
/// sits where the blend is still >= #E4165E (4.59:1). Only the large bold
/// title (28pt/700, WCAG large text needs 3:1) reaches the vivid end.
/// Button text #D61256 on white: 5.15:1.
class ZokyFoodHeroCard extends StatelessWidget {
  const ZokyFoodHeroCard({super.key, required this.onSearch});

  final VoidCallback onSearch;

  static const double padding = ZokySpacing.s10;
  static const BorderRadius radius = ZokyRadius.xxl;

  /// Visible button height (>= the 44pt iOS / 48pt Android tap target).
  static const double buttonHeight = ZokySizes.buttonMd;

  static const LinearGradient background = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [ZokyColors.brandDeep, ZokyColors.brandDeep, ZokyColors.brand],
    stops: [0, 0.2, 1],
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: background,
        borderRadius: radius,
        boxShadow: ZokyShadows.brand,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          painter: const _GlowPainter(),
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
                              Text(
                                ZokyStrings.heroSubtitle,
                                style: ZokyTextStyles.weight(
                                  ZokyTextStyles.bodyMd,
                                  FontWeight.w500,
                                ).copyWith(color: white),
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
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill();

  @override
  Widget build(BuildContext context) {
    final style = ZokyTextStyles.labelSm.copyWith(
      color: ZokyColors.onAction,
      letterSpacing: 1.4,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZokySpacing.s5,
        vertical: ZokySpacing.s2,
      ),
      decoration: BoxDecoration(
        borderRadius: ZokyRadius.full,
        // Faint brandDeep wash keeps the small label >= 4.5:1 even where the
        // card gradient has started to brighten (narrow phones).
        color: ZokyColors.brandDeep.withValues(alpha: 0.45),
        border: Border.all(
          color: ZokyColors.onAction.withValues(alpha: 0.85),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 12,
              color: ZokyColors.onAction,
            ),
          ),
          const SizedBox(width: ZokySpacing.s3),
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
    );
  }
}

/// Soft lighter-pink circle holding the decorative bento drawing.
class _IllustrationCircle extends StatelessWidget {
  const _IllustrationCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ZokyColors.onAction.withValues(alpha: 0.20),
          border: Border.all(
            color: ZokyColors.onAction.withValues(alpha: 0.28),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: ZokyBentoIllustration(size: size * 0.74),
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: ZokyStrings.heroSearchButton,
      excludeSemantics: true,
      child: Material(
        color: ZokyColors.surface,
        borderRadius: ZokyRadius.md,
        child: InkWell(
          onTap: onPressed,
          borderRadius: ZokyRadius.md,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ZokyFoodHeroCard.buttonHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZokySpacing.s8,
                vertical: ZokySpacing.s3,
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
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: ZokySizes.iconLg,
                    color: ZokyColors.brandDeep,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Very soft light wash in the top-right corner (behind the illustration,
/// away from small text) so the flat pink has the mockup's gentle depth.
class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.92, -size.height * 0.05);
    final radius = size.width * 0.42;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            ZokyColors.onAction.withValues(alpha: 0.12),
            ZokyColors.onAction.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => false;
}
