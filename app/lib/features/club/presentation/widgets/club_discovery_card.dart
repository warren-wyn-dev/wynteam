import 'package:flutter/material.dart';

import '../../data/club.dart';
import '../../../../core/design/wyn_spacing.dart';

/// A full-width Club row -- icon + name + category chip + member count
/// + short description, mirroring FollowListScreen/ClubMembersTab's row
/// shape (avatar/icon left, info right). Shared by Explore Clubs
/// (Screen 1) and the new Club tab in Search (Screen 2), per the Design
/// spec's reuse-one-widget-for-both instruction.
/// See .wyn/docs/design/wyn-015-club-discovery-integration.md.
class ClubDiscoveryCard extends StatelessWidget {
  const ClubDiscoveryCard({super.key, required this.club, required this.onTap});

  final Club club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${club.name}'
          '${club.category != null ? ', หมวดหมู่ ${club.category}' : ''}'
          ', มีสมาชิก ${club.memberCount} คน',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage: club.iconUrl != null ? NetworkImage(club.iconUrl!) : null,
                child: club.iconUrl == null
                    ? Text(
                        club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
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
        ),
      ),
    );
  }
}
