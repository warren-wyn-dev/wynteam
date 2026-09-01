import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// WYN-072 (Guest Browsing): call before any screen/action that needs a
/// real (non-anonymous) identity -- Bottom Nav's "โปรไฟล์"/"+"
/// (Create Drop)/"การแจ้งเตือน", Home's chat entry point, and any write
/// action on content (Like/Comment/Save/ReDrop/Poll vote/Follow/Club
/// create-join). Returns `true` if the caller should proceed normally
/// (a real signed-in identity -- AuthGate never reaches call sites with
/// no session at all, so that case doesn't need handling here);
/// returns `false` if the current user is a guest (Anonymous Sign-In,
/// see AuthMethodScreen's "เข้าชม WYNOS ได้เลย") and was shown the
/// sign-in prompt instead -- the caller must not proceed with whatever
/// it was about to do.
///
/// One shared gate, not a dialog rolled per call site -- see
/// .wyn/docs/design/wyn-072-onboarding-polish-guest-browsing.md's own
/// "ห้ามเขียน dialog ซ้ำมือทีละจุด" rule.
Future<bool> requireRealAccount(BuildContext context) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || !user.isAnonymous) return true;

  final wantsToSignIn = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('เข้าสู่ระบบเพื่อดำเนินการต่อ'),
      content: const Text('ฟีเจอร์นี้ต้องมีบัญชีจริง สมัครใช้เวลาไม่ถึงนาที'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('ไว้ทีหลัง'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('สมัคร/เข้าสู่ระบบ'),
        ),
      ],
    ),
  );

  // Discard the anonymous session and let AuthGate's own auth-state
  // listener take it from there -- same "just signOut(), don't navigate
  // yourself" convention every other sign-out call site in this app
  // already follows (ViewProfileScreen._signOut, DeleteAccountScreen,
  // AuthGate._leaveBlockedScreen). AuthGate's listener pops back to the
  // root route and re-renders WelcomeScreen once the signedOut event
  // lands -- pushing AuthMethodScreen directly from here instead would
  // race that listener (unpredictable which one runs first), so this
  // deliberately lands the guest one tap earlier (Welcome, not Auth
  // Method) in exchange for reusing a mechanism that's already proven
  // safe everywhere else in the app.
  //
  // Nothing on the anonymous session is worth keeping -- every gated
  // action is one the guest never got to perform in the first place --
  // so no identity-linking upgrade (`linkIdentity`) is attempted here;
  // see the design doc's own note on that being a deliberate non-goal
  // for this task.
  if (wantsToSignIn == true) {
    await Supabase.instance.client.auth.signOut();
  }
  return false;
}
