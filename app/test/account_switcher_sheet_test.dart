import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/account_switcher/data/account_switcher_repository.dart';
import 'package:wyn/features/account_switcher/data/stored_account.dart';
import 'package:wyn/features/account_switcher/presentation/account_switcher_sheet.dart';
import 'package:wyn/features/home/presentation/widgets/verified_badge.dart';

import 'support/fake_supabase_session.dart';

/// An in-memory AccountSecureStore -- same role as
/// account_switcher_repository_test.dart's own private fake (that class
/// isn't exported, so this file keeps its own copy rather than reaching
/// across test files for it).
class _FakeSecureStore implements AccountSecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  // Founder feedback ("ตรงนี้ด้วย" on a screenshot circling the official
  // WYNOS accounts' rows in this exact sheet): the switcher's own account
  // list should carry VerifiedBadge too, not just the profile page --
  // StoredAccount had no field for it at all until now, so
  // AccountSwitcherRepository.captureCurrentAccount had nothing to store
  // regardless of the real profiles.is_verified.
  testWidgets(
      'shows VerifiedBadge next to a verified account\'s row, and not '
      'next to an unverified one', (tester) async {
    final store = _FakeSecureStore();
    final repository = AccountSwitcherRepository(store: store);
    await repository.upsertAccount(const StoredAccount(
      userId: 'me',
      refreshToken: 'rt-me',
      username: 'me_user',
      displayName: 'Me',
    ));
    await repository.upsertAccount(const StoredAccount(
      userId: 'wynos-official',
      refreshToken: 'rt-wynos',
      username: 'wynos_',
      displayName: 'WYNOS officials',
      isVerified: true,
    ));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AccountSwitcherSheet(accountSwitcherRepository: repository),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Me'), findsOneWidget);
    expect(find.text('WYNOS officials'), findsOneWidget);
    // Exactly one badge -- next to the verified account, not the
    // unverified one that also happens to be in the list.
    expect(find.byType(VerifiedBadge), findsOneWidget);
  });
}
