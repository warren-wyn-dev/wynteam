import 'package:flutter/material.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_line_icon.dart';
import '../../fulfillment/fulfillment_mode_controller.dart';

/// Compact "จัดส่ง | รับเองที่ร้าน" chips inside the pink food page header
/// (Founder feedback 2026-10-18: "เล็กๆที่สุดเท่าที่ทำได้ แต่ต้องดูดี";
/// pickup opened by Founder decision "ค"). Two small left-aligned pills,
/// each a painted icon (scooter / bag) and the label:
/// - selected: white pill, [ZokyColors.brandDeep] icon and text (5.15:1);
/// - unselected: [unselectedFill] (white 12%) pill with a faint white rim,
///   white icon and text (>= 4.5:1 on the brandDeep header, see tests).
///
/// The pill is ~32pt tall ([pillHeightFor]) but each chip takes taps over
/// a 44pt-high box ([ZokySizes.tapTargetIos]); the extra space is
/// invisible. Each chip is a button with a selected state.
class ZokyFoodModeToggle extends StatelessWidget {
  const ZokyFoodModeToggle({super.key, required this.controller});

  final FulfillmentModeController controller;

  /// Chip keys (the 44pt tap box; tests).
  static Key keyFor(FulfillmentMode mode) =>
      ValueKey('zoky-food-mode-${mode.name}');

  /// Unselected pill fill on the pink header.
  static const Color unselectedFill = Color(0x1FFFFFFF);

  /// Unselected pill rim.
  static const Color unselectedRim = Color(0x4DFFFFFF);

  static const double _fontSize = 13;
  static const double _lineHeight = 1.3;

  /// Visible pill height: 32pt, taller with large text.
  static double pillHeightFor(BuildContext context, [TextScaler? scaler]) {
    final text =
        (scaler ?? MediaQuery.textScalerOf(context)).scale(_fontSize) *
        _lineHeight;
    final pill = text + 2 * ZokySpacing.s3;
    return pill > 32 ? pill : 32;
  }

  /// Height the chip row takes (the tap boxes).
  static double heightFor(BuildContext context, [TextScaler? scaler]) {
    final pill = pillHeightFor(context, scaler);
    return pill > ZokySizes.tapTargetIos ? pill : ZokySizes.tapTargetIos;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Semantics(
        container: true,
        label: ZokyStrings.fulfillmentModeLabel,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, mode) in FulfillmentMode.values.indexed) ...[
              if (i > 0) const SizedBox(width: ZokySpacing.s4),
              Flexible(
                child: _ModeChip(
                  key: keyFor(mode),
                  label: switch (mode) {
                    FulfillmentMode.delivery => ZokyStrings.modeDelivery,
                    FulfillmentMode.pickup => ZokyStrings.modePickup,
                  },
                  glyph: switch (mode) {
                    FulfillmentMode.delivery => ZokyLineGlyph.scooter,
                    FulfillmentMode.pickup => ZokyLineGlyph.bag,
                  },
                  selected: controller.mode == mode,
                  onTap: () => controller.select(mode),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    super.key,
    required this.label,
    required this.glyph,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final ZokyLineGlyph glyph;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? ZokyColors.brandDeep : ZokyColors.onAction;
    final style = ZokyTextStyles.weight(
      ZokyTextStyles.labelMd.copyWith(
        fontSize: ZokyFoodModeToggle._fontSize,
        height: ZokyFoodModeToggle._lineHeight,
        color: fg,
      ),
      FontWeight.w700,
    );
    final pillHeight = ZokyFoodModeToggle.pillHeightFor(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        // The whole 44pt box takes the tap, not only the visible pill.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: ZokyFoodModeToggle.heightFor(context),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : ZokyMotion.press,
              height: pillHeight,
              padding: const EdgeInsetsDirectional.only(
                start: ZokySpacing.s5,
                end: ZokySpacing.s6,
              ),
              decoration: ShapeDecoration(
                color: selected
                    ? ZokyColors.surface
                    : ZokyFoodModeToggle.unselectedFill,
                shape: StadiumBorder(
                  side: selected
                      ? BorderSide.none
                      : const BorderSide(
                          color: ZokyFoodModeToggle.unselectedRim,
                        ),
                ),
                shadows: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x33991636),
                          offset: Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ZokyLineIcon(glyph, size: 18, color: fg),
                  const SizedBox(width: ZokySpacing.s2),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
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
