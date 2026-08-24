import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/settings/presentation/delete_account_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_auth_repository.dart';
import 'support/recording_data_rights_repository.dart';

void main() {
  // Constructed in setUpAll -- see settings_screen_test.dart's own
  // comment on why (the GoTrue auto-refresh timer started by the
  // SupabaseClient each Recording repository wraps must not be
  // attributed to a single test's FakeAsync zone).
  late RecordingDataRightsRepository recordingDataRightsRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    recordingDataRightsRepository = RecordingDataRightsRepository();
  });

  setUp(() {
    recordingDataRightsRepository.deleteMyAccountCalls = 0;
    recordingDataRightsRepository.deleteError = null;
  });

  Widget buildScreen({
    required RecordingAuthRepository authRepository,
  }) {
    return MaterialApp(
      home: DeleteAccountScreen(
        dataRightsRepository: recordingDataRightsRepository,
        authRepository: authRepository,
      ),
    );
  }

  group('typed confirmation gates the button', () {
    testWidgets('button starts disabled with an empty field', (tester) async {
      final authRepository = RecordingAuthRepository();
      addTearDown(authRepository.dispose);
      await tester.pumpWidget(buildScreen(authRepository: authRepository));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    for (final nearMiss in [
      'ลบ บัญชี', // extra whitespace inside the phrase
      'ลบบัญชีถาวร', // partial/extra text
      'ลบ', // partial match
      'LBBANCHI', // wrong content entirely
    ]) {
      testWidgets('"$nearMiss" keeps the button disabled', (tester) async {
        final authRepository = RecordingAuthRepository();
        addTearDown(authRepository.dispose);
        await tester.pumpWidget(buildScreen(authRepository: authRepository));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), nearMiss);
        await tester.pumpAndSettle();

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull,
            reason: '"$nearMiss" should not enable the button');
      });
    }

    testWidgets('exact phrase with surrounding whitespace enables the button',
        (tester) async {
      final authRepository = RecordingAuthRepository();
      addTearDown(authRepository.dispose);
      await tester.pumpWidget(buildScreen(authRepository: authRepository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  ลบบัญชี  ');
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('exact phrase with no extra whitespace enables the button',
        (tester) async {
      final authRepository = RecordingAuthRepository();
      addTearDown(authRepository.dispose);
      await tester.pumpWidget(buildScreen(authRepository: authRepository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ลบบัญชี');
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });
  });

  group('confirmation flow', () {
    testWidgets(
        'tapping the button shows an AlertDialog before delete_my_account() '
        'is called', (tester) async {
      final authRepository = RecordingAuthRepository();
      addTearDown(authRepository.dispose);
      await tester.pumpWidget(buildScreen(authRepository: authRepository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ลบบัญชี');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('ยืนยันลบบัญชีถาวร?'), findsOneWidget);
      // The RPC must not have fired yet -- only the second-layer
      // AlertDialog confirmation does that.
      expect(recordingDataRightsRepository.deleteMyAccountCalls, 0);
    });

    testWidgets('cancelling the dialog never calls delete_my_account()',
        (tester) async {
      final authRepository = RecordingAuthRepository();
      addTearDown(authRepository.dispose);
      await tester.pumpWidget(buildScreen(authRepository: authRepository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ลบบัญชี');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(recordingDataRightsRepository.deleteMyAccountCalls, 0);
      expect(authRepository.signOutCalls, 0);
    });

    testWidgets(
        'confirming the dialog calls delete_my_account(), then signs out',
        (tester) async {
      final authRepository = RecordingAuthRepository();
      addTearDown(authRepository.dispose);
      await tester.pumpWidget(buildScreen(authRepository: authRepository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ลบบัญชี');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Not pumpAndSettle -- the success path deliberately leaves
      // _isDeleting true (no success state to show -- the real
      // AuthGate is what navigates away after signOut(), per the
      // Design spec's States section), so the button's
      // CircularProgressIndicator keeps its indeterminate animation
      // running and pumpAndSettle would never terminate. A handful of
      // plain pump()s is enough to flush the (real, non-Timer-based)
      // async chain: deleteMyAccount() -> unregisterCurrentDevice()
      // (a same-microtask no-op since Firebase isn't initialized in
      // tests) -> signOut().
      await tester.tap(find.text('ลบ'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(recordingDataRightsRepository.deleteMyAccountCalls, 1);
      expect(authRepository.signOutCalls, 1);
    });

    testWidgets(
        'a failed deletion shows an error SnackBar, stays on screen, and '
        'never signs out', (tester) async {
      recordingDataRightsRepository.deleteError = Exception('network error');
      final authRepository = RecordingAuthRepository();
      addTearDown(authRepository.dispose);
      await tester.pumpWidget(buildScreen(authRepository: authRepository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ลบบัญชี');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();

      expect(recordingDataRightsRepository.deleteMyAccountCalls, 1);
      expect(authRepository.signOutCalls, 0);
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(find.text('ลบบัญชีไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    });
  });
}
