import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_3d_icon.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../deals/domain/deal_models.dart';
import '../../deals/widgets/zoky_deal_card.dart' show ZokyDemoBadge;
import '../../fulfillment/fulfillment_mode_controller.dart';
import '../../home/widgets/zoky_recommended_store_card.dart'
    show ZokyRecommendedStoreCard;
import '../../home/widgets/zoky_store_cover.dart';
import '../../../core/widgets/zoky_line_icon.dart';

/// One store in the food page's "ร้านอาหารทั้งหมด" list (Founder mockup
/// v2): a rounded 1:1 photo on the left (real cover, else the 3D dish art
/// on a soft tint), and on the right the bold name, a gray
/// "หมวด · คะแนน · เวลา · ระยะ" line (each part only when the data exists),
/// short labels and the pink "ดูเมนู →" link. The whole row is one button.
///
/// [mode] pickup hides delivery-only info (ETA, free-delivery promo) and
/// adds "รับเองได้". Labels (closed, ad, promo, pickup) sit in the text
/// column and wrap instead of being cut (ZOKY-127); the name and the meta
/// line wrap too, so ETA and distance are never ellipsized (ZOKY-129).
/// Demo stores carry the "ตัวอย่าง" badge on the photo (ZOKY-123).
class ZokyFoodStoreRow extends StatelessWidget {
  const ZokyFoodStoreRow({
    super.key,
    required this.store,
    required this.mode,
    required this.onTap,
    this.fallbackArt,
  });

  final ZokyStoreSummary store;
  final FulfillmentMode mode;
  final VoidCallback onTap;

  /// Dish art when the store has no photo or art of its own.
  final ZokyDealArt? fallbackArt;

  /// Photo side for a viewport [width] wide: ~110pt, smaller on narrow
  /// phones.
  static double photoSize(double width) => math.min(110, width * 0.28);

  bool get _pickup => mode == FulfillmentMode.pickup;

  /// The promo label, unless it does not apply in [mode].
  String? get _promo => store.hasPromo && !(_pickup && store.promoFreeDelivery)
      ? store.promoLabel
      : null;

  String get _category =>
      store.categories.isEmpty ? 'อาหาร' : store.categories.first;

  /// No-break spaces keep "20–30 นาที" and "1.9 กม." on one line.
  String? get _eta => _pickup
      ? null
      : ZokyRecommendedStoreCard.etaLabel(store)?.replaceAll(' ', '\u00A0');

  /// [store]'s distance when it is a real one (finite, not negative);
  /// odd values are hidden rather than shown as "Infinity" (ZOKY-131).
  static double? shownDistanceKm(ZokyStoreSummary store) {
    final km = store.distanceKm;
    return km != null && km.isFinite && km >= 0 ? km : null;
  }

  String? get _distance {
    final km = shownDistanceKm(store);
    return km == null ? null : '${km.toStringAsFixed(1)}\u00A0กม.';
  }

  /// Screen reader label (one node for the row).
  String semanticLabel() {
    final parts = <String>[
      if (store.isDemo) ZokyStrings.demoStorePrefix,
      'ร้าน${store.isDemo ? store.nameWithoutDemoSuffix : store.name}',
      _category,
    ];
    final rating = store.rating;
    if (rating != null) {
      parts.add('คะแนน ${rating.toStringAsFixed(1)}');
    } else if (store.isNew) {
      parts.add(ZokyStrings.newStore);
    }
    final eta = _eta;
    if (eta != null) parts.add('ส่งประมาณ $eta');
    final distance = _distance;
    if (distance != null) parts.add('ระยะ $distance');
    if (!store.isOpen) parts.add('ร้านปิดอยู่');
    final promo = _promo;
    if (promo != null) parts.add('โปรโมชัน $promo');
    if (store.isAd) parts.add(ZokyStrings.adLabel);
    if (_pickup && store.supportsPickup) parts.add(ZokyStrings.pickupAvailable);
    parts.add(ZokyStrings.viewMenu);
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final photo = photoSize(MediaQuery.sizeOf(context).width);
    final meta = ZokyTextStyles.bodyMd.copyWith(
      color: ZokyColors.textSecondary,
      height: 1.35,
    );
    final rating = store.rating;
    final eta = _eta;
    final distance = _distance;
    final promo = _promo;
    final labels = <Widget>[
      if (!store.isOpen)
        _Label(
          glyph: ZokyLineGlyph.clock,
          text: ZokyStrings.closedLabel,
          background: ZokyColors.neutral900.withValues(alpha: 0.8),
          foreground: ZokyColors.neutral0,
        ),
      if (_pickup && store.supportsPickup)
        const _Label(
          text: ZokyStrings.pickupAvailable,
          background: ZokyColors.successContainer,
          foreground: ZokyColors.success,
        ),
      if (promo != null)
        _Label(
          text: promo,
          background: ZokyColors.brandDeep,
          foreground: ZokyColors.onAction,
        ),
      if (store.isAd)
        _Label(
          text: ZokyStrings.adLabel,
          background: ZokyColors.neutral900.withValues(alpha: 0.72),
          foreground: ZokyColors.neutral0,
        ),
    ];
    return Semantics(
      button: true,
      label: semanticLabel(),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: ZokyRadius.lg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ZokySpacing.gutter,
            vertical: ZokySpacing.s4,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: photo,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ZokyStoreCover(
                      store: store,
                      borderRadius: ZokyRadius.lg,
                      fallbackArt: fallbackArt,
                    ),
                    if (store.isDemo)
                      Positioned(
                        left: ZokySpacing.s3,
                        top: ZokySpacing.s3,
                        right: ZokySpacing.s3,
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.3,
                          child: const Align(
                            alignment: Alignment.topLeft,
                            // One line, never cut: scales down to fit.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topLeft,
                              child: ZokyDemoBadge(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: ZokySpacing.s7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      store.isDemo ? store.nameWithoutDemoSuffix : store.name,
                      style: ZokyTextStyles.weight(
                        ZokyTextStyles.bodyLg.copyWith(
                          fontSize: 18,
                          height: 1.3,
                        ),
                        FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: ZokySpacing.s1),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: _category),
                          if (rating != null) ...[
                            const TextSpan(text: ' · '),
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              // Glossy 3D star, as on Home's store cards.
                              child: Zoky3DIcon(
                                Zoky3DGlyph.star,
                                size: 16,
                                palette: Zoky3DPalette.gold,
                              ),
                            ),
                            TextSpan(text: ' ${rating.toStringAsFixed(1)}'),
                          ] else if (store.isNew)
                            const TextSpan(text: ' · ${ZokyStrings.newStore}'),
                          if (eta != null) TextSpan(text: ' · $eta'),
                          if (distance != null) TextSpan(text: ' · $distance'),
                        ],
                      ),
                      style: meta,
                    ),
                    if (labels.isNotEmpty) ...[
                      const SizedBox(height: ZokySpacing.s3),
                      Wrap(
                        spacing: ZokySpacing.s2,
                        runSpacing: ZokySpacing.s2,
                        children: labels,
                      ),
                    ],
                    const SizedBox(height: ZokySpacing.s3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            ZokyStrings.viewMenu,
                            style: ZokyTextStyles.labelLg.copyWith(
                              color: ZokyColors.brandDeep,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: ZokySpacing.s2),
                        // Glossy 3D arrow (Home hero CTA family).
                        const Zoky3DIcon(Zoky3DGlyph.arrowRight, size: 22),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Short store label. Wraps rather than ellipsizing (ZOKY-127).
class _Label extends StatelessWidget {
  const _Label({
    required this.text,
    required this.background,
    required this.foreground,
    this.glyph,
  });

  final String text;
  final Color background;
  final Color foreground;
  final ZokyLineGlyph? glyph;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: ZokyRadius.full,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph case final glyph?) ...[
              ZokyLineIcon(glyph, size: 13, color: foreground),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                text,
                style: ZokyTextStyles.weight(
                  ZokyTextStyles.labelSm.copyWith(color: foreground),
                  FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
