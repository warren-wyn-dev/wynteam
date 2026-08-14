import 'package:flutter/material.dart';

import '../../data/club.dart';

/// A joined-Club shortcut card for the Home CLUB section's horizontal
/// row -- icon + name + member count, ~100px wide. See
/// .wyn/docs/design/wyn-014-club-core.md, Screen 1.
class ClubMiniCard extends StatelessWidget {
  const ClubMiniCard({super.key, required this.club, required this.onTap});

  final Club club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${club.name} มีสมาชิก ${club.memberCount} คน กดเพื่อดู Club',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 96,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage:
                      club.iconUrl != null ? NetworkImage(club.iconUrl!) : null,
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
                const SizedBox(height: 4),
                Text(
                  club.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${club.memberCount} สมาชิก',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
