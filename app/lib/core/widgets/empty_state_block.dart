import 'package:flutter/material.dart';

import '../design/wyn_colors.dart';
import '../design/wyn_spacing.dart';
import '../design/wyn_typography.dart';

/// 22-empty-states.tsx's shared empty-state shape: an icon centered in a
/// tinted circle, a title-style headline, and a muted supportive line below
/// it -- "the same icon-in-tint-circle + title-style headline + supportive
/// line pattern as the empty state already established on Home... and
/// Bookmarks" (that file's own doc comment). Used by Notifications and
/// the Chat Inbox; reach for this rather than a one-off empty-state
/// layout wherever this same shape is needed next.
class EmptyStateBlock extends StatelessWidget {
  const EmptyStateBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFF1EFE9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: WynColors.sapphire),
          ),
          const SizedBox(height: WynSpacing.space4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: WynTypography.screenTitle(fontSize: 18, color: WynColors.ink),
          ),
          const SizedBox(height: WynSpacing.space1 + 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: WynColors.graphite, height: 1.4),
          ),
        ],
      ),
    );
  }
}
