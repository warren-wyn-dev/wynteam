import 'package:flutter/material.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/widgets/zoky_glossy_surface.dart';
import '../../../core/widgets/zoky_skeleton.dart';
import '../../deals/widgets/zoky_deal_illustration.dart';
import '../data/home_content_repository.dart';
import '../domain/home_content_models.dart';
import 'zoky_store_cover.dart';

/// Home v2 food category circles (Founder, 2026-10-18): a horizontally
/// scrolling row of round "ZOKY Glossy 3D" dish illustrations with the
/// Thai name under each. Tapping one opens the store list filtered by that
/// category.
///
/// Loads from [HomeContentRepository.fetchFoodCategories]; skeleton circles
/// while loading, hidden when there are none or the call fails.
class ZokyFoodCategoryRow extends StatefulWidget {
  const ZokyFoodCategoryRow({
    super.key,
    required this.repository,
    required this.onOpenCategory,
  });

  final HomeContentRepository repository;
  final ValueChanged<ZokyFoodCategory> onOpenCategory;

  /// Key of the horizontal scroll view (tests).
  static const Key rowKey = ValueKey('zoky-category-row');

  /// Circle diameter for a viewport [width] wide.
  static double circleSize(double width) => (width * 0.165).clamp(60.0, 72.0);

  @override
  State<ZokyFoodCategoryRow> createState() => _ZokyFoodCategoryRowState();
}

class _ZokyFoodCategoryRowState extends State<ZokyFoodCategoryRow> {
  List<ZokyFoodCategory>? _categories;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final categories = await widget.repository.fetchFoodCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    if (_failed || (categories != null && categories.isEmpty)) {
      return const SizedBox.shrink();
    }
    final circle = ZokyFoodCategoryRow.circleSize(
      MediaQuery.sizeOf(context).width,
    );
    final itemWidth = circle + ZokySpacing.s8;
    return SingleChildScrollView(
      key: ZokyFoodCategoryRow.rowKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        ZokySpacing.gutter - ZokySpacing.s4,
        ZokySpacing.s2,
        ZokySpacing.gutter - ZokySpacing.s4,
        ZokySpacing.s6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categories == null)
            for (var i = 0; i < 5; i++)
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
                onTap: () => widget.onOpenCategory(category),
              ),
        ],
      ),
    );
  }
}

/// One category: a 1:1 glossy tinted disc with the dish, label below. One
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

  static const List<BoxShadow> _shadow = [
    BoxShadow(color: Color(0x24EE226E), offset: Offset(0, 4), blurRadius: 10),
  ];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(circle / 2);
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
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ZokyStoreCover.tintFor(category.art),
                    boxShadow: _shadow,
                  ),
                  child: CustomPaint(
                    foregroundPainter: ZokyGlossPainter(
                      gradient: null,
                      borderRadius: radius,
                      glossHeight: circle * 0.42,
                      glossOpacity: 0.45,
                      glossInset: circle * 0.06,
                      rimTop: const Color(0xE6FFFFFF),
                      rimBottom: const Color(0x40FFFFFF),
                    ),
                    child: SizedBox.square(
                      dimension: circle,
                      child: Center(
                        child: ZokyDealIllustration(
                          art: category.art,
                          size: circle * 0.86,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: ZokySpacing.s4),
                Text(
                  category.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZokyTextStyles.labelMd.copyWith(
                    color: ZokyColors.textPrimary,
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
