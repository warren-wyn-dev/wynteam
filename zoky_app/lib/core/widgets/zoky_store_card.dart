import 'package:flutter/material.dart';

import '../../features/catalog/domain/catalog_models.dart';
import '../adaptive/zoky_icons.dart';
import '../design/zoky_colors.dart';
import '../design/zoky_tokens.dart';
import '../design/zoky_typography.dart';
import '../format/money.dart';
import '../l10n/zoky_strings.dart';

/// Store card (design 9.4, web `StoreCard` / `fx-store-card`).
///
/// 4:3 photo with overlays (ad, closed, promo, ETA), name (max 2 lines),
/// rating/distance meta and tags. Read by screen readers as one node.
class ZokyStoreCard extends StatelessWidget {
  const ZokyStoreCard({super.key, required this.store, required this.onTap});

  final ZokyStoreSummary store;
  final VoidCallback onTap;

  String _semanticLabel() {
    final parts = <String>['ร้าน${store.name}'];
    parts.add(
      store.isNew
          ? ZokyStrings.newStore
          : 'คะแนน ${store.ratingAverage.toStringAsFixed(1)}',
    );
    parts.add(
      'ส่งประมาณ ${store.etaMinMinutes} ถึง ${store.etaMaxMinutes} ${ZokyStrings.minutes}',
    );
    if (!store.isOpen) parts.add('ร้านปิดอยู่');
    if (store.hasPromo) parts.add('โปรโมชัน ${store.promoLabel}');
    if (store.isAd) parts.add(ZokyStrings.adLabel);
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
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
              store.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ZokyTextStyles.weight(
                ZokyTextStyles.bodyMd,
                FontWeight.w700,
              ),
            ),
            const SizedBox(height: ZokySpacing.s1),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: ZokySpacing.s2,
              children: [
                const Icon(ZokyIcons.star, size: 14, color: ZokyColors.rating),
                Text(
                  store.isNew
                      ? ZokyStrings.newStore
                      : store.ratingAverage.toStringAsFixed(1),
                  style: ZokyTextStyles.weight(
                    ZokyTextStyles.bodySm.copyWith(
                      color: ZokyColors.textPrimary,
                    ),
                    FontWeight.w700,
                  ),
                ),
                if (!store.isNew && store.ratingCount > 0)
                  Text('(${store.ratingCount})', style: ZokyTextStyles.bodySm),
                if (store.distanceKm != null)
                  Text(
                    '· ${store.distanceKm!.toStringAsFixed(1)} กม.',
                    style: ZokyTextStyles.bodySm,
                  ),
              ],
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
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: ZokyRadius.lg,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Each overlay may use at most half the photo width so they
            // never collide (design: overlays clamp to 1.3x text scale).
            final half = constraints.maxWidth / 2 - ZokySpacing.s6;
            return MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _cover(),
                  if (store.isAd)
                    Positioned(
                      left: ZokySpacing.s4,
                      top: ZokySpacing.s4,
                      child: _Overlay(
                        maxWidth: half,
                        label: ZokyStrings.adLabel,
                        background: ZokyColors.neutral900.withValues(
                          alpha: 0.72,
                        ),
                        foreground: ZokyColors.neutral0,
                      ),
                    ),
                  if (!store.isOpen)
                    Positioned(
                      right: ZokySpacing.s4,
                      top: ZokySpacing.s4,
                      child: _Overlay(
                        maxWidth: half,
                        icon: ZokyIcons.clock,
                        label: ZokyStrings.closedLabel,
                        background: ZokyColors.neutral900.withValues(
                          alpha: 0.8,
                        ),
                        foreground: ZokyColors.neutral0,
                      ),
                    ),
                  if (store.hasPromo)
                    Positioned(
                      left: 0,
                      bottom: ZokySpacing.s4,
                      child: _Overlay(
                        maxWidth: half,
                        label: store.promoLabel!,
                        background: ZokyColors.brandDeep,
                        foreground: ZokyColors.onAction,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(ZokyRadius.fullValue),
                        ),
                      ),
                    ),
                  Positioned(
                    right: ZokySpacing.s4,
                    bottom: ZokySpacing.s4,
                    child: _Overlay(
                      maxWidth: half,
                      label:
                          '${store.etaMinMinutes}–${store.etaMaxMinutes} ${ZokyStrings.minutes}',
                      background: ZokyColors.surface,
                      foreground: ZokyColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          },
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
    required this.maxWidth,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.borderRadius = ZokyRadius.full,
  });

  final double maxWidth;
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth.clamp(0, double.infinity)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: borderRadius,
        ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZokyTextStyles.weight(
                    ZokyTextStyles.caption.copyWith(color: foreground),
                    FontWeight.w700,
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
