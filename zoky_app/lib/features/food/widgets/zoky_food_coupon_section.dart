import 'package:flutter/material.dart';

import '../../../core/adaptive/adaptive.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/format/money.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_line_icon.dart';
import '../../../core/widgets/zoky_skeleton.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../deals/widgets/zoky_deal_card.dart' show ZokyDemoBadge;
import '../../fulfillment/fulfillment_mode_controller.dart';
import '../../home/widgets/zoky_home_section_header.dart';
import '../collected_promos_controller.dart';

/// Stores whose promo can be collected in [mode] (web parity: promoStores
/// = directory stores with a `promo_name`). Pickup lists only pickup
/// stores and drops free-delivery promos, which do not apply there.
List<ZokyStoreSummary> couponStores(
  List<ZokyStoreSummary> stores,
  FulfillmentMode mode,
) => [
  for (final store in stores)
    if (store.hasPromo &&
        (mode == FulfillmentMode.delivery ||
            (store.supportsPickup && !store.promoFreeDelivery)))
      store,
];

/// "โค้ดลดเพิ่มสำหรับคุณ" + "ดูทั้งหมด >" and the coupon cards (Founder
/// mockup v2; web promoCard). Only real stores' promos (or demo promos,
/// labelled "ตัวอย่าง") are shown: no promo = no section. While [stores]
/// is null a skeleton card shows. Hidden when the directory failed to load:
/// coupons come from the same call, whose error and retry the store list
/// shows.
///
/// Web shows the first 4 and the rest in the "รวมโค้ดลดเพิ่ม" sheet.
class ZokyFoodCouponSection extends StatelessWidget {
  const ZokyFoodCouponSection({
    super.key,
    required this.stores,
    required this.failed,
    required this.mode,
    required this.collected,
    required this.onSeeAll,
  });

  /// Directory stores; null while loading.
  final List<ZokyStoreSummary>? stores;
  final bool failed;
  final FulfillmentMode mode;
  final CollectedPromosController collected;
  final VoidCallback onSeeAll;

  /// Section key (tests).
  static const Key sectionKey = ValueKey('zoky-food-coupons-section');

  /// Skeleton key (tests).
  static const Key skeletonKey = ValueKey('zoky-food-coupons-skeleton');

  /// Cards shown in the section (the rest are in the sheet).
  static const int maxCards = 4;

  @override
  Widget build(BuildContext context) {
    if (failed) return const SizedBox.shrink();
    final all = stores;
    final width = MediaQuery.sizeOf(context).width - 2 * ZokySpacing.gutter;
    if (all == null) {
      return Padding(
        key: skeletonKey,
        padding: const EdgeInsets.fromLTRB(
          ZokySpacing.gutter,
          ZokySpacing.s6,
          ZokySpacing.gutter,
          ZokySpacing.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ZokySkeleton(width: width * 0.55, height: 20),
            const SizedBox(height: ZokySpacing.s6),
            const ZokySkeleton(height: 76, borderRadius: ZokyRadius.lg),
          ],
        ),
      );
    }
    final shown = couponStores(all, mode);
    if (shown.isEmpty) return const SizedBox.shrink();
    final cards = shown.take(maxCards).toList();
    final cardWidth = cards.length == 1 ? width : width * 0.88;
    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.only(top: ZokySpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZokyHomeSectionHeader(
            title: ZokyStrings.couponsTitle,
            seeAllLabel: ZokyStrings.seeAllCoupons,
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: ZokySpacing.s2),
          ListenableBuilder(
            listenable: collected,
            builder: (context, _) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: ZokySpacing.gutter,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, store) in cards.indexed) ...[
                      if (i > 0) const SizedBox(width: ZokySpacing.s6),
                      SizedBox(
                        width: cardWidth,
                        child: ZokyFoodCouponCard(
                          store: store,
                          collected: collected.isCollected(store.id),
                          onToggle: () => collected.toggle(store.id),
                          compact: ZokyFoodCouponCard.compactFor(
                            context,
                            cardWidth,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One coupon: ticket (or bike for free delivery) icon, promo label (web
/// foodPromoLabel) with the demo badge, "store · condition" and the
/// "เก็บโค้ด" / "เก็บแล้ว" toggle (web aria-pressed = toggled semantics).
class ZokyFoodCouponCard extends StatelessWidget {
  const ZokyFoodCouponCard({
    super.key,
    required this.store,
    required this.collected,
    required this.onToggle,
    this.compact = false,
  });

  final ZokyStoreSummary store;
  final bool collected;
  final VoidCallback onToggle;

  /// Narrow card or large text: the button moves under the copy.
  final bool compact;

  /// Whether a card [width] wide needs the [compact] layout.
  static bool compactFor(BuildContext context, double width) =>
      width < MediaQuery.textScalerOf(context).scale(300);

  /// Card background: soft blush.
  static const Color background = Color(0xFFFDEEF3);

  /// Web: "เมื่อสั่งครบ ฿X" when there is a minimum, else the promo name.
  static String conditionFor(ZokyStoreSummary store) {
    final name = store.isDemo ? store.nameWithoutDemoSuffix : store.name;
    final condition = store.promoMinSubtotal > 0
        ? '${ZokyStrings.promoMinSubtotal} ${formatBaht(store.promoMinSubtotal)}'
        : store.promoName;
    return condition == null || condition.isEmpty ? name : '$name · $condition';
  }

  @override
  Widget build(BuildContext context) {
    final label =
        store.promoLabel ?? store.promoName ?? ZokyStrings.promoFallback;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ZokySpacing.s8,
        ZokySpacing.s7,
        ZokySpacing.s6,
        ZokySpacing.s7,
      ),
      decoration: const BoxDecoration(
        color: background,
        borderRadius: ZokyRadius.lg,
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ZokyLineIcon(
                      store.promoFreeDelivery
                          ? ZokyLineGlyph.scooter
                          : ZokyLineGlyph.ticket,
                      size: 30,
                      color: ZokyColors.brandDeep,
                    ),
                    const SizedBox(width: ZokySpacing.s6),
                    Expanded(
                      child: Semantics(
                        container: true,
                        label: [
                          if (store.isDemo) ZokyStrings.demoBadge,
                          label,
                          conditionFor(store),
                        ].join(', '),
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              spacing: ZokySpacing.s3,
                              runSpacing: ZokySpacing.s1,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  label,
                                  style: ZokyTextStyles.weight(
                                    ZokyTextStyles.bodyLg.copyWith(
                                      fontSize: 18,
                                      height: 1.3,
                                    ),
                                    FontWeight.w700,
                                  ),
                                ),
                                if (store.isDemo) const ZokyDemoBadge(),
                              ],
                            ),
                            const SizedBox(height: ZokySpacing.s1),
                            Text(
                              conditionFor(store),
                              // Price condition: wraps, never cut (ZOKY-129).
                              style: ZokyTextStyles.bodyMd.copyWith(
                                color: ZokyColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZokySpacing.s4),
                // Start side: the floating cart button sits at the end
                // and covered "เก็บโค้ด" on small phones (ZOKY-131).
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ZokyCollectButton(
                    collected: collected,
                    onPressed: onToggle,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                ZokyLineIcon(
                  store.promoFreeDelivery
                      ? ZokyLineGlyph.scooter
                      : ZokyLineGlyph.ticket,
                  size: 30,
                  color: ZokyColors.brandDeep,
                ),
                const SizedBox(width: ZokySpacing.s6),
                Expanded(
                  child: Semantics(
                    container: true,
                    label: [
                      if (store.isDemo) ZokyStrings.demoBadge,
                      label,
                      conditionFor(store),
                    ].join(', '),
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: ZokySpacing.s3,
                          runSpacing: ZokySpacing.s1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              label,
                              style: ZokyTextStyles.weight(
                                ZokyTextStyles.bodyLg.copyWith(
                                  fontSize: 18,
                                  height: 1.3,
                                ),
                                FontWeight.w700,
                              ),
                            ),
                            if (store.isDemo) const ZokyDemoBadge(),
                          ],
                        ),
                        const SizedBox(height: ZokySpacing.s1),
                        Text(
                          conditionFor(store),
                          // Price condition: wraps, never cut (ZOKY-129).
                          style: ZokyTextStyles.bodyMd.copyWith(
                            color: ZokyColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: ZokySpacing.s4),
                ZokyCollectButton(collected: collected, onPressed: onToggle),
              ],
            ),
    );
  }
}

/// "เก็บโค้ด" (filled) / "เก็บแล้ว" (outlined, check) pill, 44pt target.
class ZokyCollectButton extends StatelessWidget {
  const ZokyCollectButton({
    super.key,
    required this.collected,
    required this.onPressed,
  });

  final bool collected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = collected ? ZokyColors.brandDeep : ZokyColors.onAction;
    final text = collected
        ? ZokyStrings.codeCollected
        : ZokyStrings.collectCode;
    return Semantics(
      button: true,
      toggled: collected,
      label: text,
      excludeSemantics: true,
      child: Material(
        color: collected ? ZokyColors.surface : ZokyColors.actionPrimary,
        shape: StadiumBorder(
          side: BorderSide(
            color: collected ? ZokyColors.brandLine : ZokyColors.actionPrimary,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ZokySizes.tapTargetIos,
              minWidth: ZokySizes.tapTargetIos,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZokySpacing.s8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (collected) ...[
                    ZokyLineIcon(ZokyLineGlyph.check, size: 18, color: fg),
                    const SizedBox(width: ZokySpacing.s2),
                  ],
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Text(
                      text,
                      maxLines: 1,
                      style: ZokyTextStyles.labelLg.copyWith(color: fg),
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

/// "รวมโค้ดลดเพิ่ม" sheet (web: browse === "promos"): every coupon of
/// [stores] stacked, or a short empty message.
Future<void> showZokyCouponsSheet(
  BuildContext context, {
  required List<ZokyStoreSummary> stores,
  required CollectedPromosController collected,
}) {
  return showZokySheet<void>(
    context: context,
    builder: (sheetContext) => ListenableBuilder(
      listenable: collected,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          ZokySpacing.gutter,
          ZokySpacing.s4,
          ZokySpacing.gutter,
          ZokySpacing.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                ZokyStrings.couponsSheetTitle,
                style: ZokyTextStyles.titleSm,
              ),
            ),
            const SizedBox(height: ZokySpacing.s6),
            if (stores.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: ZokySpacing.s12),
                child: Text(
                  ZokyStrings.couponsEmpty,
                  textAlign: TextAlign.center,
                  style: ZokyTextStyles.bodyMd.copyWith(
                    color: ZokyColors.textSecondary,
                  ),
                ),
              ),
            for (final (i, store) in stores.indexed) ...[
              if (i > 0) const SizedBox(height: ZokySpacing.s6),
              ZokyFoodCouponCard(
                store: store,
                collected: collected.isCollected(store.id),
                onToggle: () => collected.toggle(store.id),
                compact: ZokyFoodCouponCard.compactFor(
                  context,
                  MediaQuery.sizeOf(context).width - 2 * ZokySpacing.gutter,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
