import 'package:flutter/material.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_line_icon.dart';
import '../../address/delivery_address_controller.dart';
import '../../fulfillment/fulfillment_mode_controller.dart';

/// Address block of the food page header (Founder feedback 2026-10-18,
/// LINE MAN-style layout): left-aligned, two lines in delivery mode -- a
/// small "จัดส่งที่" label over the bold address name and a painted ▾ --
/// and the single bold "รับเองที่ร้าน ▾" in pickup mode (Founder,
/// 2026-10-18); the selected address stays the reference location for
/// nearby stores. Tapping it opens the address sheet.
///
/// Contrast: both lines are pure white on the header's
/// [ZokyColors.brandDeep] band (5.15:1, passes 4.5:1 for small text). The
/// address name ellipsizes rather than wrapping. One 44pt+ button for
/// assistive tech, announced with the full text ([titleFor]).
class ZokyFoodAddressButton extends StatelessWidget {
  const ZokyFoodAddressButton({
    super.key,
    required this.controller,
    required this.mode,
    required this.onPressed,
  });

  final DeliveryAddressController controller;
  final FulfillmentModeController mode;
  final VoidCallback onPressed;

  /// Small label line style (delivery mode).
  static TextStyle get labelStyle => ZokyTextStyles.weight(
    ZokyTextStyles.labelMd.copyWith(
      fontSize: 13,
      height: 1.3,
      color: ZokyColors.onAction,
    ),
    FontWeight.w600,
  );

  /// Bold title line style.
  static TextStyle get titleStyle => ZokyTextStyles.weight(
    ZokyTextStyles.labelLg.copyWith(
      fontSize: 17,
      height: 1.3,
      color: ZokyColors.onAction,
    ),
    FontWeight.w700,
  );

  /// Height of the two text lines at the ambient text scale.
  static double textHeightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return scaler.scale(13) * 1.3 + scaler.scale(17) * 1.3;
  }

  /// Name shown for [controller]'s state.
  static String nameFor(DeliveryAddressController controller) =>
      controller.selected?.label ?? ZokyStrings.chooseDeliveryAddress;

  /// Full header text for [mode] and the selected address [name] (screen
  /// readers announce this).
  static String titleFor(FulfillmentMode mode, String name) => switch (mode) {
    FulfillmentMode.delivery => '${ZokyStrings.deliverAt} $name',
    FulfillmentMode.pickup => ZokyStrings.modePickup,
  };

  /// Visible bold line for [mode]: the address name, or "รับเองที่ร้าน".
  static String boldLineFor(FulfillmentMode mode, String name) =>
      switch (mode) {
        FulfillmentMode.delivery => name,
        FulfillmentMode.pickup => ZokyStrings.modePickup,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, mode]),
      builder: (context, _) {
        final name = nameFor(controller);
        final delivery = mode.mode == FulfillmentMode.delivery;
        return Semantics(
          button: true,
          label: titleFor(mode.mode, name),
          hint: ZokyStrings.chooseDeliveryAddress,
          excludeSemantics: true,
          child: InkWell(
            onTap: onPressed,
            borderRadius: ZokyRadius.md,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: ZokySizes.tapTargetIos,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZokySpacing.s2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (delivery)
                      Text(
                        ZokyStrings.deliverAt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            boldLineFor(mode.mode, name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                        const SizedBox(width: ZokySpacing.s1),
                        const ZokyLineIcon(
                          ZokyLineGlyph.caretDown,
                          size: 20,
                          color: ZokyColors.onAction,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
