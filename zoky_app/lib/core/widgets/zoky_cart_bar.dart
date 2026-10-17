import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/zoky_colors.dart';
import '../design/zoky_tokens.dart';
import '../design/zoky_typography.dart';
import '../format/money.dart';
import '../l10n/zoky_strings.dart';

/// Floating cart bar (design 9.7, web `fx-cart-bar`): pink-deep pill, count
/// bubble, "ดูตะกร้า", total. Max 540 wide, centered. At text scale >= 1.5
/// the "ดูตะกร้า" label is hidden so count + total always fit (design 10.2).
///
/// The total shown is the local cart subtotal for display; the amount the
/// customer confirms always comes from the server quote (ZOKY-107).
class ZokyCartBar extends StatelessWidget {
  const ZokyCartBar({
    super.key,
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  final int itemCount;
  final num total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final showLabel = scale < 1.5;
    final countText = itemCount > 99 ? '99+' : '$itemCount';
    final totalText = formatBaht(total);
    final textStyle = ZokyTextStyles.weight(
      ZokyTextStyles.bodyLg.copyWith(
        color: ZokyColors.onAction,
        fontSize: 17,
        height: 1.25,
      ),
      FontWeight.w700,
    ).copyWith(fontFeatures: ZokyTextStyles.price.fontFeatures);

    return Semantics(
      button: true,
      liveRegion: true,
      label:
          '${ZokyStrings.viewCart} $itemCount รายการ รวม ${total.toString()} บาท',
      excludeSemantics: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ZokySizes.cartBarMaxWidth,
            minHeight: ZokySizes.cartBar,
          ),
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
                onTap: onTap,
                highlightColor: ZokyColors.actionPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZokySpacing.s5,
                    vertical: ZokySpacing.s5,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: const BoxDecoration(
                            color: ZokyColors.neutral0,
                            borderRadius: ZokyRadius.full,
                          ),
                          alignment: Alignment.center,
                          child: MediaQuery.withClampedTextScaling(
                            maxScaleFactor: 1.3,
                            child: Text(
                              countText,
                              style: textStyle.copyWith(
                                color: ZokyColors.actionPrimary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: ZokySpacing.s6),
                        Expanded(
                          child: showLabel
                              ? Text(
                                  ZokyStrings.viewCart,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textStyle,
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: ZokySpacing.s6),
                        // A very long total scales down instead of
                        // overflowing; it may take up to 45% of the bar.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: math.max(0, constraints.maxWidth * 0.45),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(totalText, style: textStyle),
                          ),
                        ),
                        const SizedBox(width: ZokySpacing.s4),
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
