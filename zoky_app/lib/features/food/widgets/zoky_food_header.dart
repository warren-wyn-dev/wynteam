import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_glossy_surface.dart';
import '../../../core/widgets/zoky_line_icon.dart';
import 'zoky_food_mode_toggle.dart';
import 'zoky_food_search_field.dart';

/// Food page header (Founder feedback 2026-10-18, layout after LINE MAN,
/// ZOKY brand only): a full-bleed pink surface from the very top of the
/// screen (under the status bar) and edge to edge. Top to bottom:
/// 1. row: adaptive back, the left-aligned address block [title]
///    ("จัดส่งที่" / "บ้าน ▾", or "รับเองที่ร้าน ▾"), heart ("ร้านโปรด")
///    and the coupon ticket ("คูปองส่วนลด");
/// 2. the compact [modeChips] ("จัดส่ง | รับเองที่ร้าน"), left-aligned;
/// 3. the white [search] field;
/// 4. a white sheet with large rounded top corners, like Home's header,
///    so the page continues on white.
///
/// Why the sheet rather than a search field floating over the seam: the
/// search stays inside the pink (white on pink, no extra shadow), the
/// compact chips keep a calm pink band of their own, and it matches the
/// Home header family. Pinned: as the page scrolls, the row and the chips
/// fold away and the sheet flattens, leaving a full-bleed pink bar with
/// the search field ([collapse], see [maxExtentFor] / [minExtentFor]).
///
/// Surface: the ZOKY brand gradient deepening from [ZokyColors.headerTop]
/// under the status bar to [ZokyColors.brandDeep] where the content
/// starts ([gradientFor]), plus the faint top gloss of the Home header.
/// All small white text sits on brandDeep (5.15:1). The status bar always
/// has pink behind it, so its icons are light.
class ZokyFoodHeader extends StatelessWidget {
  const ZokyFoodHeader({
    super.key,
    required this.title,
    required this.modeChips,
    required this.search,
    required this.onFavorites,
    required this.onCoupons,
    this.collapse = 0,
  });

  final Widget title;
  final Widget modeChips;
  final Widget search;
  final VoidCallback onFavorites;
  final VoidCallback onCoupons;

  /// 0 = full header, 1 = compact pinned bar with only the search field
  /// (driven by the scroll offset, so there is no extra animation to
  /// reduce).
  final double collapse;

  /// Radius of the white sheet under the search field (same as Home).
  static const double sheetRadius = ZokyRadius.xxlValue + 4;

  /// Key of the full-bleed pink surface (tests).
  static const Key surfaceKey = ValueKey('zoky-food-header-surface');

  /// Key of the white sheet (tests).
  static const Key sheetKey = ValueKey('zoky-food-header-sheet');

  /// Back button key (tests).
  static const Key backKey = ValueKey('zoky-food-back');

  /// Heart and coupon button keys (tests).
  static const Key favoritesKey = ValueKey('zoky-food-favorites');
  static const Key couponsKey = ValueKey('zoky-food-coupons');

  /// Light status bar content over the pink (iOS: statusBarBrightness
  /// dark = light icons; Android: statusBarIconBrightness).
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  /// Peak opacity of the top sheen (fades to 0 at its lower edge).
  static const double glossOpacity = 0.06;

  /// Header text never scales past this (the page body still does).
  static const double maxTextScale = 1.3;

  static const double _padTopOpen = ZokySpacing.s2;
  static const double _padTopCompact = ZokySpacing.s3;
  static const double _gapAfterChips = ZokySpacing.s2;
  static const double _padBottomOpen = ZokySpacing.s6;
  static const double _padBottomCompact = ZokySpacing.s5;

  /// [context] with the header's clamped text scale.
  static MediaQueryData _clamped(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.copyWith(
      textScaler: media.textScaler.clamp(maxScaleFactor: maxTextScale),
    );
  }

  /// Address row height: 48pt, taller when the two lines need it.
  static double rowHeightFor(BuildContext context) {
    final scaler = _clamped(context).textScaler;
    final text = scaler.scale(13) * 1.3 + scaler.scale(17) * 1.3 + 4;
    return math.max(ZokySizes.tapTargetAndroid, text);
  }

  static double _chipsHeightFor(BuildContext context) =>
      ZokyFoodModeToggle.heightFor(context, _clamped(context).textScaler);

  /// Height of the part that folds away on scroll (row + chips).
  static double _foldFor(BuildContext context) =>
      rowHeightFor(context) + _chipsHeightFor(context) + _gapAfterChips;

  /// Full height: status bar, row, chips, search field and the sheet.
  static double maxExtentFor(BuildContext context) =>
      MediaQuery.paddingOf(context).top +
      _padTopOpen +
      _foldFor(context) +
      ZokyFoodSearchField.heightFor(context) +
      _padBottomOpen +
      sheetRadius;

  /// Compact pinned height: status bar and the search field on pink.
  static double minExtentFor(BuildContext context) =>
      MediaQuery.paddingOf(context).top +
      _padTopCompact +
      ZokyFoodSearchField.heightFor(context) +
      _padBottomCompact;

  /// Brand gradient for a header [height] tall whose content starts at
  /// [contentTop]: bright headerTop at the top, brandDeep from
  /// [contentTop] down.
  static LinearGradient gradientFor(double height, double contentTop) {
    final deepAt = height <= 0 ? 0.0 : (contentTop / height).clamp(0.0, 1.0);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        ZokyColors.headerTop,
        ZokyColors.headerBottom,
        ZokyColors.brandDeep,
      ],
      stops: [0, deepAt * 0.55, deepAt],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final t = collapse.clamp(0.0, 1.0);
    final padTop = _padTopOpen + (_padTopCompact - _padTopOpen) * t;
    final fold = _foldFor(context);
    final foldSpace = fold * (1 - t);
    final rowOpacity = (1 - t * 1.6).clamp(0.0, 1.0);
    final sheet = sheetRadius * (1 - t);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle,
      child: LayoutBuilder(
        builder: (context, constraints) => ZokyGlossySurface(
          key: surfaceKey,
          gradient: gradientFor(constraints.maxHeight, topInset + padTop),
          // Long, faint sheen ending under the address row: no visible
          // band edge, and white text over it stays >= 4.5:1 (tests).
          glossHeight: topInset + padTop + rowHeightFor(context) * (1 - t),
          glossOpacity: glossOpacity,
          glossInset: 0,
          rim: false,
          shadow: false,
          child: MediaQuery(
            data: _clamped(context),
            child: Padding(
              padding: EdgeInsets.only(top: topInset + padTop),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row + chips fold away as the page scrolls; they stop
                  // taking taps once mostly hidden.
                  ClipRect(
                    child: SizedBox(
                      height: foldSpace,
                      child: OverflowBox(
                        alignment: Alignment.bottomCenter,
                        minHeight: fold,
                        maxHeight: fold,
                        child: IgnorePointer(
                          ignoring: t > 0.5,
                          child: ExcludeSemantics(
                            excluding: t > 0.5,
                            child: Opacity(
                              opacity: rowOpacity,
                              child: _foldContent(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZokySpacing.gutter,
                    ),
                    child: MediaQuery(
                      // The field sizes itself from the page's text scale.
                      data: MediaQuery.of(context),
                      child: search,
                    ),
                  ),
                  // Bottom padding and the white sheet (absorbs rounding).
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          // 1px past the bottom: no hairline seam.
                          bottom: -1,
                          height: sheet + 1,
                          child: const DecoratedBox(
                            key: sheetKey,
                            decoration: BoxDecoration(
                              color: ZokyColors.surface,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(sheetRadius),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _foldContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: rowHeightFor(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZokySpacing.s2),
            child: Row(
              children: [
                _HeaderIcon(
                  key: backKey,
                  icon: Icon(ZokyIcons.back(context), size: 26),
                  tooltip: ZokyStrings.back,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: title),
                ),
                _HeaderIcon(
                  key: favoritesKey,
                  icon: const Icon(ZokyIcons.favorite, size: 26),
                  tooltip: ZokyStrings.favoriteStores,
                  onPressed: onFavorites,
                ),
                _HeaderIcon(
                  key: couponsKey,
                  icon: const ZokyLineIcon(
                    ZokyLineGlyph.ticket,
                    size: 26,
                    color: ZokyColors.onAction,
                  ),
                  tooltip: ZokyStrings.coupons,
                  onPressed: onCoupons,
                ),
              ],
            ),
          ),
        ),
        // Chips line up with the search field below.
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: ZokySpacing.gutter,
            end: ZokySpacing.gutter,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(height: _chipsHeightFor(context), child: modeChips),
          ),
        ),
        const SizedBox(height: _gapAfterChips),
      ],
    );
  }
}

/// White icon on the pink header, 44pt target.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: icon,
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
