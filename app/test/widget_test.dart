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

    expect(find.text('WYN'), findsOneWidget);
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
    expect(find.text('เข้าสู่ระบบด้วย Apple'), findsOneWidget);
    // Any email + password sign-in (Founder, 2026-08-24) -- see
    // auth_method_screen.dart's own doc comment.
    expect(find.text('เข้าสู่ระบบด้วยอีเมล'), findsOneWidget);
    // Phone/OTP sign-in is temporarily hidden -- the Supabase project has
    // no SMS provider (Twilio) configured yet, so it always fails
    // server-side right now. See .wyn/company/DECISIONS.md, 2026-08-24
    // ("Phone Login ซ่อนชั่วคราว") and AuthMethodScreen's
    // _phoneLoginEnabled flag.
    expect(find.text('ใช้เบอร์โทรศัพท์แทน'), findsNothing);
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
}
