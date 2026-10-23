import 'package:flutter/material.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_3d_icon.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../deals/widgets/zoky_deal_card.dart';
import 'zoky_store_cover.dart';

/// Store card of the Home "ร้านอาหารแนะนำ" row (Founder mockup Phase 4):
/// white card, 1:1 cover photo with rounded corners on top, the store
/// name, then "★ 4.8 | 30–45 นาที". No heart on the photo (Founder,
/// 2026-10-17): favorites stay on the header heart.
///
/// Rating and delivery time are drawn only when the model has them
/// ([ZokyStoreSummary.rating], [ZokyStoreSummary.hasEta]); a sample store
/// carries the "ตัวอย่าง" badge. The card is one button for assistive tech
/// ([semanticLabel]).
class ZokyRecommendedStoreCard extends StatelessWidget {
  const ZokyRecommendedStoreCard({
    super.key,
    required this.store,
    required this.width,
    required this.onTap,
  });

  final ZokyStoreSummary store;
  final double width;
  final VoidCallback onTap;

  static const BorderRadius radius = ZokyRadius.lg;

  /// Gap between the card edge and the photo.
  static const double photoInset = ZokySpacing.s2;
  static const BorderRadius photoRadius = BorderRadius.all(
    Radius.circular(ZokyRadius.lgValue - photoInset),
  );

  /// Food photos are 1:1 everywhere (Founder, 2026-10-17): the same square
  /// upload the web uses for store and menu photos fits without cropping.
  static const double photoAspectRatio = 1;

  /// Inset of the demo badge from the photo's top-left corner.
  static const double _badgeGap = ZokySpacing.s3;

  /// Same soft pink shadow as the Phase 3 deal cards.
  static const List<BoxShadow> shadow = ZokyDealCard.shadow;

  /// Row card width: ~40% of the screen so two cards show and the third
  /// peeks in (mockup), clamped for very small and large phones.
  static double rowWidth(double viewportWidth) =>
      (viewportWidth * 0.40).clamp(148.0, 184.0);

  /// "30–45 นาที" (or "30 นาที" when both ends match); null without ETA.
  static String? etaLabel(ZokyStoreSummary store) {
    if (!store.hasEta) return null;
    final min = store.etaMinMinutes!;
    final max = store.etaMaxMinutes!;
    return min == max
        ? '$min ${ZokyStrings.minutes}'
        : '$min–$max ${ZokyStrings.minutes}';
  }

  /// Accessible name, e.g. "ร้านตัวอย่าง ราเมงซอยเจ็ด คะแนน 4.8 ส่งใน 30
  /// ถึง 45 นาที". Only facts the card shows are read.
  static String semanticLabel(ZokyStoreSummary store) {
    final parts = <String>[
      store.isDemo
          ? '${ZokyStrings.demoStorePrefix} ${store.nameWithoutDemoSuffix}'
          : store.name,
    ];
    final rating = store.rating;
    if (rating != null) parts.add('คะแนน ${rating.toStringAsFixed(1)}');
    if (store.hasEta) {
      final min = store.etaMinMinutes!;
      final max = store.etaMaxMinutes!;
      parts.add(
        min == max
            ? 'ส่งใน $min ${ZokyStrings.minutes}'
            : 'ส่งใน $min ถึง $max ${ZokyStrings.minutes}',
      );
    }
    if (!store.isOpen) parts.add(ZokyStrings.closedLabel);
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: semanticLabel(store),
        onTap: onTap,
        excludeSemantics: true,
        // Shadow outside the Material so the ink clip does not cut it.
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: radius,
            boxShadow: shadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Ink(
              decoration: const BoxDecoration(
                borderRadius: radius,
                color: ZokyColors.surface,
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: Padding(
                  padding: const EdgeInsets.all(photoInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [_photo(), _details()],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photo() {
    return AspectRatio(
      aspectRatio: photoAspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ZokyStoreCover(store: store, borderRadius: photoRadius),
          if (store.isDemo)
            Positioned(
              left: _badgeGap,
              top: _badgeGap,
              // Badge stays one line within the photo.
              right: _badgeGap,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: const Align(
                  alignment: Alignment.topLeft,
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
    );
  }

  Widget _details() {
    final rating = store.rating;
    final eta = etaLabel(store);
    final metaStyle = ZokyTextStyles.bodySm.copyWith(
      color: ZokyColors.textSecondary,
    );
    final meta = <Widget>[
      if (!store.isOpen)
        Text(
          ZokyStrings.closedLabel,
          style: ZokyTextStyles.weight(metaStyle, FontWeight.w700),
        ),
      if (rating != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Zoky3DIcon(
              Zoky3DGlyph.star,
              size: 16,
              palette: Zoky3DPalette.gold,
            ),
            const SizedBox(width: ZokySpacing.s2),
            Text(
              rating.toStringAsFixed(1),
              style: ZokyTextStyles.weight(
                ZokyTextStyles.bodySm.copyWith(color: ZokyColors.textPrimary),
                FontWeight.w700,
              ),
            ),
          ],
        ),
      if (eta != null) Text(eta, style: metaStyle),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZokySpacing.s3,
        ZokySpacing.s5,
        ZokySpacing.s3,
        ZokySpacing.s3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            store.isDemo ? store.nameWithoutDemoSuffix : store.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ZokyTextStyles.weight(
              ZokyTextStyles.bodyMd.copyWith(
                color: ZokyColors.textPrimary,
                height: 1.3,
              ),
              FontWeight.w700,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: ZokySpacing.s3),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: ZokySpacing.s4,
              runSpacing: ZokySpacing.s2,
              children: [
                for (final (i, item) in meta.indexed) ...[
                  if (i > 0) const _MetaDivider(),
                  item,
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Thin vertical rule between rating and time (mockup).
class _MetaDivider extends StatelessWidget {
  const _MetaDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: 14,
      child: ColoredBox(color: ZokyColors.borderDefault),
    );
  }
}
