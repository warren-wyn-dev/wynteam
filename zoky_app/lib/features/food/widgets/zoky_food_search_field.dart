import 'package:flutter/material.dart';

import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';

/// Food page search entry inside the pink header card (Founder mockup v2):
/// a white rounded field with a pink search icon and
/// "ค้นหาร้านอาหารหรือเมนู". It is a button, not a text field: tapping it
/// opens the store search page with the keyboard up.
///
/// Placeholder text is [ZokyColors.textSecondary] (>= 4.8:1 on white); the
/// icon is [ZokyColors.brandDeep].
class ZokyFoodSearchField extends StatelessWidget {
  const ZokyFoodSearchField({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const BorderRadius radius = ZokyRadius.xl;

  static TextStyle get _style =>
      ZokyTextStyles.bodyLg.copyWith(color: ZokyColors.textSecondary);

  /// Field height: 48pt, taller when the user enlarges text.
  static double heightFor(BuildContext context) {
    final line = MediaQuery.textScalerOf(context).scale(16) * 1.45;
    final padded = line + 2 * ZokySpacing.s6;
    return padded > ZokySizes.buttonMd ? padded : ZokySizes.buttonMd;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: ZokyStrings.foodSearchPlaceholder,
      hint: ZokyStrings.searchHint,
      excludeSemantics: true,
      child: SizedBox(
        height: heightFor(context),
        child: Material(
          color: ZokyColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZokySpacing.s8),
              child: Row(
                children: [
                  const Icon(
                    ZokyIcons.search,
                    size: ZokySizes.iconLg,
                    color: ZokyColors.brandDeep,
                  ),
                  const SizedBox(width: ZokySpacing.s5),
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
    );
  }
}
