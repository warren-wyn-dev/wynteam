import 'package:flutter/material.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/adaptive/zoky_icons.dart';
import '../../core/design/zoky_colors.dart';
import '../../core/design/zoky_tokens.dart';
import '../../core/design/zoky_typography.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_button.dart';
import 'domain/deal_models.dart';
import 'widgets/zoky_deal_card.dart';
import 'widgets/zoky_deal_illustration.dart';

/// Deal detail placeholder (adaptive sheet). Shows only what the deal says;
/// sample deals are marked "ตัวอย่าง — ยังไม่ใช่โปรโมชันจริง" and offer no
/// claim, collect or order action.
Future<void> showZokyDealSheet(BuildContext context, ZokyDeal deal) {
  return showZokySheet<void>(
    context: context,
    builder: (sheetContext) => ZokyDealDetail(deal: deal),
  );
}

class ZokyDealDetail extends StatelessWidget {
  const ZokyDealDetail({super.key, required this.deal});

  final ZokyDeal deal;

  @override
  Widget build(BuildContext context) {
    final minimum = deal.minimumLabel;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ZokySpacing.s12,
        ZokySpacing.s4,
        ZokySpacing.s12,
        ZokySpacing.s12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: ZokyDealIllustration(art: deal.art, size: 112)),
          const SizedBox(height: ZokySpacing.s6),
          if (deal.isDemo) ...[
            const ZokyDemoBadge(),
            const SizedBox(height: ZokySpacing.s4),
          ],
          Semantics(
            header: true,
            child: Text(deal.headline, style: ZokyDealCard.headlineStyle),
          ),
          const SizedBox(height: ZokySpacing.s2),
          Text(deal.description, style: ZokyTextStyles.titleSm),
          if (deal.storeName != null) ...[
            const SizedBox(height: ZokySpacing.s2),
            Text(
              deal.storeName!,
              style: ZokyTextStyles.bodyMd.copyWith(
                color: ZokyColors.textSecondary,
              ),
            ),
          ],
          if (minimum != null) ...[
            const SizedBox(height: ZokySpacing.s2),
            Text(
              minimum,
              style: ZokyTextStyles.bodyMd.copyWith(
                color: ZokyColors.textSecondary,
              ),
            ),
          ],
          if (deal.isDemo) ...[
            const SizedBox(height: ZokySpacing.s8),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: ZokyColors.warningContainer,
                borderRadius: ZokyRadius.md,
              ),
              child: Padding(
                padding: const EdgeInsets.all(ZokySpacing.s6),
                child: Row(
                  children: [
                    const Icon(
                      ZokyIcons.info,
                      size: ZokySizes.iconMd,
                      color: ZokyColors.warning,
                    ),
                    const SizedBox(width: ZokySpacing.s4),
                    Expanded(
                      child: Text(
                        ZokyStrings.demoDealDisclaimer,
                        style: ZokyTextStyles.labelMd.copyWith(
                          color: ZokyColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: ZokySpacing.s10),
          ZokyButton(
            label: ZokyStrings.close,
            variant: ZokyButtonVariant.soft,
            expand: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
