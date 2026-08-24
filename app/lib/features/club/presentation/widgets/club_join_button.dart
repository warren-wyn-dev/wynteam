import 'package:flutter/material.dart';

import '../../data/club_member.dart';

/// Small 3-state Join button (เข้าร่วม / เข้าร่วมแล้ว / รออนุมัติ) shared by
/// [ClubRecommendedCard]/[ClubRankedRow] (WYN-056) so both discovery
/// widgets can trigger Join/Leave directly without opening ClubPage
/// first. Mirrors ClubPage's `_buildJoinButton` state logic exactly,
/// just sized down for a compact card/row context. See
/// .wyn/docs/design/wyn-056-club-discovery-visual-refresh.md.
class ClubJoinButton extends StatelessWidget {
  const ClubJoinButton({
    super.key,
    required this.status,
    required this.isInFlight,
    required this.onTapped,
    this.expand = false,
  });

  /// Null means "not requested yet" -- ExploreClubsScreen only ever
  /// shows Clubs the user hasn't already joined (`approved` is excluded
  /// server-side by `_fetchDiscoverableClubs`), so in practice this is
  /// either null or [ClubMemberStatus.pending] (a Private Club the user
  /// already sent a request to). [ClubMemberStatus.approved] is kept in
  /// the switch below only so this stays a safe superset of ClubPage's
  /// own button logic, not because Explore can actually produce it.
  final ClubMemberStatus? status;
  final bool isInFlight;
  final VoidCallback onTapped;

  /// True for ClubRecommendedCard (full-width button under the card
  /// text); false for ClubRankedRow (compact trailing button in a row).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String label;
    String semanticsLabel;
    VoidCallback? onPressed;

    if (status == ClubMemberStatus.approved) {
      label = 'เข้าร่วมแล้ว';
      semanticsLabel = 'เข้าร่วมแล้ว กดเพื่อออกจาก Club';
      onPressed = isInFlight ? null : onTapped;
    } else if (status == ClubMemberStatus.pending) {
      label = 'รออนุมัติ';
      semanticsLabel = 'ส่งคำขอเข้าร่วมแล้ว รอการอนุมัติ';
      onPressed = null;
    } else {
      label = 'เข้าร่วม';
      semanticsLabel = 'กดเพื่อเข้าร่วม';
      onPressed = isInFlight ? null : onTapped;
    }

    final button = expand
        ? FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor:
                  status == ClubMemberStatus.approved ? scheme.surfaceContainerHigh : null,
              foregroundColor:
                  status == ClubMemberStatus.approved ? scheme.onSurfaceVariant : null,
              textStyle: Theme.of(context).textTheme.labelMedium,
            ),
            child: _buildChild(label, isInFlight),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
              textStyle: Theme.of(context).textTheme.labelSmall,
              foregroundColor:
                  status == ClubMemberStatus.approved ? scheme.outline : scheme.primary,
              side: BorderSide(
                color: status == ClubMemberStatus.approved ? scheme.outline : scheme.primary,
              ),
            ),
            child: _buildChild(label, isInFlight),
          );

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: expand ? SizedBox(width: double.infinity, height: 32, child: button) : button,
    );
  }

  Widget _buildChild(String label, bool isInFlight) {
    if (!isInFlight) return Text(label);
    return const SizedBox(
      height: 14,
      width: 14,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
