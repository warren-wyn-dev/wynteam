import 'package:flutter/material.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../fulfillment/fulfillment_mode_controller.dart';

/// "จัดส่ง | รับเองที่ร้าน" segmented toggle under the food page header
/// (Founder mockup v2; pickup opened by Founder decision "ค", 2026-10-18).
/// Two equal pills: the selected one is filled [ZokyColors.actionPrimary]
/// with white text (5.15:1), the other light gray with ink text.
///
/// Each pill is a button with a selected state, at least 44pt tall, and
/// grows with the text scale.
class ZokyFoodModeToggle extends StatelessWidget {
  const ZokyFoodModeToggle({super.key, required this.controller});

  final FulfillmentModeController controller;

  /// Pill keys (tests).
  static Key keyFor(FulfillmentMode mode) =>
      ValueKey('zoky-food-mode-${mode.name}');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Semantics(
        container: true,
        label: ZokyStrings.fulfillmentModeLabel,
        child: Row(
          children: [
            for (final (i, mode) in FulfillmentMode.values.indexed) ...[
              if (i > 0) const SizedBox(width: ZokySpacing.s4),
              Expanded(
                child: _Pill(
                  key: keyFor(mode),
                  label: switch (mode) {
                    FulfillmentMode.delivery => ZokyStrings.modeDelivery,
                    FulfillmentMode.pickup => ZokyStrings.modePickup,
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

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = ZokyTextStyles.weight(
      ZokyTextStyles.labelLg.copyWith(
        color: selected ? ZokyColors.onAction : ZokyColors.textPrimary,
      ),
      selected ? FontWeight.w700 : FontWeight.w600,
    );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? ZokyColors.actionPrimary : ZokyColors.chip,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ZokySizes.tapTargetIos,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZokySpacing.s4,
                vertical: ZokySpacing.s4,
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
