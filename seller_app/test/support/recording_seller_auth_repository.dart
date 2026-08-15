import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zoky_seller/features/auth/data/seller_auth_repository.dart';

/// A SellerAuthRepository whose network-touching members are overridden
/// with canned/controllable values instead of making a real Supabase
/// call. Mirrors RecordingProfileRepository (WYN Social,
/// `app/test/support/recording_profile_repository.dart`) -- see
/// .wyn/learning/PATTERNS.md, "subclass concrete repository เพื่อทำ
/// test double".
class RecordingSellerAuthRepository extends SellerAuthRepository {
  RecordingSellerAuthRepository({
    this.session,
    this.hasUsernameResult = true,
  }) : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  final Session? session;
  final bool hasUsernameResult;

  int setUsernameCalls = 0;

  @override
  Session? get currentSession => session;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<bool> hasUsername(String userId) async => hasUsernameResult;

  @override
  Future<bool> isUsernameAvailable(String username) async => true;

  @override
  Future<void> setUsername(String userId, String username) async {
    setUsernameCalls++;
  }
}
