import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/notification/data/notification_settings.dart';
import 'package:wyn/features/notification/data/notification_settings_repository.dart';

/// A NotificationSettingsRepository whose network-touching methods are
/// overridden to just record what they were called with, instead of
/// making a real Supabase call. Mirrors RecordingBlockRepository
/// (WYN-027) -- see .wyn/learning/PATTERNS.md.
class RecordingNotificationSettingsRepository
    extends NotificationSettingsRepository {
  RecordingNotificationSettingsRepository({
    this.fetchSettingsResult = NotificationSettings.allEnabled,
    this.fetchSettingsError,
    this.updateCategoryError,
  }) : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchSettings] unless [fetchSettingsError] is set.
  NotificationSettings fetchSettingsResult;
  Object? fetchSettingsError;

  Object? updateCategoryError;

  int fetchSettingsCalls = 0;
  final List<(NotificationCategory, bool)> updateCategoryCalls = [];

  @override
  Future<NotificationSettings> fetchSettings() async {
    fetchSettingsCalls++;
    final error = fetchSettingsError;
    if (error != null) throw error;
    return fetchSettingsResult;
  }

  @override
  Future<void> updateCategory(NotificationCategory category, bool enabled) async {
    updateCategoryCalls.add((category, enabled));
    final error = updateCategoryError;
    if (error != null) throw error;
  }
}
