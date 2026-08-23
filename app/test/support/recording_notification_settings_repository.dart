import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/settings/data/notification_settings_repository.dart';

/// A NotificationSettingsRepository whose network-touching methods are
/// overridden to just return canned data instead of making a real
/// Supabase call. Mirrors RecordingProfileRepository -- see
/// .wyn/learning/PATTERNS.md.
class RecordingNotificationSettingsRepository
    extends NotificationSettingsRepository {
  RecordingNotificationSettingsRepository({
    this.settings = const NotificationSettings(),
    this.fetchException,
  }) : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetch] -- mutable (not final) so a single shared
  /// instance (this project's setUpAll convention -- see
  /// PATTERNS.md) can be reused across testWidgets cases that each
  /// need a different canned NotificationSettings, same "reassign a
  /// canned field per test" approach RecordingMuteRepository's
  /// isMutedResult already establishes.
  NotificationSettings settings;

  /// Thrown by [fetch] when set, instead of returning [settings].
  Exception? fetchException;

  /// Recorded (category, value) pairs [upsertCategory] was called
  /// with, in call order.
  final List<(String, bool)> upsertCategoryArgs = [];

  /// Thrown by [upsertCategory] when set, instead of succeeding.
  Exception? upsertCategoryException;

  /// When set, [upsertCategory] awaits this instead of
  /// resolving/throwing immediately -- lets a test control exactly
  /// when a specific category's save completes (e.g. via a
  /// Completer), to prove a different row stays interactive while one
  /// row's save is still in flight (Design Rule #1).
  Future<void> Function(String category, bool value)?
      upsertCategoryOverride;

  @override
  Future<NotificationSettings> fetch() async {
    if (fetchException != null) throw fetchException!;
    return settings;
  }

  @override
  Future<void> upsertCategory({
    required String category,
    required bool value,
  }) async {
    upsertCategoryArgs.add((category, value));
    if (upsertCategoryOverride != null) {
      await upsertCategoryOverride!(category, value);
    }
    if (upsertCategoryException != null) throw upsertCategoryException!;
  }
}
