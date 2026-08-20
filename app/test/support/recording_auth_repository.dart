import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/auth/data/auth_repository.dart';

/// An AuthRepository whose network-touching methods are overridden to
/// simulate the *real* `isUsernameAvailable`'s behavior (WYN-024's design
/// spec, R3) instead of making a real Supabase call: a username that's
/// already taken by any profile -- including the caller's own current one
/// -- reports unavailable, exactly like the real `.eq('username',
/// username)` query would (it has no self-exclusion built in). Tests that
/// need to prove Edit Profile's client-side short-circuit must supply
/// [takenUsernames] including the profile's own current username, the
/// same way the real DB row for that username would otherwise trip up an
/// un-guarded call. Mirrors RecordingProfileRepository -- see
/// .wyn/learning/PATTERNS.md.
class RecordingAuthRepository extends AuthRepository {
  RecordingAuthRepository({Set<String> takenUsernames = const {}})
      : takenUsernames = Set.of(takenUsernames),
        super(SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          // See RecordingProfileRepository's identical comment -- avoids
          // leaking a real GoTrue auto-refresh Timer.periodic into tests
          // that construct this directly inside a testWidgets() body.
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  final Set<String> takenUsernames;

  int isUsernameAvailableCalls = 0;
  final List<String> isUsernameAvailableArgs = [];

  int setUsernameCalls = 0;
  final List<String> setUsernameArgs = [];

  @override
  Future<bool> isUsernameAvailable(String username) async {
    isUsernameAvailableCalls++;
    isUsernameAvailableArgs.add(username);
    return !takenUsernames.contains(username);
  }

  @override
  Future<void> setUsername(String userId, String username) async {
    setUsernameCalls++;
    setUsernameArgs.add(username);
    if (takenUsernames.contains(username)) {
      throw UsernameTakenException();
    }
  }
}
