import 'package:flutter/material.dart';

import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_glossy_surface.dart';

/// Food page search entry that floats over the header's pink/white seam: a
/// white glossy rounded field with a search icon and "สั่งอะไรดี?". It is a
/// button, not a text field: tapping it opens the store search page with
/// the keyboard up.
///
/// Placeholder text is [ZokyColors.textSecondary] (>= 4.8:1 on the white
/// glossy fill).
class ZokyFoodSearchField extends StatelessWidget {
  const ZokyFoodSearchField({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const BorderRadius radius = ZokyRadius.xl;

  static TextStyle get _style =>
      ZokyTextStyles.bodyLg.copyWith(color: ZokyColors.textSecondary);

  /// Field height: 52pt, taller when the user enlarges text.
  static double heightFor(BuildContext context) {
    final line = MediaQuery.textScalerOf(context).scale(16) * 1.45;
    final padded = line + 2 * ZokySpacing.s6;
    return padded > ZokySizes.input ? padded : ZokySizes.input;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: ZokyStrings.foodSearchPlaceholder,
      hint: ZokyStrings.searchHint,
      excludeSemantics: true,
      // Shadow outside the Material: ink is clipped to the Material's box.
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Color(0x2EEE226E),
              offset: Offset(0, 6),
              blurRadius: 18,
            ),
            BoxShadow(
              color: Color(0x1A16161A),
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: const BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [ZokyColors.neutral0, Color(0xFFFFF8FB)],
              ),
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: radius,
              child: CustomPaint(
                painter: const ZokyGlossPainter(
                  gradient: null,
                  borderRadius: radius,
                  glossHeight: 0,
                  rimTop: ZokyGloss.controlRimTop,
                  rimBottom: ZokyGloss.controlRimBottom,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZokySpacing.s8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        ZokyIcons.search,
                        size: ZokySizes.iconLg,
                        color: ZokyColors.textPrimary,
                      ),
                      const SizedBox(width: ZokySpacing.s6),
                      Expanded(
                        child: Text(
                          ZokyStrings.foodSearchPlaceholder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _style,
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
