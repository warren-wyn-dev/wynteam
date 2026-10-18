import 'package:flutter/material.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/widgets/zoky_skeleton.dart';
import '../../deals/widgets/zoky_deal_illustration.dart';
import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../home/domain/home_content_models.dart';

/// Food page category circles (Founder mockup v2, 2026-10-18): soft blush
/// circles with the "ZOKY Glossy 3D" dish illustration and the Thai name
/// under each. The first four fill the width evenly; further categories
/// continue in the same horizontally scrolling row. Tapping one opens the
/// store list filtered by that category.
///
/// The page loads the list (so pull-to-refresh reloads it): skeleton
/// circles while [categories] is null, a compact offline message with a
/// retry button when [failed], nothing when the list is empty.
class ZokyFoodCategoryRow extends StatelessWidget {
  const ZokyFoodCategoryRow({
    super.key,
    required this.categories,
    required this.onOpenCategory,
    this.failed = false,
    this.onRetry,
  });

  final List<ZokyFoodCategory>? categories;
  final ValueChanged<ZokyFoodCategory> onOpenCategory;
  final bool failed;
  final VoidCallback? onRetry;

  /// Key of the horizontal scroll view (tests).
  static const Key rowKey = ValueKey('zoky-category-row');

  /// Key of the error message (tests).
  static const Key errorKey = ValueKey('zoky-category-error');

  /// Categories that fill the width before the row scrolls.
  static const int visibleCount = 4;

  /// Width of one item for a viewport [width] wide: the content width
  /// split into [visibleCount] columns.
  static double itemWidth(double width) =>
      (width - 2 * ZokySpacing.gutter) / visibleCount;

  /// Circle diameter for a viewport [width] wide.
  static double circleSize(double width) =>
      (itemWidth(width) * 0.62).clamp(52.0, 68.0);

  /// Soft blush circle behind each dish.
  static const Color circleColor = Color(0xFFFDEEF3);

  @override
  Widget build(BuildContext context) {
    final categories = this.categories;
    if (failed) {
      return Padding(
        key: errorKey,
        padding: const EdgeInsets.fromLTRB(
          ZokySpacing.gutter,
          ZokySpacing.s4,
          ZokySpacing.s4,
          ZokySpacing.s4,
        ),
        child: Row(
          children: [
            const Icon(
              ZokyIcons.wifiOff,
              size: ZokySizes.iconMd,
              color: ZokyColors.textSecondary,
            ),
            const SizedBox(width: ZokySpacing.s4),
            Expanded(
              child: Text(
                ZokyStrings.offlineTitle,
                style: ZokyTextStyles.bodyMd.copyWith(
                  color: ZokyColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: ZokyColors.brandDeep,
                minimumSize: const Size(
                  ZokySizes.tapTargetIos,
                  ZokySizes.tapTargetIos,
                ),
              ),
              child: const Text(ZokyStrings.retry),
            ),
          ],
        ),
      );
    }
    if (categories != null && categories.isEmpty) {
      return const SizedBox.shrink();
    }
    final width = MediaQuery.sizeOf(context).width;
    final circle = ZokyFoodCategoryRow.circleSize(width);
    final itemWidth = ZokyFoodCategoryRow.itemWidth(width);
    return SingleChildScrollView(
      key: ZokyFoodCategoryRow.rowKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        ZokySpacing.gutter,
        ZokySpacing.s4,
        ZokySpacing.gutter,
        ZokySpacing.s4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categories == null)
            for (var i = 0; i < ZokyFoodCategoryRow.visibleCount; i++)
              SizedBox(
                width: itemWidth,
                child: Column(
                  children: [
                    ZokySkeleton(
                      width: circle,
                      height: circle,
                      borderRadius: ZokyRadius.full,
                    ),
                    const SizedBox(height: ZokySpacing.s4),
                    ZokySkeleton(
                      width: circle * 0.7,
                      height: 12,
                      borderRadius: ZokyRadius.full,
                    ),
                  ],
                ),
              )
          else
            for (final category in categories)
              ZokyFoodCategoryItem(
                category: category,
                circle: circle,
                width: itemWidth,
                onTap: () => onOpenCategory(category),
              ),
        ],
      ),
    );
  }
}

/// One category: a 1:1 soft blush disc with the dish, label below. One
/// button for assistive tech, at least 44pt in both directions.
class ZokyFoodCategoryItem extends StatelessWidget {
  const ZokyFoodCategoryItem({
    super.key,
    required this.category,
    required this.circle,
    required this.width,
    required this.onTap,
  });

  final ZokyFoodCategory category;
  final double circle;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: category.label,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        child: InkWell(
          onTap: onTap,
          borderRadius: ZokyRadius.lg,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ZokySpacing.s2),
            child: Column(
              children: [
                Container(
                  width: circle,
                  height: circle,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: ZokyFoodCategoryRow.circleColor,
                  ),
                  child: ZokyDealIllustration(
                    art: category.art,
                    size: circle * 0.8,
                  ),
                ),
                const SizedBox(height: ZokySpacing.s3),
                Text(
                  category.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZokyTextStyles.bodyMd.copyWith(
                    color: ZokyColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
