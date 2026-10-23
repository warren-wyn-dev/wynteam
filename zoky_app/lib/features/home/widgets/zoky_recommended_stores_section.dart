import 'package:flutter/material.dart';

import '../../../core/design/zoky_tokens.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_skeleton.dart';
import '../../catalog/data/store_repository.dart';
import '../../catalog/domain/catalog_models.dart';
import 'zoky_home_section_header.dart';
import 'zoky_recommended_store_card.dart';

/// Home Phase 4 (Founder mockup "เฟส 4 ร้านอาหารแนะนำ"): section heading,
/// "ดูทั้งหมด >" and one horizontally scrolling row of
/// [ZokyRecommendedStoreCard]s; the next card peeks in at the right edge.
///
/// Stores come from [StoreRepository.fetchRecommended] (web: featured
/// placements in priority order). Loading shows skeleton cards; when
/// nothing is featured or the load fails the section is hidden, like the
/// web's "ร้านแนะนำ" section.
class ZokyRecommendedStoresSection extends StatefulWidget {
  const ZokyRecommendedStoresSection({
    super.key,
    required this.repository,
    required this.onOpenStore,
    required this.onSeeAll,
  });

  final StoreRepository repository;
  final ValueChanged<ZokyStoreSummary> onOpenStore;
  final VoidCallback onSeeAll;

  /// Key of the horizontal scroll view (tests).
  static const Key rowKey = ValueKey('zoky-recommended-row');

  @override
  State<ZokyRecommendedStoresSection> createState() =>
      _ZokyRecommendedStoresSectionState();
}

class _ZokyRecommendedStoresSectionState
    extends State<ZokyRecommendedStoresSection> {
  List<ZokyStoreSummary>? _stores;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stores = await widget.repository.fetchRecommended();
      if (!mounted) return;
      setState(() => _stores = stores);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stores = _stores;
    if (_failed || (stores != null && stores.isEmpty)) {
      return const SizedBox.shrink();
    }
    final cardWidth = ZokyRecommendedStoreCard.rowWidth(
      MediaQuery.sizeOf(context).width,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZokyHomeSectionHeader(
          title: ZokyStrings.recommendedTitle,
          seeAllLabel: ZokyStrings.seeAllRecommended,
          onSeeAll: widget.onSeeAll,
        ),
        SingleChildScrollView(
          key: ZokyRecommendedStoresSection.rowKey,
          scrollDirection: Axis.horizontal,
          // Same rhythm as Phase 3; room for the cards' soft shadow.
          padding: const EdgeInsets.fromLTRB(
            ZokySpacing.gutter,
            ZokySpacing.s5,
            ZokySpacing.gutter,
            ZokySpacing.s10,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stores == null)
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: ZokySpacing.s6),
                    ZokySkeleton(
                      width: cardWidth,
                      height:
                          cardWidth /
                              ZokyRecommendedStoreCard.photoAspectRatio +
                          64,
                      borderRadius: ZokyRecommendedStoreCard.radius,
                    ),
                  ]
                else
                  for (final (i, store) in stores.indexed) ...[
                    if (i > 0) const SizedBox(width: ZokySpacing.s6),
                    ZokyRecommendedStoreCard(
                      store: store,
                      width: cardWidth,
                      onTap: () => widget.onOpenStore(store),
                    ),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
