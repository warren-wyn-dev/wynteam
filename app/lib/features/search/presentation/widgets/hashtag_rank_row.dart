import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/design/wyn_typography.dart';
import '../../data/discovery_ranking.dart';

/// One row of `03-search.tsx`'s Top 100 ranked hashtag list -- shared by
/// [DiscoveryView]'s preview and [Top100Screen]'s full list so the same
/// row never drifts out of sync between the two. Right-aligned Fraunces
/// rank numeral, bold `#tag`, "N โพสต์" meta, hairline divider (all but
/// the last row).
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
      label: 'อันดับที่ $rank #${item.tag} ${item.postCount} โพสต์ '
          'กดเพื่อดูโพสต์ที่มีแฮชแท็กนี้',
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
                  style: WynTypography.fraunces(
                      fontSize: 17, fontWeight: FontWeight.w500, color: WynColors.faint),
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
                      style: GoogleFonts.inter(
                          fontSize: 14.5, fontWeight: FontWeight.w700, color: WynColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.postCount} โพสต์ · กำลังนิยมใน ไทย',
                      style: GoogleFonts.inter(fontSize: 12, color: WynColors.graphite),
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
