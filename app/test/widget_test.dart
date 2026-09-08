import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/auth/presentation/auth_method_screen.dart';
import 'package:wyn/features/auth/presentation/welcome_screen.dart';

import 'support/recording_auth_repository.dart';

void main() {
  // WYN-113 (Invite-Only Access Gate): AuthMethodScreen now calls
  // isInviteGateEnabled() unconditionally from initState, which a real
  // AuthRepository (backed by a real, if placeholder, SupabaseClient)
  // turns into a genuine network request -- fine for the plain
  // "constructs without touching the network" claim this used to rely
  // on, but the very first test in this file to actually mount
  // AuthMethodScreen and pumpAndSettle() now hangs waiting on that
  // request to resolve against a domain with no real backend.
  // RecordingAuthRepository resolves every method (including
  // isInviteGateEnabled, defaulted to false/off) without touching the
  // network at all -- same fix shape as every other test file in this
  // project that mounts a screen touching AuthRepository.
  final authRepository = RecordingAuthRepository();

  testWidgets('WelcomeScreen shows the headline and CTA button',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WelcomeScreen(authRepository: authRepository),
    ));

    expect(find.text('WYNOS'), findsOneWidget);
    expect(find.text('เริ่มต้นใช้งาน'), findsOneWidget);
  });

  testWidgets('Tapping the CTA navigates to AuthMethodScreen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WelcomeScreen(authRepository: authRepository),
    ));

    await tester.tap(find.text('เริ่มต้นใช้งาน'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthMethodScreen), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
    // Sign in with Apple is temporarily hidden -- no Apple Developer
    // Program yet (Founder, 2026-08-30 -- "แพงจ่ายไม่ไหว"), so it always
    // failed server-side right now. See .wyn/company/DECISIONS.md,
    // 2026-09-01 (WYN-072) and AuthMethodScreen's _appleLoginEnabled flag.
    expect(find.text('เข้าสู่ระบบด้วย Apple'), findsNothing);
    // Any email + password sign-in (Founder, 2026-08-24) -- see
    // auth_method_screen.dart's own doc comment.
    expect(find.text('เข้าสู่ระบบด้วยอีเมล'), findsOneWidget);
    // Phone/OTP sign-in is temporarily hidden -- the Supabase project has
    // no SMS provider (Twilio) configured yet, so it always fails
    // server-side right now. See .wyn/company/DECISIONS.md, 2026-08-24
    // ("Phone Login ซ่อนชั่วคราว") and AuthMethodScreen's
    // _phoneLoginEnabled flag.
    expect(find.text('ใช้เบอร์โทรศัพท์แทน'), findsNothing);
    // Guest Browsing (WYN-072) is currently paused (Founder, 2026-09-08)
    // -- see AuthMethodScreen's _guestBrowsingEnabled flag and
    // .wyn/company/DECISIONS.md, 2026-09-08.
    expect(find.text('เข้าชม WYNOS ได้เลย'), findsNothing);
  });

  // The guest-mode bypass (added 2026-08-16, see .wyn/company/
  // DECISIONS.md) was removed from WelcomeScreen (Founder, 2026-08-24)
  // now that real sign-in paths (Google/Apple/Email) work --
  // AuthRepository.signInAnonymously() itself is untouched, only this
  // screen's button to it is gone.
  testWidgets('Does not show a guest-mode button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WelcomeScreen(authRepository: authRepository),
    ));

    expect(find.text('ทดลองใช้โดยไม่ต้องเข้าสู่ระบบ'), findsNothing);
  });

  // Multi-account switching: AccountSwitcherSheet's "เพิ่มบัญชี" row pushes
  // this exact screen with isAddingAccount: true (see that screen's own
  // doc comment) -- these two cases prove what changes on screen.
  group('isAddingAccount', () {
    testWidgets('shows "เพิ่มบัญชี" as the title instead of "เข้าสู่ระบบ WYNOS"',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AuthMethodScreen(
          authRepository: authRepository,
          isAddingAccount: true,
        ),
      ));

      expect(find.text('เพิ่มบัญชี WYNOS'), findsOneWidget);
      expect(find.text('เข้าสู่ระบบ WYNOS'), findsNothing);
    });

    testWidgets('hides the guest-browsing option', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AuthMethodScreen(
          authRepository: authRepository,
          isAddingAccount: true,
        ),
      ));

      expect(find.text('เข้าชม WYNOS ได้เลย'), findsNothing);
      // Google/email sign-in still work exactly as normal -- only guest
      // browsing is specific to "not adding a second account".
      expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
      expect(find.text('เข้าสู่ระบบด้วยอีเมล'), findsOneWidget);
    });

    testWidgets(
        'guest browsing stays hidden even when not adding an account -- '
        'it is paused entirely, not just for isAddingAccount',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AuthMethodScreen(authRepository: authRepository),
      ));

      expect(find.text('เข้าชม WYNOS ได้เลย'), findsNothing);
    });
  });
}
