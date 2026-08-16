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
    expect(find.text('ใช้เบอร์โทรศัพท์แทน'), findsOneWidget);
  });

  // Added 2026-08-16 (temporary Internal Testing bypass -- see
  // .wyn/company/DECISIONS.md). Only asserts the button is present and
  // wired to AuthRepository.signInAnonymously -- deliberately does NOT
  // tap it. AuthRepository isn't injectable/fakeable here (WelcomeScreen
  // takes the concrete class, not an interface), so tapping would fire a
  // real, unmocked network call against the fake SupabaseClient's
  // placeholder URL and could hang/leak into later tests, the same
  // network-call risk this suite already avoids for the Google/Apple/
  // Phone OTP buttons on this screen's siblings.
  testWidgets('Shows a guest-mode button to sign in without a provider',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WelcomeScreen(authRepository: authRepository),
    ));

    expect(find.text('ทดลองใช้โดยไม่ต้องเข้าสู่ระบบ'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
