import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

/// A minimal `POST .../auth/v1/token?grant_type=refresh_token` response body
/// gotrue's `Session.fromJson`/`User.fromJson` can parse, keyed by the
/// refresh token the mock server should treat as valid for [userId].
Map<String, dynamic> _refreshSuccessJson({
  required String userId,
  required String refreshToken,
}) => {
      'access_token': 'at-$refreshToken',
      'token_type': 'bearer',
      'refresh_token': refreshToken,
      'expires_in': 3600,
      'user': {'id': userId, 'aud': 'authenticated'},
    };

/// A real gotrue "refresh token rejected" error shape (a stale/rotated/
/// revoked token -- not the narrow `refresh_token_already_used` case
/// gotrue itself recovers from). `error_code` (not `code`) is what
/// gotrue's error parser reads when the response carries no API-version
/// header, which this fake server deliberately never sets.
final Map<String, dynamic> _refreshTokenNotFoundJson = {
  'error_code': 'refresh_token_not_found',
  'msg': 'Invalid Refresh Token: Refresh Token Not Found',
};

/// Builds a [SupabaseClient] whose GoTrue HTTP calls are served by [handler]
/// instead of live network -- same "inject the real thing's own extension
/// point" shape as every other fake in this app, just via `http`'s own
/// `MockClient` (supabase_flutter's `SupabaseClient`/`GoTrueClient` both
/// accept a `httpClient` for exactly this purpose). `autoRefreshToken:
/// false` keeps gotrue's background refresh timer from firing mid-test,
/// same as this file's existing `forgetAndSwitchToNextIfAny` test.
SupabaseClient _fakeAuthClient(
  Map<String, dynamic> Function(String refreshToken) handler,
) {
  return SupabaseClient(
    'https://example.supabase.co',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final refreshToken = body['refresh_token'] as String;
      final result = handler(refreshToken);
      final isError = result.containsKey('error_code');
      return http.Response(
        jsonEncode(result),
        isError ? 400 : 200,
        headers: const {'content-type': 'application/json'},
      );
    }),
  );
}

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

    // Regression: every row in AccountSwitcherSheet showed a fallback
    // initial instead of the account's real avatar, because this method
    // never stored one at all -- `StoredAccount.avatarUrl` stayed null for
    // every account regardless of what its `profiles.avatar_url` actually
    // was.
    test('also stores the session account\'s avatarUrl', () async {
      final session = Session(
        accessToken: 'at',
        tokenType: 'bearer',
        refreshToken: 'rt-captured',
        user: _fakeUser('u1'),
      );

      await repository.captureCurrentAccount(
        session: session,
        username: 'worapon',
        avatarUrl: 'https://example.com/avatar.png',
      );

      final accounts = await repository.loadAccounts();
      expect(accounts.single.avatarUrl, 'https://example.com/avatar.png');
    });

    // Regression: the Account Switcher's own row for the official WYNOS
    // account never showed VerifiedBadge -- same missing-field shape as
    // avatarUrl above, `StoredAccount.isVerified` stayed false for every
    // account regardless of `profiles.is_verified`.
    test('also stores the session account\'s isVerified', () async {
      final session = Session(
        accessToken: 'at',
        tokenType: 'bearer',
        refreshToken: 'rt-captured',
        user: _fakeUser('u1'),
      );

      await repository.captureCurrentAccount(
        session: session,
        username: 'wynos_',
        isVerified: true,
      );

      final accounts = await repository.loadAccounts();
      expect(accounts.single.isVerified, isTrue);
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

  group('switchTo', () {
    // Bug fix (2026-09-13, Founder report: "ระบบมันชอบเด้งออก"). Before
    // this fix, a stale target-account refresh token didn't just fail the
    // switch -- gotrue's own `_doRefresh` wipes whatever session was
    // active *before* the failed `setSession` call and broadcasts
    // `AuthChangeEvent.signedOut`, which `AuthGate`'s listener treats as
    // relevant and pops straight to WelcomeScreen. See this method's own
    // doc comment and `.wyn/tasks/bugs/` for the fix.
    test(
        'restores the previously active session instead of leaving the '
        'user signed out when the target account\'s stored token is stale',
        () async {
      const currentUserId = 'current-user';
      const currentInitialToken = 'rt-current-initial';
      const currentFreshToken = 'rt-current-fresh';
      const staleTargetToken = 'rt-target-stale';

      final client = _fakeAuthClient((refreshToken) {
        switch (refreshToken) {
          case currentInitialToken:
            // Establishes the "already signed in" session below.
            return _refreshSuccessJson(
              userId: currentUserId,
              refreshToken: currentFreshToken,
            );
          case currentFreshToken:
            // The restore attempt this fix makes, using the token
            // `switchTo` itself just persisted moments earlier.
            return _refreshSuccessJson(
              userId: currentUserId,
              refreshToken: currentFreshToken,
            );
          case staleTargetToken:
            return _refreshTokenNotFoundJson;
          default:
            fail('Unexpected refresh_token in request: $refreshToken');
        }
      });
      addTearDown(client.dispose);

      // Sign in as the account already active on this device.
      await client.auth.setSession(currentInitialToken);
      expect(client.auth.currentSession?.user.id, currentUserId);

      final signedOutEvents = <AuthChangeEvent>[];
      final sub = client.auth.onAuthStateChange.listen((state) {
        signedOutEvents.add(state.event);
      });
      addTearDown(sub.cancel);

      final target = _account('target-user', refreshToken: staleTargetToken);

      await expectLater(
        repository.switchTo(target, client),
        throwsA(anything),
      );

      // Let the signedOut/signedIn events (and this repository's own
      // restore call) finish propagating through the stream.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // The core assertion: the account that was active before the
      // failed switch is still the active session afterward -- the user
      // was never actually signed out, only the switch attempt failed.
      expect(client.auth.currentSession, isNotNull);
      expect(client.auth.currentSession?.user.id, currentUserId);

      // gotrue still broadcasts its own signedOut for the rejected
      // refresh internally; this fix's restore call (setSession with only
      // a refresh token) always routes through gotrue's own
      // tokenRefreshed path (see AccountSwitcherRepository's class-level
      // doc comment), never signedOut again -- documenting that the
      // *net* state a listener like AuthGate ends up on is still
      // signed-in, not the permanent flash-to-Welcome the original bug
      // caused.
      expect(signedOutEvents, contains(AuthChangeEvent.signedOut));
      expect(signedOutEvents.last, isNot(AuthChangeEvent.signedOut));
    });

    test('persists the new refresh token on a successful switch', () async {
      const currentUserId = 'current-user';
      const currentInitialToken = 'rt-current-initial';
      const targetUserId = 'target-user';
      const targetStoredToken = 'rt-target-stored';
      const targetRotatedToken = 'rt-target-rotated';

      final client = _fakeAuthClient((refreshToken) {
        switch (refreshToken) {
          case currentInitialToken:
            return _refreshSuccessJson(
              userId: currentUserId,
              refreshToken: currentInitialToken,
            );
          case targetStoredToken:
            return _refreshSuccessJson(
              userId: targetUserId,
              refreshToken: targetRotatedToken,
            );
          default:
            fail('Unexpected refresh_token in request: $refreshToken');
        }
      });
      addTearDown(client.dispose);

      await client.auth.setSession(currentInitialToken);
      await repository.upsertAccount(
        _account(currentUserId, refreshToken: currentInitialToken),
      );

      final target =
          _account(targetUserId, refreshToken: targetStoredToken);
      await repository.upsertAccount(target);

      await repository.switchTo(target, client);

      expect(client.auth.currentSession?.user.id, targetUserId);
      final stored = await repository.loadAccounts();
      expect(
        stored.firstWhere((a) => a.userId == targetUserId).refreshToken,
        targetRotatedToken,
      );
      // The account switched away from keeps its own (now-rotated by
      // gotrue) refresh token persisted too, not left pointing at the
      // single-use initial one.
      expect(
        stored.firstWhere((a) => a.userId == currentUserId).refreshToken,
        currentInitialToken,
      );
    });
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
