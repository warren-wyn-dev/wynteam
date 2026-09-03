import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/features/auth/data/auth_repository.dart';
import 'package:wyn/features/auth/presentation/auth_method_screen.dart';
import 'package:wyn/features/auth/presentation/welcome_screen.dart';

void main() {
  // SupabaseClient() only stores config here — it makes no network calls
  // until a method (auth/select/etc.) is actually invoked, so it's safe to
  // construct in a widget test without a real backend.
  final authRepository =
      AuthRepository(SupabaseClient('https://example.supabase.co', 'test-key'));

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
    // WYN-072 (Guest Browsing): the new guest entry point, distinct from
    // the old WelcomeScreen guest button removed 2026-08-24 (see the test
    // below) -- this one uses signInAnonymously() and lives here instead.
    expect(find.text('เข้าชม WYNOS ได้เลย'), findsOneWidget);
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

    testWidgets('AuthMethodScreen still shows guest browsing when not adding an account',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AuthMethodScreen(authRepository: authRepository),
      ));

      expect(find.text('เข้าชม WYNOS ได้เลย'), findsOneWidget);
    });
  });
}
