import 'package:flutter/material.dart';

import '../../data/club.dart';
import '../../data/club_member.dart';
import 'club_join_button.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/network_thumbnail.dart';

/// A cover-image-led Club card for ExploreClubsScreen's "Club
/// แนะนำสำหรับคุณ" row -- richer than the icon-only ClubMiniCard used on
/// Home (WYN-014), since this screen's whole purpose is browsing/
/// comparing Clubs visually. Opaque throughout, no elevation/shadow
/// (DS-005's "card-less" rule means no Material `Card` elevation, not
/// "no image") -- the only shadow used is the Join button's own glow
/// when active. See
/// .wyn/docs/design/wyn-056-club-discovery-visual-refresh.md, Screen 2.
class ClubRecommendedCard extends StatelessWidget {
  const ClubRecommendedCard({
    super.key,
    required this.club,
    required this.status,
    required this.isJoinInFlight,
    required this.onTap,
    required this.onJoinTapped,
    required this.onReport,
  });

  final Club club;
  final ClubMemberStatus? status;
  final bool isJoinInFlight;
  final VoidCallback onTap;
  final VoidCallback onJoinTapped;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '${club.name}'
          '${club.category != null ? ', หมวดหมู่ ${club.category}' : ''}'
          ', มีสมาชิก ${club.memberCount} คน',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
        child: Container(
          width: 168,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(WynSpacing.radiusMd),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      // Beta4 §8.1 -- one image per Club.
                      child: club.identityImageUrl != null
                          ? NetworkThumbnail(imageUrl: club.identityImageUrl!)
                          : Container(
                              color: scheme.primaryContainer,
                              alignment: Alignment.center,
                              child: Text(
                                club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: _MoreMenuButton(onReport: onReport),
                  ),
                  // Beta4 §8.1: the small avatar disc that used to
                  // overlap the bottom-left of the hero is gone. It
                  // read `icon_url` while the hero read `cover_url`,
                  // so the card was built to show a Club's *two*
                  // images -- one of which nothing in the product
                  // could ever set, meaning in practice every card
                  // showed a photo with a grey initial-disc stuck to
                  // its corner. With one identity image the disc
                  // would now be a shrunken duplicate of the picture
                  // directly behind it.
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  WynSpacing.space3,
                  // Was `space3 + 8`, the extra 8 reserving room for
                  // the removed disc's overhang.
                  WynSpacing.space3,
                  WynSpacing.space3,
                  WynSpacing.space2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (club.category != null) ...[
                          Flexible(
                            child: Text(
                              club.category!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('·', style: TextStyle(color: scheme.onSurfaceVariant)),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          '${club.memberCount} สมาชิก',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: WynSpacing.space2),
                    ClubJoinButton(
                      status: status,
                      isInFlight: isJoinInFlight,
                      onTapped: onJoinTapped,
                      expand: true,
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

class _MoreMenuButton extends StatelessWidget {
  const _MoreMenuButton({required this.onReport});

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: WynColors.imageScrim,
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, size: 16, color: Colors.white),
        tooltip: 'เพิ่มเติม',
        onSelected: (_) => onReport(),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'report', child: Text('รายงาน Club')),
        ],
      ),
    );
  }
}

