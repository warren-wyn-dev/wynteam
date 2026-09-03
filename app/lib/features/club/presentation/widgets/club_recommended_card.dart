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
                      child: club.coverUrl != null
                          ? NetworkThumbnail(imageUrl: club.coverUrl!)
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
                  Positioned(
                    left: 8,
                    bottom: -16,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: scheme.surfaceContainer,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: scheme.primary,
                        backgroundImage:
                            club.iconUrl != null ? NetworkImage(club.iconUrl!) : null,
                        child: club.iconUrl == null
                            ? Text(
                                club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  WynSpacing.space3,
                  WynSpacing.space3 + 8,
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

