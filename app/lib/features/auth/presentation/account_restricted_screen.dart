import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';
import '../../moderation/data/appeal_status.dart';

/// Screen 6 -- shown in place of RootShell/WelcomeScreen by AuthGate
/// when the account trying to log in is Suspended or Banned.
///
/// WYN-030 adds an appeal entry point for both Suspend and Ban (Ban's
/// own copy used to say appeal wasn't available in-app yet -- it now
/// is, so that line is gone). Submitting an appeal keeps the user on
/// this same screen with [appealStatus] now `pending`; "ตกลง" stays
/// the only way to actually leave, whether that's before or after
/// appealing. See AuthGate for why this screen is rendered from
/// *local State*, not derived straight from the auth stream (the race
/// this class's caller has to avoid), and for why sign-out itself now
/// happens only when the user leaves this screen, not the moment the
/// block was detected.
class AccountRestrictedScreen extends StatelessWidget {
  const AccountRestrictedScreen({
    super.key,
    required this.isBanned,
    required this.reason,
    required this.expiresAt,
    required this.onAcknowledge,
    this.actionId,
    this.appealStatus,
    this.onAppeal,
  });

  final bool isBanned;
  final String? reason;

  /// Suspend only -- always null when [isBanned] is true (Ban never
  /// expires on its own, see supabase/schema.sql).
  final DateTime? expiresAt;

  final VoidCallback onAcknowledge;

  // WYN-030: all 3 optional, default null -- a caller that doesn't
  // pass them gets exactly the same screen as before this feature
  // existed (same defaulting shape as RestrictionBanner's identical
  // trio). [actionId] gates whether the appeal section renders at
  // all, [appealStatus] picks which of its 3 states to show, [onAppeal]
  // is AuthGate's own "open AppealFormScreen" callback.
  final String? actionId;
  final AppealStatus? appealStatus;
  final Future<void> Function()? onAppeal;

  @override
  Widget build(BuildContext context) {
    final daysLeft = expiresAt == null
        ? null
        : expiresAt!.difference(DateTime.now()).inDays.clamp(0, 1 << 30) + 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WynSpacing.space6),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.gpp_bad_outlined,
                  size: 72,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: WynSpacing.space4),
                Text(
                  isBanned ? 'บัญชีของคุณถูกระงับถาวร' : 'บัญชีของคุณถูกระงับชั่วคราว',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: WynSpacing.space4),
                Text(
                  'เหตุผล: ${reason ?? 'ไม่ระบุ'}',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (!isBanned && expiresAt != null) ...[
                  const SizedBox(height: WynSpacing.space4),
                  Text(
                    'ระงับถึงวันที่ ${dateLabel(expiresAt!)} (อีก $daysLeft วัน)',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: WynSpacing.space2),
                  Text(
                    'เมื่อครบกำหนดคุณจะกลับมาใช้งานได้ตามปกติ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: WynSpacing.space8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onAcknowledge,
                    child: const Text('ตกลง'),
                  ),
                ),
                if (actionId != null) ...[
                  const SizedBox(height: WynSpacing.space3),
                  _buildAppealSection(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppealSection(BuildContext context) {
    switch (appealStatus ?? AppealStatus.none) {
      case AppealStatus.none:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onAppeal,
            child: const Text('อุทธรณ์'),
          ),
        );
      case AppealStatus.pending:
        return Text(
          'คุณได้ส่งอุทธรณ์แล้ว อยู่ระหว่างการตรวจสอบ',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        );
      case AppealStatus.rejected:
        return Text(
          'อุทธรณ์ของคุณถูกปฏิเสธแล้ว',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        );
      case AppealStatus.approved:
        // Not reachable in practice -- an approved appeal overturns the
        // block, which means AuthGate stops constructing this screen at
        // all on the next login/status check. See RestrictionBanner's
        // identical case for the same reasoning.
        return const SizedBox.shrink();
    }
  }
}
