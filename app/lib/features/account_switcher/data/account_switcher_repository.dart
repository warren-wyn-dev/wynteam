import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'stored_account.dart';

/// Thin key/value abstraction so this repository's own tests can inject
/// an in-memory fake instead of touching a real platform Keychain/
/// Keystore via method channels -- same "extend/inject the real thing,
/// swap the storage/network-touching bits" shape as every other
/// Recording* test double in this app, just expressed as an interface
/// here since [FlutterSecureStorage] itself isn't meant to be subclassed
/// for that purpose.
abstract class AccountSecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class _PlatformSecureStore implements AccountSecureStore {
  const _PlatformSecureStore();
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Thrown by [AccountSwitcherRepository.upsertAccount] when adding a
/// genuinely new account would exceed [AccountSwitcherRepository.maxAccounts].
class TooManyAccountsException implements Exception {}

/// Backs WYNOS's multi-account switching (Instagram/Twitter-style: add
/// up to [maxAccounts] accounts on one device, switch between them
/// instantly without re-authenticating). Stores each account's Supabase
/// refresh token in the platform Keychain/Keystore (never
/// shared_preferences, unlike this app's other, non-sensitive local
/// prefs) -- see [captureCurrentAccount]/[switchTo]'s own doc comments
/// for how a refresh token is kept valid across switches despite
/// Supabase rotating it on every use.
class AccountSwitcherRepository {
  AccountSwitcherRepository({AccountSecureStore? store})
      : _store = store ?? const _PlatformSecureStore();

  final AccountSecureStore _store;

  static const _storageKey = 'wynos_switcher_accounts';

  /// Instagram's own limit -- keeps this device's local storage bounded
  /// without needing a more elaborate LRU eviction policy.
  static const maxAccounts = 5;

  Future<List<StoredAccount>> loadAccounts() async {
    final raw = await _store.read(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((entry) => StoredAccount.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save(List<StoredAccount> accounts) {
    return _store.write(
      _storageKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }

  /// Adds [account], or -- if [StoredAccount.userId] is already stored --
  /// refreshes its cached fields in place (including the refresh token,
  /// which would otherwise go stale the moment this account is actually
  /// switched to; see [switchTo]). [TooManyAccountsException] is only
  /// thrown when adding a genuinely *new* account past [maxAccounts];
  /// updating an existing entry never counts against the limit.
  Future<void> upsertAccount(StoredAccount account) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.userId == account.userId);
    if (index == -1) {
      if (accounts.length >= maxAccounts) throw TooManyAccountsException();
      await _save([...accounts, account]);
    } else {
      final updated = [...accounts];
      updated[index] = account;
      await _save(updated);
    }
  }

  /// Best-effort convenience for [startSyncingActiveSession] -- unlike
  /// [upsertAccount], this never creates a new entry and never throws: a
  /// session whose account was never explicitly captured (still
  /// mid-onboarding, or a guest -- see [captureCurrentAccount]) simply
  /// has nothing to update.
  Future<void> updateRefreshToken(String userId, String refreshToken) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.userId == userId);
    if (index == -1) return;
    final updated = [...accounts];
    updated[index] = updated[index].copyWith(refreshToken: refreshToken);
    await _save(updated);
  }

  Future<void> removeAccount(String userId) async {
    final accounts = await loadAccounts();
    await _save(accounts.where((a) => a.userId != userId).toList());
  }

  /// Called once, for the app's whole lifetime, from `main.dart` --
  /// keeps whichever account is currently active fresh in storage every
  /// time its access token (and, with it, its single-use refresh token)
  /// auto-rotates, so switching away from it and back later never hits
  /// an already-consumed token. Deliberately a no-op for any account not
  /// already captured (see [updateRefreshToken]) -- capturing a
  /// brand-new account into the switcher at all happens exactly once,
  /// explicitly, only after AuthGate has confirmed it's fully onboarded
  /// (see [captureCurrentAccount]), not from this general-purpose
  /// listener.
  void startSyncingActiveSession(SupabaseClient client) {
    client.auth.onAuthStateChange.listen((state) {
      if (state.event != AuthChangeEvent.signedIn &&
          state.event != AuthChangeEvent.tokenRefreshed) {
        return;
      }
      final session = state.session;
      final refreshToken = session?.refreshToken;
      if (session == null || session.user.isAnonymous || refreshToken == null) {
        return;
      }
      unawaited(updateRefreshToken(session.user.id, refreshToken));
    });
  }

  /// AuthGate's explicit capture point -- called exactly once an account
  /// is confirmed fully onboarded and about to show RootShell.
  /// Fire-and-forget by design (see that call site): a failure here must
  /// never block reaching Home, and hitting [TooManyAccountsException]
  /// the moment a 6th account signs in on a device that already has 5
  /// switchable is expected and harmless -- that account still gets to
  /// use the app normally, it just isn't added to the switcher.
  Future<void> captureCurrentAccount({
    required Session session,
    required String username,
    String? displayName,
    String? avatarUrl,
  }) async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null) return;
    try {
      await upsertAccount(StoredAccount(
        userId: session.user.id,
        refreshToken: refreshToken,
        username: username,
        email: session.user.email,
        displayName: displayName,
        avatarUrl: avatarUrl,
      ));
    } on TooManyAccountsException {
      // Intentionally silent -- see doc comment above.
    }
  }

  /// Switches the active Supabase session to [account]: persists
  /// whatever account is *currently* active first (its stored refresh
  /// token may be stale if it rotated since being captured), exchanges
  /// [account]'s own stored refresh token for a fresh session via
  /// `setSession`, then immediately re-saves the new refresh token that
  /// call returns (Supabase single-use-rotates refresh tokens, so the
  /// old one stops working the moment this succeeds).
  ///
  /// Deliberately never calls `signOut()` on the account being switched
  /// away from -- confirmed against the Supabase Auth server's own
  /// logout handler that even `SignOutScope.local` revokes that
  /// session's refresh token server-side, which would destroy the very
  /// thing quick-switching relies on. The account switched away from
  /// simply stops being the client's current session; its own session
  /// stays valid on the server until it's actually switched back to.
  Future<void> switchTo(StoredAccount account, SupabaseClient client) async {
    final current = client.auth.currentSession;
    final currentRefreshToken = current?.refreshToken;
    if (current != null &&
        !current.user.isAnonymous &&
        currentRefreshToken != null) {
      await updateRefreshToken(current.user.id, currentRefreshToken);
    }

    final response = await client.auth.setSession(account.refreshToken);
    final newRefreshToken = response.session?.refreshToken;
    if (newRefreshToken != null) {
      await updateRefreshToken(account.userId, newRefreshToken);
    }
  }

  /// Removes [userId] from the switcher -- call this right after a real
  /// sign-out/account-deletion has already revoked its session (see
  /// SettingsScreen/DeleteAccountScreen) -- and, if any other account
  /// remains on this device, switches straight to it instead of falling
  /// through to WelcomeScreen: same "logging out lands you on another
  /// already-added account" behavior as Instagram/Twitter. Returns true
  /// if it switched to another account.
  Future<bool> forgetAndSwitchToNextIfAny(
    String userId,
    SupabaseClient client,
  ) async {
    await removeAccount(userId);
    final remaining = await loadAccounts();
    if (remaining.isEmpty) return false;
    await switchTo(remaining.first, client);
    return true;
  }
}
