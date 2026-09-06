import 'package:wyn/core/developer_access/developer_access_service.dart';

/// A DeveloperAccessService whose result is fully controlled by the test
/// instead of a real RPC call -- constructing the real class's default
/// (`DeveloperAccessService()`) touches `Supabase.instance.client.rpc(...)`
/// for real, which against this suite's placeholder project
/// (`https://example.supabase.co`, see fake_supabase_session.dart) hangs
/// `pumpAndSettle()` indefinitely rather than failing fast -- the same
/// class of bug WYN-113 found and fixed in widget_test.dart. Mirrors
/// RecordingAuthRepository/RecordingModerationRepository's own
/// "extend the real repository, override the network-touching bits"
/// shape -- see .wyn/learning/PATTERNS.md.
class RecordingDeveloperAccessService extends DeveloperAccessService {
  RecordingDeveloperAccessService({this.isDeveloperResult = false});

  bool isDeveloperResult;
  Object? isDeveloperErrorOverride;
  int isDeveloperAccountCalls = 0;

  @override
  Future<bool> isDeveloperAccount() async {
    isDeveloperAccountCalls++;
    final error = isDeveloperErrorOverride;
    if (error != null) throw error;
    return isDeveloperResult;
  }
}
