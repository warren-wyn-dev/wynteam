import 'package:flutter/material.dart';

import '../../data/club.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/network_thumbnail.dart';
import 'club_avatar.dart';

/// Which visual shape [ClubDiscoveryCard] renders as -- [row] (the
/// original, full-width) or [grid] (WYN-056, vertical/image-led, for
/// ExploreClubsScreen's 2-column grid). Same widget, same tap/Semantics
/// contract either way -- callers just pick the layout that fits their
/// container.
enum ClubDiscoveryCardLayout { row, grid }

/// A Club card/row -- icon or cover image + name + category chip +
/// member count (+ description in [ClubDiscoveryCardLayout.row]).
/// [ClubDiscoveryCardLayout.row] mirrors FollowListScreen/
/// ClubMembersTab's row shape (avatar/icon left, info right) and is
/// still what the Club tab in Search (WYN-015 Screen 2) uses --
/// [ClubDiscoveryCardLayout.grid] is WYN-056's vertical, cover-image-led
/// variant used by ExploreClubsScreen's "กำลังนิยม"/"ใหม่ล่าสุด" grid.
/// See .wyn/docs/design/wyn-015-club-discovery-integration.md and
/// .wyn/docs/design/wyn-056-club-discovery-visual-refresh.md, Screen 4.
class ClubDiscoveryCard extends StatelessWidget {
  const ClubDiscoveryCard({
    super.key,
    required this.club,
    required this.onTap,
    this.layout = ClubDiscoveryCardLayout.row,
  });

  final Club club;
  final VoidCallback onTap;
  final ClubDiscoveryCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final semantics = Semantics(
      label: '${club.name}'
          '${club.category != null ? ', หมวดหมู่ ${club.category}' : ''}'
          ', มีสมาชิก ${club.memberCount} คน',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            layout == ClubDiscoveryCardLayout.grid
                ? BorderRadius.circular(WynSpacing.radiusMd)
                : null,
        child: layout == ClubDiscoveryCardLayout.grid ? _buildGrid(context) : _buildRow(context),
      ),
    );
    return semantics;
  }

  Widget _buildGrid(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(WynSpacing.radiusMd)),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              // Beta4 §8.1: the Club's single identity image, not a
              // separate cover. This card's grid layout is the one
              // Club surface that shows the image large, so the hero
              // slot is where it goes -- the row layout beside it uses
              // the same image as a circle (ClubAvatar).
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
          Padding(
            padding: const EdgeInsets.all(WynSpacing.space2),
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
                Text(
                  club.category != null
                      ? '${club.category} · ${club.memberCount} สมาชิก'
                      : '${club.memberCount} สมาชิก',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClubAvatar(club: club),
          const SizedBox(width: WynSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(club.name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (club.category != null) ...[
                      Chip(
                        label: Text(club.category!),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        labelStyle: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '${club.memberCount} สมาชิก',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
                if (club.description != null && club.description!.isNotEmpty) ...[
                  const SizedBox(height: WynSpacing.space1),
                  Text(
                    club.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
