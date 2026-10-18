import 'package:flutter/material.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/design/zoky_colors.dart';
import '../../core/design/zoky_tokens.dart';
import '../../core/design/zoky_typography.dart';
import '../../core/l10n/zoky_strings.dart';
import 'delivery_address_controller.dart';
import 'domain/address_models.dart';
import '../../core/widgets/zoky_line_icon.dart';

/// "เลือกที่อยู่จัดส่ง" adaptive sheet opened from the Home address row:
/// the saved addresses (tap = select + close) and a "เพิ่มที่อยู่ใหม่" row
/// that only says "เร็ว ๆ นี้" until address entry ships (no map picking).
/// Demo addresses are called out under the title.
Future<void> showZokyAddressSheet(
  BuildContext context,
  DeliveryAddressController controller,
) {
  controller.load();
  return showZokySheet<void>(
    context: context,
    builder: (sheetContext) => ZokyAddressSheet(controller: controller),
  );
}

class ZokyAddressSheet extends StatelessWidget {
  const ZokyAddressSheet({super.key, required this.controller});

  final DeliveryAddressController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final addresses = controller.addresses;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: ZokySpacing.s8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZokySpacing.s12,
                  ZokySpacing.s4,
                  ZokySpacing.s12,
                  ZokySpacing.s4,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    ZokyStrings.chooseDeliveryAddress,
                    style: ZokyTextStyles.titleSm,
                  ),
                ),
              ),
              if (addresses != null && addresses.any((a) => a.isDemo))
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    ZokySpacing.s12,
                    0,
                    ZokySpacing.s12,
                    ZokySpacing.s4,
                  ),
                  child: _DemoNote(),
                ),
              if (addresses == null && controller.error != null)
                Padding(
                  padding: const EdgeInsets.all(ZokySpacing.s12),
                  child: Column(
                    children: [
                      Text(
                        ZokyStrings.loadErrorTitle,
                        style: ZokyTextStyles.bodyMd,
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => controller.load(force: true),
                        child: const Text(ZokyStrings.retry),
                      ),
                    ],
                  ),
                )
              else if (addresses == null)
                const Padding(
                  padding: EdgeInsets.all(ZokySpacing.s16),
                  child: Center(child: ZokySpinner(size: 24)),
                )
              else
                for (final address in addresses)
                  ZokyAddressTile(
                    address: address,
                    selected: address.id == controller.selected?.id,
                    onTap: () {
                      controller.select(address);
                      Navigator.of(context).maybePop();
                    },
                  ),
              const Divider(
                height: ZokySpacing.s8,
                indent: ZokySpacing.s12,
                endIndent: ZokySpacing.s12,
                color: ZokyColors.borderSubtle,
              ),
              const _AddAddressRow(),
            ],
          ),
        );
      },
    );
  }
}

class _DemoNote extends StatelessWidget {
  const _DemoNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ZokyLineIcon(
          ZokyLineGlyph.info,
          size: ZokySizes.iconSm,
          color: ZokyColors.warning,
        ),
        const SizedBox(width: ZokySpacing.s3),
        Expanded(
          child: Text(
            ZokyStrings.demoAddressLabel,
            style: ZokyTextStyles.bodySm.copyWith(color: ZokyColors.warning),
          ),
        ),
      ],
    );
  }
}

/// One saved address: pin, bold label, address text (2 lines) and a check
/// on the selected one. A selectable button for assistive tech.
class ZokyAddressTile extends StatelessWidget {
  const ZokyAddressTile({
    super.key,
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final ZokyDeliveryAddress address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '${address.label} ${address.address}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ZokySpacing.s12,
              vertical: ZokySpacing.s6,
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected ? ZokyColors.blush : ZokyColors.chip,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(ZokySpacing.s4),
                    child: ZokyLineIcon(
                      ZokyLineGlyph.pin,
                      size: ZokySizes.iconMd,
                      color: selected
                          ? ZokyColors.brandDeep
                          : ZokyColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: ZokySpacing.s6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address.label,
                        style: ZokyTextStyles.weight(
                          ZokyTextStyles.bodyMd,
                          FontWeight.w700,
                        ),
                      ),
                      Text(
                        address.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ZokyTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ZokySpacing.s4),
                SizedBox.square(
                  dimension: ZokySizes.iconLg,
                  child: selected
                      ? const ZokyLineIcon(
                          ZokyLineGlyph.checkCircle,
                          color: ZokyColors.brandDeep,
                          size: ZokySizes.iconLg,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "เพิ่มที่อยู่ใหม่" placeholder: not interactive yet, says "เร็ว ๆ นี้".
class _AddAddressRow extends StatelessWidget {
  const _AddAddressRow();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${ZokyStrings.addNewAddress} ${ZokyStrings.comingSoon}',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ZokySpacing.s12,
            vertical: ZokySpacing.s4,
          ),
          child: Row(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: ZokyColors.chip,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(ZokySpacing.s4),
                  child: ZokyLineIcon(
                    ZokyLineGlyph.plus,
                    size: ZokySizes.iconMd,
                    color: ZokyColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: ZokySpacing.s6),
              Expanded(
                child: Text(
                  ZokyStrings.addNewAddress,
                  style: ZokyTextStyles.bodyMd.copyWith(
                    color: ZokyColors.textSecondary,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: ZokyColors.chip,
                  borderRadius: ZokyRadius.full,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZokySpacing.s4,
                    vertical: ZokySpacing.s1,
                  ),
                  child: Text(
                    ZokyStrings.comingSoon,
                    style: ZokyTextStyles.labelSm.copyWith(
                      color: ZokyColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
