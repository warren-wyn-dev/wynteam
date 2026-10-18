import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_3d_icon.dart';
import '../../../core/widgets/zoky_glossy_heart_button.dart';
import 'zoky_food_mode_toggle.dart';
import 'zoky_food_search_field.dart';

/// Food page header (Founder feedback 2026-10-18, layout after LINE MAN,
/// ZOKY brand only): a full-bleed pale blush surface from the very top of
/// the screen (under the status bar) and edge to edge. Top to bottom:
/// 1. row: adaptive back, the left-aligned address block [title]
///    ("จัดส่งที่" / "บ้าน ▾", or "รับเองที่ร้าน ▾"), heart ("ร้านโปรด")
///    and the coupon ticket ("คูปองส่วนลด");
/// 2. the compact [modeChips] ("จัดส่ง | รับเองที่ร้าน"), left-aligned;
/// 3. the white [search] field (soft shadow + hairline).
///
/// Surface (Founder: "พื้นชมพู ขอเป็นสีที่อ่อนสุดๆ"): the lightest blush
/// [ZokyColors.headerPale] (#FFEFF5) behind the status bar and the row,
/// fading through [ZokyColors.headerPaleMid] to pure white at the middle
/// of the search field ([gradientFor]), so the header melts into the white
/// page with no seam or sheet. Pinned: as the page scrolls, the row and
/// the chips fold away, leaving a pale bar with the search field
/// ([collapse], see [maxExtentFor] / [minExtentFor]).
///
/// Contrast on the lightest point of text (#FFEFF5; everything below it is
/// lighter, so higher): ink #16161A 16.25:1 (back, address name, ▾ is
/// brandDeep), textSecondary #6B6B76 4.74:1 ("จัดส่งที่", small text, passes
/// 4.5:1), brandDeep #D61256 4.64:1 (▾; >= 3:1 for non-text). Heart and
/// coupon are the Home header's glossy white buttons with 3D icons (pink
/// 3D on white; the circle has a soft pink shadow so it lifts off the
/// blush). The background is light, so the status bar icons are dark.
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

  /// Key of the full-bleed blush surface (tests).
  static const Key surfaceKey = ValueKey('zoky-food-header-surface');

  /// Back button key (tests).
  static const Key backKey = ValueKey('zoky-food-back');

  /// Heart and coupon button keys (tests).
  static const Key favoritesKey = ValueKey('zoky-food-favorites');
  static const Key couponsKey = ValueKey('zoky-food-coupons');

  /// Dark status bar content over the pale blush, open and pinned (iOS:
  /// statusBarBrightness light = dark icons; Android:
  /// statusBarIconBrightness).
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  /// Back arrow color (ink, 16.25:1 on [ZokyColors.headerPale]).
  static const Color backColor = ZokyColors.textPrimary;

  /// Visible circle of the glossy white heart / coupon buttons (3D icons
  /// inside, 44pt tap targets).
  static const double glossyDiameter = 38;

  /// Tight soft shadow of those buttons: it stays inside their 44pt tap
  /// box (Home's larger control shadow gets clipped to a visible square
  /// on the pale background).
  static const List<BoxShadow> glossyShadow = [
    BoxShadow(color: Color(0x29D61256), offset: Offset(0, 1), blurRadius: 3),
  ];

  /// Header text never scales past this (the page body still does).
  static const double maxTextScale = 1.3;

  static const double _padTopOpen = ZokySpacing.s2;
  static const double _padTopCompact = ZokySpacing.s3;
  static const double _gapAfterChips = ZokySpacing.s2;
  static const double _padBottomOpen = ZokySpacing.s6;
  static const double _padBottomCompact = ZokySpacing.s5;

  /// Extra white space under the search field when open (the page
  /// continues on the white the header fades into).
  static const double _seamOpen = ZokySpacing.s2;

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

  /// Full height: status bar, row, chips, search field and white space.
  static double maxExtentFor(BuildContext context) =>
      MediaQuery.paddingOf(context).top +
      _padTopOpen +
      _foldFor(context) +
      ZokyFoodSearchField.heightFor(context) +
      _padBottomOpen +
      _seamOpen;

  /// Compact pinned height: status bar and the search field.
  static double minExtentFor(BuildContext context) =>
      MediaQuery.paddingOf(context).top +
      _padTopCompact +
      ZokyFoodSearchField.heightFor(context) +
      _padBottomCompact;

  /// Blush gradient for a header [height] tall: [ZokyColors.headerPale]
  /// down to [fadeFrom] (all small text sits here or lower), then fading
  /// through [ZokyColors.headerPaleMid] to white at [whiteAt] and below.
  static LinearGradient gradientFor(
    double height,
    double fadeFrom,
    double whiteAt,
  ) {
    double frac(double y) => height <= 0 ? 0.0 : (y / height).clamp(0.0, 1.0);
    final from = frac(fadeFrom);
    final white = math.max(from, frac(whiteAt));
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        ZokyColors.headerPale,
        ZokyColors.headerPale,
        ZokyColors.headerPaleMid,
        ZokyColors.surface,
      ],
      stops: [0, from, (from + white) / 2, white],
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
    final contentTop = topInset + padTop;
    // Flat blush behind the row; fades over the chips to white at the
    // middle of the search field.
    final fadeFrom = contentTop + rowHeightFor(context) * (1 - t);
    final whiteAt =
        contentTop + foldSpace + ZokyFoodSearchField.heightFor(context) / 2;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle,
      child: LayoutBuilder(
        builder: (context, constraints) => DecoratedBox(
          key: surfaceKey,
          decoration: BoxDecoration(
            gradient: gradientFor(constraints.maxHeight, fadeFrom, whiteAt),
          ),
          child: MediaQuery(
            data: _clamped(context),
            child: Padding(
              padding: EdgeInsets.only(top: contentTop),
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
                  color: backColor,
                  icon: Icon(ZokyIcons.back(context), size: 26),
                  tooltip: ZokyStrings.back,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: title),
                ),
                // Glossy 3D accents (design 7.1), as on Home's header.
                Tooltip(
                  message: ZokyStrings.favoriteStores,
                  excludeFromSemantics: true,
                  child: ZokyGlossyHeartButton(
                    key: favoritesKey,
                    label: ZokyStrings.favoriteStores,
                    onPressed: onFavorites,
                    diameter: glossyDiameter,
                    tapTarget: ZokySizes.tapTargetIos,
                    shadow: glossyShadow,
                  ),
                ),
                Tooltip(
                  message: ZokyStrings.coupons,
                  excludeFromSemantics: true,
                  child: ZokyGlossyHeartButton(
                    key: couponsKey,
                    label: ZokyStrings.coupons,
                    onPressed: onCoupons,
                    diameter: glossyDiameter,
                    tapTarget: ZokySizes.tapTargetIos,
                    shadow: glossyShadow,
                    icon: Zoky3DIcon(
                      Zoky3DGlyph.ticket,
                      size: (glossyDiameter * 0.68).roundToDouble(),
                    ),
                  ),
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

/// Icon on the blush header in [color], 44pt target.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    super.key,
    required this.color,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Color color;
  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: icon,
      color: color,
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
