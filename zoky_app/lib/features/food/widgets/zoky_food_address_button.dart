import 'package:flutter/material.dart';

import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../address/delivery_address_controller.dart';
import '../../fulfillment/fulfillment_mode_controller.dart';

/// Centered title of the food page header (Founder mockup v2): white bold
/// "จัดส่งที่ บ้าน ▾", or "รับเองใกล้ บ้าน ▾" in pickup mode,
/// where the address is the reference location for nearby stores. Tapping
/// it opens the address sheet.
///
/// Contrast: bold 18pt white on the brand pink is large text (>= 3:1);
/// the address name ellipsizes rather than wrapping. One 44pt button for
/// assistive tech, announced with the full text.
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

  /// Name shown for [controller]'s state.
  static String nameFor(DeliveryAddressController controller) =>
      controller.selected?.label ?? ZokyStrings.chooseDeliveryAddress;

  /// Text before the address name for [mode].
  static String prefixFor(FulfillmentMode mode) => switch (mode) {
    FulfillmentMode.delivery => ZokyStrings.deliverAt,
    FulfillmentMode.pickup => ZokyStrings.pickupNear,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, mode]),
      builder: (context, _) {
        final name = nameFor(controller);
        final prefix = prefixFor(mode.mode);
        final style = ZokyTextStyles.weight(
          ZokyTextStyles.labelLg.copyWith(
            fontSize: 18,
            height: 1.25,
            color: ZokyColors.onAction,
          ),
          FontWeight.w700,
        );
        return Semantics(
          button: true,
          label: '$prefix $name',
          hint: ZokyStrings.chooseDeliveryAddress,
          excludeSemantics: true,
          child: InkWell(
            onTap: onPressed,
            borderRadius: ZokyRadius.full,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: ZokySizes.tapTargetIos,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      '$prefix $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: style,
                    ),
                  ),
                  const SizedBox(width: ZokySpacing.s2),
                  const Icon(
                    ZokyIcons.chevronDown,
                    size: 24,
                    color: ZokyColors.onAction,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
