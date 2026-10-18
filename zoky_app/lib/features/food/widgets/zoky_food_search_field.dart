import 'package:flutter/material.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_line_icon.dart';

/// Food page search entry inside the blush header (Founder mockup v2): a
/// white rounded field with a soft shadow and a hairline [border] (so it
/// separates from the pale background and the white below), a pink search
/// icon and
/// "ค้นหาร้านอาหารหรือเมนู". It is a button, not a text field: tapping it
/// opens the store search page with the keyboard up.
///
/// Placeholder text is [ZokyColors.textSecondary] (>= 4.8:1 on white); the
/// icon is [ZokyColors.brandDeep].
class ZokyFoodSearchField extends StatelessWidget {
  const ZokyFoodSearchField({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const BorderRadius radius = ZokyRadius.xl;

  /// Hairline around the field.
  static const Color border = ZokyColors.borderSubtle;

  /// Soft ink shadow under the field.
  static const List<BoxShadow> shadow = [
    BoxShadow(color: Color(0x1416161A), offset: Offset(0, 2), blurRadius: 10),
  ];

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
      child: Container(
        height: heightFor(context),
        decoration: const BoxDecoration(
          borderRadius: radius,
          boxShadow: shadow,
        ),
        child: Material(
          color: ZokyColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZokySpacing.s8),
              child: Row(
                children: [
                  const ZokyLineIcon(
                    ZokyLineGlyph.search,
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
