import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../auth/presentation/auth_method_screen.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../../push/data/push_token_repository.dart';
import '../../push/presentation/push_notification_service.dart';
import '../data/account_switcher_repository.dart';
import '../data/stored_account.dart';

/// Opens the account switcher as a modal bottom sheet -- the entry point
/// is SettingsScreen's "บัญชี" -> "สลับบัญชี" row. Returns once the sheet
/// is dismissed (no meaningful return value -- switching itself is
/// handled entirely by AuthGate reacting to the auth-state change, same
/// "rebuild the parent, don't navigate" shape every other auth-adjacent
/// screen in this app already follows).
Future<void> showAccountSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WynColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(WynSpacing.radiusLg)),
    ),
    builder: (_) => const AccountSwitcherSheet(),
  );
}

class AccountSwitcherSheet extends StatefulWidget {
  const AccountSwitcherSheet({super.key, this.accountSwitcherRepository});

  final AccountSwitcherRepository? accountSwitcherRepository;

  @override
  State<AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends State<AccountSwitcherSheet> {
  late final AccountSwitcherRepository _repository =
      widget.accountSwitcherRepository ?? AccountSwitcherRepository();
  late Future<List<StoredAccount>> _accountsFuture = _repository.loadAccounts();

  String? _switchingUserId;
  String? _errorText;

  Future<void> _switchTo(StoredAccount account) async {
    if (_switchingUserId != null) return;
    setState(() {
      _switchingUserId = account.userId;
      _errorText = null;
    });
    try {
      // Beta4 §11.5 (Notification Account Isolation) -- hand this
      // device's push registration over *before* the session changes.
      //
      // `push_tokens` is unique on `token` and its RLS forbids one user
      // from retargeting a row owned by another, so once account A has
      // registered this device, account B's own registration is
      // rejected and the row keeps pointing at A: A's push
      // notifications go on arriving on a phone where B is signed in.
      // Deleting the row while A is still the current session is the
      // only moment anyone is permitted to remove it -- after
      // `switchTo` returns, the client is B and the row is A's.
      //
      // Best-effort on purpose, and deliberately *not* a reason to
      // abort the switch: failing to clean up a push registration must
      // never leave a person stuck on an account they asked to leave.
      // The worst case if this throws is the pre-Beta4 behaviour, and
      // the server drops unknown tokens on its own (see
      // send-push-notification's UNREGISTERED handling).
      try {
        await PushNotificationService(
          PushTokenRepository(Supabase.instance.client),
        ).unregisterCurrentDevice();
      } catch (_) {
        // Intentionally silent -- see above.
      }

      await _repository.switchTo(account, Supabase.instance.client);
      // No manual pop/navigation on success -- AuthGate's own auth-state
      // listener pops every route (this sheet included) back to itself
      // and rebuilds for the newly active account, same as every other
      // sign-in path in this app.
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _switchingUserId = null;
        _errorText = 'สลับบัญชีไม่สำเร็จ ลองใหม่อีกครั้ง';
      });
    }
  }

  Future<void> _confirmRemove(StoredAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบบัญชีนี้ออกจากเครื่อง?'),
        content: Text(
          'คุณจะต้องเข้าสู่ระบบใหม่หากต้องการใช้ ${account.nameOrUsername} อีกครั้งบนเครื่องนี้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ลบ', style: TextStyle(color: WynColors.errorLight)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _repository.removeAccount(account.userId);
    if (!mounted) return;
    setState(() => _accountsFuture = _repository.loadAccounts());
  }

  Future<void> _addAccount() async {
    final accounts = await _accountsFuture;
    if (accounts.length >= AccountSwitcherRepository.maxAccounts) {
      setState(() => _errorText =
          'เพิ่มบัญชีได้สูงสุด ${AccountSwitcherRepository.maxAccounts} บัญชีต่อเครื่อง ลบบัญชีอื่นก่อนเพิ่มใหม่');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AuthMethodScreen(isAddingAccount: true),
      ),
    );
    // A successful add-account sign-in fires AuthChangeEvent.signedIn,
    // which pops this sheet closed via AuthGate's own listener (same as
    // _switchTo above) before this line would ever run -- this only
    // fires if the user backed out of AuthMethodScreen without signing
    // in, in which case refreshing the list is a harmless no-op.
    if (!mounted) return;
    setState(() => _accountsFuture = _repository.loadAccounts());
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: WynSpacing.space2),
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: WynSpacing.space4),
                decoration: BoxDecoration(
                  color: WynColors.hairline,
                  borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
              child: Text('บัญชีของฉัน', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: WynSpacing.space2),
            FutureBuilder<List<StoredAccount>>(
              future: _accountsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: WynSpacing.space8),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final accounts = snapshot.data!;
                return Column(
                  children: [
                    for (final account in accounts)
                      _AccountRow(
                        key: ValueKey(account.userId),
                        account: account,
                        isActive: account.userId == currentUserId,
                        isSwitching: account.userId == _switchingUserId,
                        onTap: () => _switchTo(account),
                        onRemove: account.userId == currentUserId
                            ? null
                            : () => _confirmRemove(account),
                      ),
                  ],
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                radius: 20,
                backgroundColor: WynColors.hairline,
                child: Icon(Icons.add, color: WynColors.ink),
              ),
              title: const Text('เพิ่มบัญชี'),
              onTap: _switchingUserId != null ? null : _addAccount,
            ),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: WynSpacing.space4),
                child: Text(
                  _errorText!,
                  style: const TextStyle(fontSize: 13, color: WynColors.errorLight),
                ),
              ),
            const SizedBox(height: WynSpacing.space4),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    super.key,
    required this.account,
    required this.isActive,
    required this.isSwitching,
    required this.onTap,
    this.onRemove,
  });

  final StoredAccount account;
  final bool isActive;
  final bool isSwitching;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AvatarCircle(
        imageUrl: account.avatarUrl,
        fallbackText: account.username,
        radius: 20,
      ),
      title: Text(account.nameOrUsername),
      subtitle: Text('@${account.username}'),
      trailing: isSwitching
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isActive
              ? const Icon(Icons.check_circle, color: WynColors.sapphire)
              : onRemove == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18, color: WynColors.faint),
                      tooltip: 'ลบบัญชีนี้ออกจากเครื่อง',
                      onPressed: onRemove,
                    ),
      onTap: isActive ? null : onTap,
    );
  }
}
