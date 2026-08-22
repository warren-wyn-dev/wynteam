import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/block/presentation/blocked_list_screen.dart';
import 'package:wyn/features/mute/presentation/muted_list_screen.dart';
import 'package:wyn/features/settings/presentation/settings_screen.dart';

import 'support/fake_supabase_session.dart';

void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  testWidgets('ความปลอดภัย section shows both Blocked List and Muted List rows',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('ความปลอดภัย'), findsOneWidget);
    expect(find.text('บัญชีที่ถูกบล็อก'), findsOneWidget);
    expect(find.text('บัญชีที่ปิดเสียง'), findsOneWidget);
  });

  testWidgets('tapping บัญชีที่ถูกบล็อก opens BlockedListScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('บัญชีที่ถูกบล็อก'));
    await tester.pumpAndSettle();

    expect(find.byType(BlockedListScreen), findsOneWidget);
  });

  testWidgets('tapping บัญชีที่ปิดเสียง opens MutedListScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('บัญชีที่ปิดเสียง'));
    await tester.pumpAndSettle();

    expect(find.byType(MutedListScreen), findsOneWidget);
  });
}
