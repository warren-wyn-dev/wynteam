import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/features/auth/data/auth_repository.dart';
import 'package:wyn/features/auth/presentation/email_auth_screen.dart';

void main() {
  // SupabaseClient() only stores config here -- it makes no network calls
  // until a method is actually invoked, same reasoning as widget_test.dart.
  // AuthRepository isn't injectable/fakeable (this screen takes the
  // concrete class, not an interface), so every case below only exercises
  // pure UI/validation logic and deliberately never taps Submit -- doing
  // so would fire a real, unmocked network call against the fake
  // SupabaseClient's placeholder URL.
  final authRepository =
      AuthRepository(SupabaseClient('https://example.supabase.co', 'test-key'));

  Widget buildScreen() => MaterialApp(
        home: EmailAuthScreen(authRepository: authRepository),
      );

  testWidgets('starts in sign-up mode with the submit button disabled',
      (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(find.text('สมัครสมาชิก'), findsWidgets);
    expect(find.text('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('submit button enables only once email and password are valid',
      (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.widgetWithText(TextField, 'อีเมล'), 'not-an-email');
    await tester.enterText(find.widgetWithText(TextField, 'รหัสผ่าน'), '123456');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'an invalid email must not enable the button',
    );

    await tester.enterText(
        find.widgetWithText(TextField, 'อีเมล'), 'test@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'รหัสผ่าน'), '123');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'a password shorter than 6 characters must not enable the button',
    );

    await tester.enterText(find.widgetWithText(TextField, 'รหัสผ่าน'), '123456');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('tapping the toggle switches to sign-in mode', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.tap(find.text('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'));
    await tester.pump();

    expect(find.text('ยังไม่มีบัญชี? สมัครสมาชิก'), findsOneWidget);
    // AppBar title and the submit button's own label both flip to
    // "เข้าสู่ระบบ" -- findsWidgets (not findsOneWidget) covers both.
    expect(find.text('เข้าสู่ระบบ'), findsWidgets);
  });
}
