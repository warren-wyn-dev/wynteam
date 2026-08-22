import 'package:flutter/material.dart';

import '../../features/moderation/data/appeal_status.dart';
import '../design/wyn_spacing.dart';
import '../text_utils.dart';

/// Screen 7 (WYN-029) -- shown above the posting UI in CreateDropScreen,
/// the comment composer of DropDetailScreen/ClubPostDetailScreen, and
/// CreateClubScreen, whenever `ModerationStatus.isRestricted` is true.
/// Reuses `ViewProfileScreen._buildBlockedBanner`'s (WYN-027) exact
/// visual shape rather than inventing a new one -- lives in
/// `core/widgets/` (like `confirm_delete_dialog.dart`, moved here at
/// WYN-007 for the same reason) because Drop and Club both need it.
///
/// This is presentation only -- the actual block is enforced at the RLS
/// INSERT layer (see supabase/schema.sql's WYN-029 section); every call
/// site additionally disables its own post/comment/create button when
/// [expiresAt]/[reason] are non-null, but that's defense-in-depth for
/// UX clarity, not the real security boundary.
class RestrictionBanner extends StatelessWidget {
  const RestrictionBanner({
    super.key,
    required this.reason,
    required this.expiresAt,
    this.actionId,
    this.appealStatus,
    this.onAppeal,
  });

  final String? reason;
  final DateTime? expiresAt;

  // WYN-030: all 3 optional, default null -- a caller that doesn't pass
  // them gets exactly the same banner as before this feature existed
  // (see .wyn/docs/design/wyn-030-appeal-system.md, Screen 2). Only
  // ever meaningful together: [actionId] gates whether the second row
  // renders at all, [appealStatus] picks which of its 3 states to
  // show, [onAppeal] is the caller's own "open AppealFormScreen"
  // callback (the caller builds it, since only it knows which
  // AppealRepository/action label to use).
  final String? actionId;
  final AppealStatus? appealStatus;
  final VoidCallback? onAppeal;

  @override
  Widget build(BuildContext context) {
    final daysLeft = expiresAt == null
        ? null
        : expiresAt!.difference(DateTime.now()).inDays.clamp(0, 1 << 30) + 1;
    final message = expiresAt == null
        ? 'คุณถูกจำกัดการโพสต์ชั่วคราว${reason == null ? '' : ' เนื่องจาก: $reason'}'
        : 'คุณถูกจำกัดการโพสต์ชั่วคราวจนถึงวันที่ ${dateLabel(expiresAt!)} '
            '(อีก $daysLeft วัน)${reason == null ? '' : ' เนื่องจาก: $reason'}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: WynSpacing.space4,
        vertical: WynSpacing.space2,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: WynSpacing.space4,
        vertical: WynSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_clock_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: WynSpacing.space2),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          if (actionId != null) _buildAppealRow(context),
        ],
      ),
    );
  }

  Widget _buildAppealRow(BuildContext context) {
    switch (appealStatus ?? AppealStatus.none) {
      case AppealStatus.none:
        return TextButton(onPressed: onAppeal, child: const Text('อุทธรณ์'));
      case AppealStatus.pending:
        return Text(
          'อยู่ระหว่างพิจารณาอุทธรณ์',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        );
      case AppealStatus.rejected:
        return Text(
          'อุทธรณ์ถูกปฏิเสธแล้ว',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        );
      case AppealStatus.approved:
        // Not reachable in practice -- an approved appeal overturns the
        // restriction, which makes this banner stop rendering at all
        // (isRestricted flips false) before this case could ever show.
        // See the design doc, Screen 2.
        return const SizedBox.shrink();
    }
  }
}
