import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../account_switcher/data/account_switcher_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../push/data/push_token_repository.dart';
import '../../push/presentation/push_notification_service.dart';
import '../data/data_rights_repository.dart';

/// Screen: `DeleteAccountScreen` (WYN-047). Forces a typed
/// confirmation + a second AlertDialog confirmation before calling
/// `delete_my_account()` -- account deletion is irreversible and
/// immediate, with no grace period (unlike Drop's 30-day soft-delete/
/// restore window, WYN-037), so this screen deliberately uses more
/// friction than `confirmDeletePost` (core/widgets/confirm_delete_dialog.dart)
/// and never claims anything is recoverable. Pushed as an ordinary
/// route on top of SettingsScreen (has an AppBar + back button --
/// cancellable up until the final confirm, unlike
/// DocumentAcceptanceScreen's forced no-exit shape from WYN-046). See
/// .wyn/docs/design/wyn-047-data-rights.md.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({
    super.key,
    this.dataRightsRepository,
    this.authRepository,
  });

  /// Optional/defaulted to a real Supabase-backed instance when
  /// omitted -- same shape as every other repository this app threads
  /// through optionally (see SettingsScreen's own comment on the
  /// pattern).
  final DataRightsRepository? dataRightsRepository;
  final AuthRepository? authRepository;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  /// The exact phrase the user must type (Design spec: "case-sensitive
  /// ตรงตัว ไม่ trim ยกเว้น whitespace หัวท้าย") -- leading/trailing
  /// whitespace is stripped before comparing, but nothing in the
  /// middle is, so "ลบ บัญชี" (extra internal whitespace) still fails
  /// to match.
  static const _confirmationPhrase = 'ลบบัญชี';

  late final DataRightsRepository _dataRightsRepository =
      widget.dataRightsRepository ??
          DataRightsRepository(Supabase.instance.client);
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository(Supabase.instance.client);

  final TextEditingController _confirmController = TextEditingController();
  bool _isMatch = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(_onConfirmTextChanged);
  }

  @override
  void dispose() {
    _confirmController.removeListener(_onConfirmTextChanged);
    _confirmController.dispose();
    super.dispose();
  }

  void _onConfirmTextChanged() {
    final matches = _confirmController.text.trim() == _confirmationPhrase;
    if (matches != _isMatch) {
      setState(() => _isMatch = matches);
    }
  }

  Future<void> _startDeletion() async {
    if (!_isMatch || _isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันลบบัญชีถาวร?'),
        content: const Text(
          'บัญชีและข้อมูลทั้งหมดของคุณจะถูกลบทันที ไม่สามารถกู้คืนได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Captured before deleteMyAccount()/signOut() below -- currentUser
    // reads null once the session is gone, and multi-account switching
    // needs this account's id specifically to remove it from the
    // on-device switcher (see the forgetAndSwitchToNextIfAny call at the
    // end of this method).
    final deletedUserId = Supabase.instance.client.auth.currentUser?.id;

    setState(() => _isDeleting = true);
    try {
      await _dataRightsRepository.deleteMyAccount();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบบัญชีไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
      return;
    }

    // Success path -- best-effort push-token deregistration first (a
    // deleted account must not keep this device's token pointing at
    // it), then a real sign-out. Same posture/order as
    // ViewProfileScreen._signOut/AuthGate._leaveBlockedScreen: never
    // let a push-token failure block leaving. No further setState
    // after signOut() -- AuthGate's auth-state listener pops back to
    // its own route and renders WelcomeScreen (or, with other accounts
    // still added on this device, the next one -- see below) on its
    // own, this screen does not navigate itself.
    try {
      await PushNotificationService(
              PushTokenRepository(Supabase.instance.client))
          .unregisterCurrentDevice();
    } catch (_) {
      // Intentionally silent -- see ViewProfileScreen._signOut.
    }
    await _authRepository.signOut();

    // Multi-account switching: same "logging out/losing this account
    // lands you on another already-added one instead of WelcomeScreen"
    // behavior as SettingsScreen._signOut -- a deleted account obviously
    // can never be switched back to, so it's removed from the switcher
    // unconditionally either way. Best-effort, same posture as the
    // push-token deregistration above -- a secure-storage hiccup here
    // must never leave account deletion looking stuck or failed.
    if (deletedUserId != null) {
      try {
        await AccountSwitcherRepository().forgetAndSwitchToNextIfAny(
            deletedUserId, Supabase.instance.client);
      } catch (_) {
        // Intentionally silent -- see comment above.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canSubmit = _isMatch && !_isDeleting;

    return Scaffold(
      appBar: AppBar(title: const Text('ลบบัญชี')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WynSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                  const SizedBox(width: WynSpacing.space2),
                  Expanded(
                    child: Text(
                      'ลบบัญชีถาวร',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: WynSpacing.space3),
              const Text('การลบบัญชีจะทำให้สิ่งต่อไปนี้หายไปทั้งหมด:'),
              const SizedBox(height: WynSpacing.space2),
              const _BulletItem('โพสต์, Pop และ Comment ทั้งหมดของคุณ'),
              const _BulletItem('Follower และ Following ทั้งหมด'),
              const _BulletItem('ข้อความแชททั้งหมดที่คุณส่ง'),
              const _BulletItem('การเป็นสมาชิก Club ทั้งหมด'),
              const SizedBox(height: WynSpacing.space3),
              Text(
                'การลบบัญชีไม่สามารถย้อนกลับได้ ไม่มีระยะเวลาผ่อนผันเหมือนการลบโพสต์',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: WynSpacing.space4),
              TextField(
                controller: _confirmController,
                enabled: !_isDeleting,
                decoration: const InputDecoration(
                  labelText: 'พิมพ์ "ลบบัญชี" เพื่อยืนยัน',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: WynSpacing.space4),
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  label: canSubmit
                      ? 'ลบบัญชีถาวร'
                      : 'ลบบัญชีถาวร ปิดใช้งานจนกว่าจะพิมพ์ข้อความยืนยันให้ตรง',
                  excludeSemantics: true,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    onPressed: canSubmit ? _startDeletion : null,
                    child: _isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ลบบัญชีถาวร'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WynSpacing.space1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
