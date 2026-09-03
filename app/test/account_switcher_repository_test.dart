import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/account_switcher/data/account_switcher_repository.dart';
import 'package:wyn/features/account_switcher/data/stored_account.dart';

/// An in-memory AccountSecureStore -- lets these tests exercise
/// AccountSwitcherRepository's real read/upsert/remove logic without
/// touching a real platform Keychain/Keystore via method channels. Same
/// "extend/inject the real thing, fake the storage/network-touching
/// bits" shape as every other Recording* test double in this app.
class _FakeSecureStore implements AccountSecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

StoredAccount _account(String userId, {String refreshToken = 'rt-1'}) =>
    StoredAccount(
      userId: userId,
      refreshToken: refreshToken,
      username: 'user_$userId',
      displayName: 'User $userId',
    );

User _fakeUser(String id, {bool isAnonymous = false}) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      isAnonymous: isAnonymous,
    );

void main() {
  late _FakeSecureStore store;
  late AccountSwitcherRepository repository;

  setUp(() {
    store = _FakeSecureStore();
    repository = AccountSwitcherRepository(store: store);
  });

  test('loadAccounts returns an empty list when nothing is stored', () async {
    expect(await repository.loadAccounts(), isEmpty);
  });

  test('upsertAccount adds a new account and persists it as JSON', () async {
    await repository.upsertAccount(_account('u1'));

    final accounts = await repository.loadAccounts();
    expect(accounts, hasLength(1));
    expect(accounts.single.userId, 'u1');
    expect(accounts.single.username, 'user_u1');
  });

  test('upsertAccount updates an existing account in place instead of duplicating', () async {
    await repository.upsertAccount(_account('u1', refreshToken: 'rt-old'));
    await repository.upsertAccount(_account('u1', refreshToken: 'rt-new'));

    final accounts = await repository.loadAccounts();
    expect(accounts, hasLength(1));
    expect(accounts.single.refreshToken, 'rt-new');
  });

  test(
      'upsertAccount throws TooManyAccountsException past maxAccounts for a '
      'genuinely new account, but never for updating an existing one',
      () async {
    for (var i = 0; i < AccountSwitcherRepository.maxAccounts; i++) {
      await repository.upsertAccount(_account('u$i'));
    }
    expect(await repository.loadAccounts(), hasLength(5));

    // Updating one of the 5 already-stored accounts must never throw,
    // even though the store is already "full".
    await repository.upsertAccount(_account('u0', refreshToken: 'rt-updated'));
    expect((await repository.loadAccounts()).first.refreshToken, 'rt-updated');

    // A genuinely new 6th account is rejected.
    expect(
      () => repository.upsertAccount(_account('u-sixth')),
      throwsA(isA<TooManyAccountsException>()),
    );
    expect(await repository.loadAccounts(), hasLength(5));
  });

  test('removeAccount drops only the matching account', () async {
    await repository.upsertAccount(_account('u1'));
    await repository.upsertAccount(_account('u2'));

    await repository.removeAccount('u1');

    final accounts = await repository.loadAccounts();
    expect(accounts, hasLength(1));
    expect(accounts.single.userId, 'u2');
  });

  test('removeAccount on an id that was never stored is a harmless no-op', () async {
    await repository.upsertAccount(_account('u1'));
    await repository.removeAccount('does-not-exist');
    expect(await repository.loadAccounts(), hasLength(1));
  });

  group('updateRefreshToken', () {
    test('updates an already-stored account\'s token in place', () async {
      await repository.upsertAccount(_account('u1', refreshToken: 'rt-old'));
      await repository.updateRefreshToken('u1', 'rt-rotated');

      final accounts = await repository.loadAccounts();
      expect(accounts.single.refreshToken, 'rt-rotated');
    });

    test('is a no-op (does not create an entry) for an account never captured',
        () async {
      await repository.updateRefreshToken('never-added', 'rt-x');
      expect(await repository.loadAccounts(), isEmpty);
    });
  });

  group('captureCurrentAccount', () {
    test('adds the session\'s account with its username/displayName', () async {
      final session = Session(
        accessToken: 'at',
        tokenType: 'bearer',
        refreshToken: 'rt-captured',
        user: _fakeUser('u1'),
      );

      await repository.captureCurrentAccount(
        session: session,
        username: 'worapon',
        displayName: 'Worapon',
      );

      final accounts = await repository.loadAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.single.userId, 'u1');
      expect(accounts.single.refreshToken, 'rt-captured');
      expect(accounts.single.username, 'worapon');
      expect(accounts.single.displayName, 'Worapon');
    });

    test('silently does nothing when the session has no refresh token', () async {
      final session = Session(
        accessToken: 'at',
        tokenType: 'bearer',
        user: _fakeUser('u1'),
      );

      await repository.captureCurrentAccount(session: session, username: 'worapon');

      expect(await repository.loadAccounts(), isEmpty);
    });

    test('swallows TooManyAccountsException for a 6th distinct account '
        'instead of throwing out of AuthGate\'s fire-and-forget call site',
        () async {
      for (var i = 0; i < AccountSwitcherRepository.maxAccounts; i++) {
        await repository.upsertAccount(_account('u$i'));
      }

      final sixthSession = Session(
        accessToken: 'at',
        tokenType: 'bearer',
        refreshToken: 'rt-6',
        user: _fakeUser('u-sixth'),
      );

      // Must not throw.
      await repository.captureCurrentAccount(
        session: sixthSession,
        username: 'sixth',
      );

      expect(await repository.loadAccounts(), hasLength(5));
    });
  });

  test(
      'forgetAndSwitchToNextIfAny removes the account and returns false '
      'without touching the network when no other account remains',
      () async {
    await repository.upsertAccount(_account('only-account'));

    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

    final switched =
        await repository.forgetAndSwitchToNextIfAny('only-account', client);

    expect(switched, isFalse);
    expect(await repository.loadAccounts(), isEmpty);
  });

  test('persisted JSON round-trips every field of StoredAccount', () async {
    const account = StoredAccount(
      userId: 'u1',
      refreshToken: 'rt-1',
      username: 'worapon',
      email: 'w@example.com',
      displayName: 'Worapon',
      avatarUrl: 'https://example.com/a.jpg',
    );
    await repository.upsertAccount(account);

    // Round-trip through the same JSON encode/decode this repository
    // itself uses, independent of loadAccounts, to prove the *stored*
    // representation (not just the in-memory object) is complete.
    final raw = await store.read('wynos_switcher_accounts');
    final decoded =
        (jsonDecode(raw!) as List).single as Map<String, dynamic>;
    expect(StoredAccount.fromJson(decoded).toJson(), account.toJson());
  });
}
