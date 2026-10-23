import 'package:flutter/material.dart';

import '../../features/catalog/domain/catalog_models.dart';
import '../adaptive/zoky_icons.dart';
import '../design/zoky_colors.dart';
import '../design/zoky_tokens.dart';
import '../design/zoky_typography.dart';
import '../format/money.dart';
import '../l10n/zoky_strings.dart';

/// Menu row (design 9.5, web `fx-menu-row`): text on the left, 104px photo
/// on the right (84px at <=359px wide) with the add (+) button over it.
/// Sold out: "หมด" over the photo, muted price, no add button.
class ZokyMenuItemCard extends StatelessWidget {
  const ZokyMenuItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onAdd,
  });

  final ZokyMenuItem item;
  final VoidCallback onTap;

  /// Null hides the add button (also hidden when sold out).
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 359;
    final photoSize = narrow ? 84.0 : 104.0;
    final soldOut = item.isSoldOut;
    final lowStock =
        !soldOut && item.remainingStock != null && item.remainingStock! <= 5;

    final label = [
      item.name,
      '${item.price} บาท',
      if (soldOut) ZokyStrings.soldOut,
      if (lowStock) 'เหลือ ${item.remainingStock} ชิ้น',
    ].join(', ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZokySpacing.gutter,
          vertical: ZokySpacing.s6,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                container: true,
                label: label,
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ZokyTextStyles.weight(
                        ZokyTextStyles.bodyLg,
                        FontWeight.w600,
                      ),
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: ZokySpacing.s1),
                      Text(
                        item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ZokyTextStyles.bodySm,
                      ),
                    ],
                    const SizedBox(height: ZokySpacing.s3),
                    Wrap(
                      spacing: ZokySpacing.s4,
                      runSpacing: ZokySpacing.s2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatBaht(item.price),
                          style: ZokyTextStyles.price.copyWith(
                            color: soldOut
                                ? ZokyColors.textSecondary
                                : ZokyColors.textPrimary,
                          ),
                        ),
                        if (lowStock) _StockTag('เหลือ ${item.remainingStock}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: ZokySpacing.s6),
            SizedBox(
              width: photoSize,
              height: photoSize,
              child: Stack(
                children: [
                  Positioned.fill(child: _photo(soldOut)),
                  if (soldOut)
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ZokyColors.neutral900.withValues(alpha: 0.8),
                          borderRadius: ZokyRadius.full,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          child: MediaQuery.withClampedTextScaling(
                            maxScaleFactor: 1.3,
                            child: Text(
                              ZokyStrings.soldOut,
                              style: ZokyTextStyles.labelSm.copyWith(
                                color: ZokyColors.neutral0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!soldOut && onAdd != null)
                    Positioned(
                      // Kept inside the photo: Flutter does not hit-test
                      // children outside their parent's bounds.
                      right: 0,
                      bottom: 0,
                      child: _AddButton(itemName: item.name, onPressed: onAdd!),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo(bool soldOut) {
    final placeholder = Container(
      decoration: const BoxDecoration(
        color: ZokyColors.sunken,
        borderRadius: ZokyRadius.md,
      ),
      alignment: Alignment.center,
      child: const Icon(ZokyIcons.food, color: ZokyColors.neutral400),
    );
    final url = item.imageUrl;
    if (url == null) return placeholder;
    final image = ClipRRect(
      borderRadius: ZokyRadius.md,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
    if (!soldOut) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_desaturate70),
      child: image,
    );
  }
}

// saturate(0.7) colour matrix (web: sold-out photo).
const List<double> _desaturate70 = [
  0.7639, 0.2145, 0.0216, 0, 0, //
  0.0639, 0.9145, 0.0216, 0, 0, //
  0.0639, 0.2145, 0.7216, 0, 0, //
  0, 0, 0, 1, 0, //
];

class _AddButton extends StatelessWidget {
  const _AddButton({required this.itemName, required this.onPressed});

  final String itemName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // 34px visual circle inside a 48px hit area (design 10.1).
    // container: its own screen-reader node, separate from the row.
    return Semantics(
      container: true,
      button: true,
      label: 'เพิ่ม $itemName ลงตะกร้า',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: ZokySizes.tapTargetAndroid,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onPressed,
            radius: 24,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: ZokyColors.actionAccent,
                  shape: BoxShape.circle,
                  boxShadow: ZokyShadows.e2,
                ),
                child: const Icon(
                  ZokyIcons.add,
                  color: ZokyColors.neutral0,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StockTag extends StatelessWidget {
  const _StockTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ZokyColors.warningContainer,
        borderRadius: ZokyRadius.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: ZokyTextStyles.labelSm.copyWith(color: ZokyColors.warning),
        ),
      ),
    );
  }
}
