import 'package:flutter/material.dart';

import '../../features/catalog/domain/catalog_models.dart';
import '../../features/deals/widgets/zoky_deal_card.dart' show ZokyDemoBadge;
import '../../features/home/widgets/zoky_recommended_store_card.dart'
    show ZokyRecommendedStoreCard;
import '../adaptive/zoky_icons.dart';
import '../design/zoky_colors.dart';
import '../design/zoky_tokens.dart';
import '../design/zoky_typography.dart';
import '../format/money.dart';
import '../l10n/zoky_strings.dart';

/// Store card (design 9.4, web `StoreCard` / `fx-store-card`).
///
/// 1:1 photo (Founder decision 2026-10-17: every food photo is square,
/// ZOKY-125) with short badges (demo, ad, closed, promo), name (max 2
/// lines), "rating | time | distance" meta (as on the Home recommended card)
/// and tags. Badge labels wrap instead of being ellipsized (ZOKY-127): the ad
/// disclosure, promo value and closed state must always be readable. Read by
/// screen readers as one node.
class ZokyStoreCard extends StatelessWidget {
  const ZokyStoreCard({super.key, required this.store, required this.onTap});

  final ZokyStoreSummary store;
  final VoidCallback onTap;

  String _semanticLabel() {
    final parts = <String>['ร้าน${store.name}'];
    // Same rule as the Home card: a score only with real reviews (ZOKY-121).
    final rating = store.rating;
    if (rating != null) {
      parts.add('คะแนน ${rating.toStringAsFixed(1)}');
    } else if (store.isNew) {
      parts.add(ZokyStrings.newStore);
    }
    if (store.hasEta) {
      parts.add(
        'ส่งประมาณ ${store.etaMinMinutes} ถึง ${store.etaMaxMinutes} ${ZokyStrings.minutes}',
      );
    }
    if (!store.isOpen) parts.add('ร้านปิดอยู่');
    if (store.hasPromo) parts.add('โปรโมชัน ${store.promoLabel}');
    if (store.isAd) parts.add(ZokyStrings.adLabel);
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final rating = store.rating;
    final eta = ZokyRecommendedStoreCard.etaLabel(store);
    final strong = ZokyTextStyles.weight(
      ZokyTextStyles.bodySm.copyWith(color: ZokyColors.textPrimary),
      FontWeight.w700,
    );
    // ETA lives here, not on the photo, so it is never cut (ZOKY-127).
    // Groups wrap on narrow cards (and the rating group wraps inside). Each
    // group has a leading thin rule that is clipped away at the start of a
    // line, so rules only show between groups on one line (never dangling).
    final meta = <List<Widget>>[
      if (rating != null)
        [
          const Icon(ZokyIcons.star, size: 14, color: ZokyColors.rating),
          Text(rating.toStringAsFixed(1), style: strong),
          Text('(${store.ratingCount})', style: ZokyTextStyles.bodySm),
        ]
      else if (store.isNew)
        [Text(ZokyStrings.newStore, style: strong)],
      if (eta != null) [Text(eta, style: ZokyTextStyles.bodySm)],
      if (store.distanceKm != null)
        [
          Text(
            '${store.distanceKm!.toStringAsFixed(1)} กม.',
            style: ZokyTextStyles.bodySm,
          ),
        ],
    ];
    final categories = store.categories.isEmpty
        ? const ['อาหาร']
        : store.categories.take(2);
    return Semantics(
      button: true,
      label: _semanticLabel(),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: ZokyRadius.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Photo(store: store),
            const SizedBox(height: ZokySpacing.s4),
            Text(
              // Sample stores carry the separate "ตัวอย่าง" badge on the
              // photo instead of the name suffix, which could be ellipsized
              // away (ZOKY-123, same as the Home recommended card).
              store.isDemo ? store.nameWithoutDemoSuffix : store.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ZokyTextStyles.weight(
                ZokyTextStyles.bodyMd,
                FontWeight.w700,
              ),
            ),
            const SizedBox(height: ZokySpacing.s1),
            if (meta.isNotEmpty)
              ClipRect(
                clipper: const _ClipLeftEdge(),
                child: Transform.translate(
                  offset: const Offset(-_MetaItem.lead, 0),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: ZokySpacing.s1,
                    children: [
                      for (final group in meta)
                        _MetaItem(
                          child: group.length == 1
                              ? group.single
                              : Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: ZokySpacing.s2,
                                  children: group,
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: ZokySpacing.s2),
            Wrap(
              spacing: ZokySpacing.s2,
              runSpacing: ZokySpacing.s2,
              children: [
                for (final name in categories) _Tag(name),
                _Tag(
                  '${ZokyStrings.deliveryFee} ${formatBaht(store.deliveryFee)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.store});

  final ZokyStoreSummary store;

  @override
  Widget build(BuildContext context) {
    final hasTop = store.isDemo || store.isAd || !store.isOpen;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: ZokyRadius.lg,
        // Overlays clamp to 1.3x text scale (design).
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _cover(),
              if (hasTop)
                Positioned(
                  left: ZokySpacing.s4,
                  top: ZokySpacing.s4,
                  right: ZokySpacing.s4,
                  // Demo/ad on the left, closed on the right when both fit;
                  // otherwise closed moves below, so nothing overlaps and
                  // every badge may use the whole photo width (ZOKY-127).
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: ZokySpacing.s2,
                    runSpacing: ZokySpacing.s2,
                    children: [
                      if (store.isDemo || store.isAd)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (store.isDemo)
                              // One line, never cut: scales down to fit.
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: ZokyDemoBadge(),
                              ),
                            if (store.isDemo && store.isAd)
                              const SizedBox(height: ZokySpacing.s2),
                            if (store.isAd)
                              _Overlay(
                                label: ZokyStrings.adLabel,
                                background: ZokyColors.neutral900.withValues(
                                  alpha: 0.72,
                                ),
                                foreground: ZokyColors.neutral0,
                              ),
                          ],
                        ),
                      if (!store.isOpen)
                        _Overlay(
                          icon: ZokyIcons.clock,
                          label: ZokyStrings.closedLabel,
                          background: ZokyColors.neutral900.withValues(
                            alpha: 0.8,
                          ),
                          foreground: ZokyColors.neutral0,
                        ),
                    ],
                  ),
                ),
              if (store.hasPromo)
                Positioned(
                  left: 0,
                  right: ZokySpacing.s4,
                  bottom: ZokySpacing.s4,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: _Overlay(
                      label: store.promoLabel!,
                      background: ZokyColors.brandDeep,
                      foreground: ZokyColors.onAction,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(ZokyRadius.fullValue),
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

  Widget _cover() {
    final url = store.coverUrl;
    final placeholder = Container(
      color: ZokyColors.sunken,
      alignment: Alignment.center,
      child: const Icon(ZokyIcons.food, size: 30, color: ZokyColors.neutral400),
    );
    if (url == null) return placeholder;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.borderRadius = ZokyRadius.full,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    // Width comes from the parent (up to the whole photo row); the label
    // wraps rather than being ellipsized (ZOKY-127).
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: borderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: foreground),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                style: ZokyTextStyles.weight(
                  ZokyTextStyles.caption.copyWith(color: foreground),
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

/// Meta group with its leading thin rule (as on the Home card). [child]
/// still wraps inside the card width.
class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.child});

  final Widget child;

  /// Gap, rule, gap: hidden at the start of each line.
  static const double lead = 2 * ZokySpacing.s3 + 1;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: lead,
          child: Center(
            child: SizedBox(
              width: 1,
              height: 14,
              child: ColoredBox(color: ZokyColors.borderDefault),
            ),
          ),
        ),
        Flexible(child: child),
      ],
    );
  }
}

/// Clips only what lies left of the box (the hidden line-start rules), so
/// Thai marks above/below a line are never cut.
class _ClipLeftEdge extends CustomClipper<Rect> {
  const _ClipLeftEdge();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -size.height, size.width * 2, size.height * 2);

  @override
  bool shouldReclip(_ClipLeftEdge oldClipper) => false;
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ZokyColors.chip,
        borderRadius: ZokyRadius.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ZokyTextStyles.bodySm.copyWith(fontSize: 12),
        ),
      ),
    );
  }
}
