import 'package:flutter/material.dart';

import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/format/money.dart';
import '../../../core/l10n/zoky_strings.dart';

/// Floating cart button of the food page (Founder mockup v2): a pink
/// circle with the cart icon while the cart is empty, a pill with the
/// item count and total ("3 · ฿245") once it has items.
///
/// The empty state stays visible (not hidden) because the mockup shows it
/// and it keeps one steady entry point to the cart. Fill is
/// [ZokyColors.actionPrimary] so the white count/total text passes 4.5:1.
/// The pill text clamps at 1.3x text scale so it never grows over the list;
/// the page reserves [height] + margins below its last row.
class ZokyFoodCartButton extends StatelessWidget {
  const ZokyFoodCartButton({
    super.key,
    required this.itemCount,
    required this.total,
    required this.onPressed,
  });

  final int itemCount;
  final num total;
  final VoidCallback onPressed;

  /// Circle diameter / pill height.
  static const double height = 56;

  bool get _hasItems => itemCount > 0;

  String get _semanticLabel => _hasItems
      ? '${ZokyStrings.cart} $itemCount ${ZokyStrings.cartItemsSuffix} '
            'รวม ${formatBaht(total)}'
      : ZokyStrings.cart;

  @override
  Widget build(BuildContext context) {
    final countText = itemCount > 99 ? '99+' : '$itemCount';
    final style = ZokyTextStyles.weight(
      ZokyTextStyles.labelLg.copyWith(color: ZokyColors.onAction),
      FontWeight.w700,
    ).copyWith(fontFeatures: ZokyTextStyles.price.fontFeatures);
    return Semantics(
      button: true,
      liveRegion: true,
      label: _semanticLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: ZokyRadius.full,
          boxShadow: ZokyShadows.brand,
        ),
        child: Material(
          color: ZokyColors.actionPrimary,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            highlightColor: ZokyColors.actionPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: height,
                minHeight: height,
                maxHeight: height,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _hasItems ? ZokySpacing.s10 : 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      ZokyIcons.trolley,
                      size: 26,
                      color: ZokyColors.onAction,
                    ),
                    if (_hasItems) ...[
                      const SizedBox(width: ZokySpacing.s4),
                      MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.3,
                        child: Text(
                          '$countText · ${formatBaht(total)}',
                          maxLines: 1,
                          style: style,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
