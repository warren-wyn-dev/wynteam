import 'package:flutter/material.dart';

import '../../data/club.dart';
import '../../data/club_member.dart';
import 'club_join_button.dart';
import '../../../../core/design/wyn_spacing.dart';

/// A ranked row (1-5) for ExploreClubsScreen's "กำลังนิยม" row --
/// reuses the same `fetchPopularClubs` result already sorted by member
/// count, just takes the top few and renders them as a ranked list
/// instead of a grid. Trend is communicated with a plain cyan
/// `trending_up` icon, not a Rainbow gradient -- DS-009 caps Rainbow at
/// 2 named usage sites and this isn't one of them. See
/// .wyn/docs/design/wyn-056-club-discovery-visual-refresh.md, Screen 3.
class ClubRankedRow extends StatelessWidget {
  const ClubRankedRow({
    super.key,
    required this.rank,
    required this.club,
    required this.status,
    required this.isJoinInFlight,
    required this.onTap,
    required this.onJoinTapped,
  });

  final int rank;
  final Club club;
  final ClubMemberStatus? status;
  final bool isJoinInFlight;
  final VoidCallback onTap;
  final VoidCallback onJoinTapped;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isTopThree = rank <= 3;

    return Semantics(
      label: 'อันดับ $rank ${club.name}'
          '${club.category != null ? ', หมวดหมู่ ${club.category}' : ''}'
          ', มีสมาชิก ${club.memberCount} คน',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
        child: SizedBox(
          width: 230,
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isTopThree ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(width: WynSpacing.space2),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.primary,
                  backgroundImage: club.iconUrl != null ? NetworkImage(club.iconUrl!) : null,
                  child: club.iconUrl == null
                      ? Text(
                          club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                          style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: WynSpacing.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        club.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.trending_up, size: 14, color: scheme.primary),
                          const SizedBox(width: 2),
                          Text(
                            '${club.memberCount} สมาชิก',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: WynSpacing.space2),
                ClubJoinButton(
                  status: status,
                  isInFlight: isJoinInFlight,
                  onTapped: onJoinTapped,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
