// CANONICAL SOURCE: app/lib/core/design/wyn_spacing.dart — DO NOT EDIT THE MIRROR IN seller_app/ DIRECTLY.
//
// WYN Design System — spacing / radius / touch-target tokens.
// Values copied verbatim from `.wyn/docs/design/ds-001-color-system.md`,
// Section 6 (Spacing / Radius / Touch Target). Token names skip numbers
// that don't have a corresponding value in the source table (e.g. there is
// no `space7`/`space9`/`space11`) -- this matches the doc exactly, do not
// fill in the gaps.
class WynSpacing {
  WynSpacing._();

  // ---------------------------------------------------------------------
  // Spacing (4px grid)
  // ---------------------------------------------------------------------

  /// Gap between an icon and its adjacent count label.
  static const double space1 = 4;

  /// Gap inside a component.
  static const double space2 = 8;

  /// Horizontal padding of a list item.
  static const double space3 = 12;

  /// Standard screen-edge padding, and gap between elements in the same
  /// group.
  static const double space4 = 16;

  static const double space5 = 20;

  /// Gap between groups/sections.
  static const double space6 = 24;

  /// Gap between large blocks.
  static const double space8 = 32;

  static const double space10 = 40;

  /// Vertical padding above/below an empty state.
  static const double space12 = 48;

  // ---------------------------------------------------------------------
  // Radius
  // ---------------------------------------------------------------------

  /// Full-width images in feeds (let the image be the hero, no rounding).
  static const double radiusNone = 0;

  /// Chips, badges, small thumbnails.
  static const double radiusSm = 8;

  /// Default radius -- buttons, inputs, cards.
  static const double radiusMd = 12;

  /// Bottom sheets, dialogs, ZOKY product cards.
  static const double radiusLg = 16;

  /// Avatars, round buttons, pills.
  static const double radiusFull = 999;

  // ---------------------------------------------------------------------
  // Touch target
  // ---------------------------------------------------------------------

  /// Absolute minimum size for anything tappable.
  static const double touchTargetMin = 44.0;

  /// Recommended size -- matches Flutter's
  /// `MaterialTapTargetSize.padded` default.
  static const double touchTargetRecommended = 48.0;
}
