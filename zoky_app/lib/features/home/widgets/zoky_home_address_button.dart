import 'package:flutter/material.dart';

import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_glossy_surface.dart';
import '../../address/delivery_address_controller.dart';

/// Home v2 delivery address row in the pink header: a compact white glossy
/// pill with a pin, a small "จัดส่งที่" label, the selected address name in
/// bold and a ▾ chevron. Tapping it opens the address sheet.
///
/// Contrast: the text sits on the white glossy control, never on the pink
/// (white small text on #F93384 is only ~3.6:1): the label is
/// [ZokyColors.textSecondary] (>= 4.8:1 on [ZokyGloss.whiteBottom]) and the
/// name is ink. The whole row is a 44pt target, one button for assistive
/// tech ("จัดส่งที่ บ้าน").
class ZokyHomeAddressButton extends StatelessWidget {
  const ZokyHomeAddressButton({
    super.key,
    required this.controller,
    required this.onPressed,
  });

  final DeliveryAddressController controller;
  final VoidCallback onPressed;

  static const BorderRadius _radius = ZokyRadius.full;

  /// Name shown for [controller]'s state.
  static String nameFor(DeliveryAddressController controller) =>
      controller.selected?.label ?? ZokyStrings.chooseDeliveryAddress;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final name = nameFor(controller);
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            button: true,
            label: '${ZokyStrings.deliverAt} $name',
            hint: ZokyStrings.chooseDeliveryAddress,
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: ZokySizes.tapTargetIos,
              ),
              // Shadow outside the Material (ink is clipped to its box).
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  borderRadius: _radius,
                  boxShadow: ZokyGloss.controlShadow,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Ink(
                    decoration: const BoxDecoration(
                      borderRadius: _radius,
                      gradient: ZokyGloss.white,
                    ),
                    child: InkWell(
                      onTap: onPressed,
                      borderRadius: _radius,
                      child: CustomPaint(
                        painter: const ZokyGlossPainter(
                          gradient: null,
                          borderRadius: _radius,
                          glossHeight: 0,
                          rimTop: ZokyGloss.controlRimTop,
                          rimBottom: ZokyGloss.controlRimBottom,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            ZokySpacing.s5,
                            ZokySpacing.s4,
                            ZokySpacing.s4,
                            ZokySpacing.s4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                ZokyIcons.location,
                                size: 18,
                                color: ZokyColors.brandDeep,
                              ),
                              const SizedBox(width: ZokySpacing.s2),
                              // One line: the label then the bold name;
                              // the name ellipsizes at large text sizes.
                              Flexible(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${ZokyStrings.deliverAt}  ',
                                        style: ZokyTextStyles.bodySm.copyWith(
                                          height: 1.2,
                                        ),
                                      ),
                                      TextSpan(
                                        text: name,
                                        style: ZokyTextStyles.weight(
                                          ZokyTextStyles.labelMd.copyWith(
                                            height: 1.2,
                                          ),
                                          FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: ZokySpacing.s1),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: ZokyColors.textPrimary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
