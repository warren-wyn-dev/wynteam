import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/design/wyn_typography.dart';
import '../../data/discovery_ranking.dart';

/// One row of `03-search.tsx`'s Top 100 ranked hashtag list -- shared by
/// [DiscoveryView]'s preview and [Top100Screen]'s full list so the same
/// row never drifts out of sync between the two. Right-aligned title-style
/// rank numeral, bold `#tag`, meta line, hairline divider (all but the
/// last row).
///
/// WYN-101 (Wynos V1.0.0 Beta2, item 10, 2026-09-02): the meta line no
/// longer shows a post count ("N โพสต์") -- Founder: "ปล. ใต้แฮชแท็ก
/// ห้ามระบุว่ากี่โพสต์". This reverses the 2026-08-29 design-reference
/// re-brand decision that had added the count in the first place (see
/// .wyn/company/DECISIONS.md, 2026-09-02) -- a 2nd reversal, not a
/// conflict to resolve.
class HashtagRankRow extends StatelessWidget {
  const HashtagRankRow({
    super.key,
    required this.rank,
    required this.item,
    required this.showDivider,
    required this.onTap,
  });

  final int rank;
  final RankedHashtag item;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'อันดับที่ $rank #${item.tag} กดเพื่อดูโพสต์ที่มีแฮชแท็กนี้',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: showDivider
              ? const BoxDecoration(
                  border: Border(bottom: BorderSide(color: WynColors.hairline)),
                )
              : null,
          padding: const EdgeInsets.symmetric(
              horizontal: WynSpacing.space4, vertical: WynSpacing.space3),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.right,
                  style: WynTypography.screenTitle(
                      fontSize: 16, fontWeight: FontWeight.w500, color: WynColors.faint),
                ),
              ),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${item.tag}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: WynColors.ink),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'กำลังนิยมใน ไทย',
                      style: TextStyle(fontSize: 13, color: WynColors.graphite),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, size: 16, color: WynColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
