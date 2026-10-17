import 'package:flutter/material.dart';

import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_skeleton.dart';
import '../../deals/data/promotion_repository.dart';
import '../../deals/domain/deal_models.dart';
import '../../deals/widgets/zoky_deal_card.dart';
import 'zoky_home_section_header.dart';

/// Home Phase 3 (Founder mockup "เฟส 3 ดีลเด็ดวันนี้"): section heading,
/// "ดูทั้งหมด >" and a horizontally scrolling row of [ZokyDealCard]s; the
/// next card peeks in at the right edge.
///
/// Loads from [repository]. While loading it shows skeleton cards; when
/// there are no deals or the load fails the whole section is hidden (deals
/// are optional on Home, like the web's deal row). Sample data is called
/// out under the heading and on every card.
class ZokyTodayDealsSection extends StatefulWidget {
  const ZokyTodayDealsSection({
    super.key,
    required this.repository,
    required this.onOpenDeal,
    required this.onSeeAll,
  });

  final PromotionRepository repository;
  final ValueChanged<ZokyDeal> onOpenDeal;
  final VoidCallback onSeeAll;

  /// Key of the horizontal scroll view (tests).
  static const Key rowKey = ValueKey('zoky-deals-row');

  @override
  State<ZokyTodayDealsSection> createState() => _ZokyTodayDealsSectionState();
}

class _ZokyTodayDealsSectionState extends State<ZokyTodayDealsSection> {
  List<ZokyDeal>? _deals;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final deals = await widget.repository.fetchTodayDeals();
      if (!mounted) return;
      setState(() => _deals = deals);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deals = _deals;
    if (_failed || (deals != null && deals.isEmpty)) {
      return const SizedBox.shrink();
    }
    final cardWidth = ZokyDealCard.rowWidth(MediaQuery.sizeOf(context).width);
    final showDemoNote = deals == null || deals.any((d) => d.isDemo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZokyHomeSectionHeader(
          title: ZokyStrings.dealsTitle,
          seeAllLabel: ZokyStrings.seeAllDeals,
          onSeeAll: widget.onSeeAll,
        ),
        if (showDemoNote)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZokySpacing.gutter),
            child: Text(
              ZokyStrings.dealsDemoNote,
              style: ZokyTextStyles.bodySm,
            ),
          ),
        SingleChildScrollView(
          key: ZokyTodayDealsSection.rowKey,
          scrollDirection: Axis.horizontal,
          // Room for the cards' soft shadow inside the clip.
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
                if (deals == null)
                  for (var i = 0; i < 2; i++) ...[
                    if (i > 0) const SizedBox(width: ZokySpacing.s6),
                    ZokySkeleton(
                      width: cardWidth,
                      height: ZokyDealCard.minHeight,
                      borderRadius: ZokyDealCard.radius,
                    ),
                  ]
                else
                  for (final (i, deal) in deals.indexed) ...[
                    if (i > 0) const SizedBox(width: ZokySpacing.s6),
                    ZokyDealCard(
                      deal: deal,
                      width: cardWidth,
                      tint: ZokyDealTint.forIndex(i),
                      onTap: () => widget.onOpenDeal(deal),
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
