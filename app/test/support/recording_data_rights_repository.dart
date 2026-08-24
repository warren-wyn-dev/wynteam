import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/settings/data/data_rights_repository.dart';

/// A DataRightsRepository whose network-touching methods are
/// overridden to just return canned data / record calls instead of
/// making a real Supabase call. Mirrors
/// RecordingNotificationSettingsRepository/
/// RecordingPlatformDocumentRepository -- see
/// .wyn/learning/PATTERNS.md.
class RecordingDataRightsRepository extends DataRightsRepository {
  RecordingDataRightsRepository({
    this.exportResult = '{"profile":{}}',
    this.exportError,
    this.deleteError,
  }) : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [exportMyData] unless [exportError] is set. Mutable
  /// (not final) so a single shared instance (this project's
  /// setUpAll convention) can be reused across testWidgets cases that
  /// each need a different canned result.
  String exportResult;
  Object? exportError;

  int exportMyDataCalls = 0;

  /// When set, [exportMyData] awaits this instead of
  /// resolving/throwing immediately -- lets a test control exactly
  /// when the export completes (e.g. via a Completer) to observe
  /// SettingsScreen's loading state, same "resolves immediately by
  /// default, unless a test needs to observe the in-progress state"
  /// shape as RecordingPlatformDocumentRepository.fetchLatestOverride.
  Future<void> Function()? exportOverride;

  int deleteMyAccountCalls = 0;
  Object? deleteError;

  @override
  Future<String> exportMyData() async {
    exportMyDataCalls++;
    if (exportOverride != null) {
      await exportOverride!();
    }
    final error = exportError;
    if (error != null) throw error;
    return exportResult;
  }

  @override
  Future<void> deleteMyAccount() async {
    deleteMyAccountCalls++;
    final error = deleteError;
    if (error != null) throw error;
  }
}
