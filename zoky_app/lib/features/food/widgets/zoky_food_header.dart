import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_glossy_surface.dart';
import 'zoky_food_search_field.dart';

/// Food page header (Founder food page mockup v2, 2026-10-18): a rounded
/// brand-pink card inset from the screen edges, below the status bar.
/// Pinned: as the page scrolls it folds to a compact card with only the
/// search field ([collapse], see [maxExtentFor] / [minExtentFor]).
///
/// Row: the adaptive back button, the centered [title] ("จัดส่งที่ บ้าน ▾",
/// see ZokyFoodAddressButton), the heart ("ร้านโปรด") and the coupon icon
/// ("คูปองส่วนลด"). Under the row, inside the card: the white [search]
/// field.
///
/// Surface: the ZOKY brand gradient with a very faint top gloss and no
/// waves, so it reads flat like the mockup but is the same pink as the
/// rest of the app. The card sits on white, so the status bar above it
/// uses dark icons.
///
/// Contrast: the icons are white on #F93384..#EE226E (3.6:1+, enough for
/// non-text controls); the title is bold 18pt (large text, >= 3:1).
class ZokyFoodHeader extends StatelessWidget {
  const ZokyFoodHeader({
    super.key,
    required this.title,
    required this.search,
    required this.onFavorites,
    required this.onCoupons,
    this.collapse = 0,
  });

  final Widget title;
  final Widget search;
  final VoidCallback onFavorites;
  final VoidCallback onCoupons;

  /// 0 = full header, 1 = compact pinned bar with only the search field
  /// (driven by the scroll offset, so there is no extra animation to
  /// reduce).
  final double collapse;

  static const double radius = ZokyRadius.xxlValue;

  /// Key of the rounded pink card (tests).
  static const Key cardKey = ValueKey('zoky-food-header-card');

  /// Back button key (tests).
  static const Key backKey = ValueKey('zoky-food-back');

  /// Heart and coupon button keys (tests).
  static const Key favoritesKey = ValueKey('zoky-food-favorites');
  static const Key couponsKey = ValueKey('zoky-food-coupons');

  /// Dark status bar icons: the card starts below the status bar, on white.
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  /// Header row height (44pt targets; the title clamps to one line).
  static const double rowHeight = ZokySizes.tapTargetIos;

  static const double _outerTop = ZokySpacing.s4;
  static const double _outerBottom = ZokySpacing.s4;
  static const double _padTop = ZokySpacing.s4;
  static const double _gap = ZokySpacing.s4;
  static const double _padBottomOpen = ZokySpacing.s8;
  static const double _padBottomCompact = ZokySpacing.s4;

  /// Full height: status bar, card with the row and the search field.
  static double maxExtentFor(BuildContext context) =>
      MediaQuery.paddingOf(context).top +
      _outerTop +
      _padTop +
      rowHeight +
      _gap +
      ZokyFoodSearchField.heightFor(context) +
      _padBottomOpen +
      _outerBottom;

  /// Compact pinned height: status bar and the card with the search field.
  static double minExtentFor(BuildContext context) =>
      MediaQuery.paddingOf(context).top +
      _outerTop +
      _padTop +
      ZokyFoodSearchField.heightFor(context) +
      _padBottomCompact +
      _outerBottom;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    const borderRadius = BorderRadius.all(Radius.circular(radius));
    final t = collapse.clamp(0.0, 1.0);
    final rowSpace = (rowHeight + _gap) * (1 - t);
    final padBottom = _padBottomOpen + (_padBottomCompact - _padBottomOpen) * t;
    final rowOpacity = (1 - t * 1.6).clamp(0.0, 1.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle,
      // White behind the status bar in both states (dark icons).
      child: ColoredBox(
        color: ZokyColors.surface,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ZokySpacing.gutter,
            topInset + _outerTop,
            ZokySpacing.gutter,
            _outerBottom,
          ),
          child: DecoratedBox(
            key: cardKey,
            decoration: const BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Color(0x29EE226E),
                  offset: Offset(0, 6),
                  blurRadius: 16,
                ),
              ],
            ),
            child: ZokyGlossySurface(
              borderRadius: borderRadius,
              glossHeight: 40,
              glossOpacity: 0.08,
              glossInset: 0,
              rim: false,
              shadow: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ZokySpacing.s2,
                  _padTop,
                  ZokySpacing.s2,
                  padBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The row folds away as the page scrolls; it stops
                    // taking taps once mostly hidden.
                    ClipRect(
                      child: SizedBox(
                        height: rowSpace,
                        child: OverflowBox(
                          alignment: Alignment.bottomCenter,
                          minHeight: rowHeight + _gap,
                          maxHeight: rowHeight + _gap,
                          child: IgnorePointer(
                            ignoring: t > 0.5,
                            child: ExcludeSemantics(
                              excluding: t > 0.5,
                              child: Opacity(
                                opacity: rowOpacity,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: _gap),
                                  child: _row(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZokySpacing.s6,
                      ),
                      child: search,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context) {
    return SizedBox(
      height: rowHeight,
      child: Row(
        children: [
          _HeaderIcon(
            key: backKey,
            icon: ZokyIcons.back(context),
            tooltip: ZokyStrings.back,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          // Same width on both sides keeps the title centered; narrow
          // phones give that room to the title instead.
          if (MediaQuery.sizeOf(context).width >= 360)
            const SizedBox(width: ZokySizes.tapTargetIos),
          Expanded(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: title,
            ),
          ),
          _HeaderIcon(
            key: favoritesKey,
            icon: ZokyIcons.favorite,
            tooltip: ZokyStrings.favoriteStores,
            onPressed: onFavorites,
          ),
          _HeaderIcon(
            key: couponsKey,
            icon: ZokyIcons.coupon,
            tooltip: ZokyStrings.coupons,
            onPressed: onCoupons,
          ),
        ],
      ),
    );
  }
}

/// White outline icon on the pink card, 44pt target.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 26),
      color: ZokyColors.onAction,
      tooltip: tooltip,
      constraints: const BoxConstraints(
        minWidth: ZokySizes.tapTargetIos,
        minHeight: ZokySizes.tapTargetIos,
      ),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}
