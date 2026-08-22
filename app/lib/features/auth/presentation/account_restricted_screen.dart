import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';

/// Screen 6 -- shown in place of RootShell/WelcomeScreen by AuthGate
/// when the account trying to log in is Suspended or Banned. This is
/// the *only* way out of a blocked login attempt this round (no Unban/
/// appeal flow in-app yet -- Ban's own copy says so honestly rather
/// than promising a channel that doesn't exist, per the same integrity
/// rule WYN-027 Screen 9 already set).
///
/// Deliberately has no AppBar/back affordance -- the single "ตกลง"
/// button is the only way forward, back to WelcomeScreen. See AuthGate
/// for why this must be rendered from *local State*, not derived
/// straight from the auth stream (the race this class's caller has to
/// avoid).
class AccountRestrictedScreen extends StatelessWidget {
  const AccountRestrictedScreen({
    super.key,
    required this.isBanned,
    required this.reason,
    required this.expiresAt,
    required this.onAcknowledge,
  });

  final bool isBanned;
  final String? reason;

  /// Suspend only -- always null when [isBanned] is true (Ban never
  /// expires on its own, see supabase/schema.sql).
  final DateTime? expiresAt;

  final VoidCallback onAcknowledge;

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
                if (isBanned) ...[
                  const SizedBox(height: WynSpacing.space4),
                  Text(
                    'การอุทธรณ์ยังไม่เปิดให้ใช้งานในแอปขณะนี้',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
