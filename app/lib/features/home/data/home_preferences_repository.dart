import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches/upserts the current user's own `home_preferences` row
/// (WYN-072). No `userId` parameter anywhere -- RLS already scopes
/// every query to `auth.uid()`, same posture as
/// NotificationSettingsRepository (WYN-044)/SavedRepository (WYN-013).
///
/// Currently holds exactly one preference: whether the Home Feed's
/// first-time explainer banner (SPEC.md Section 4.2) has been
/// permanently dismissed. Kept as its own small table/repository rather
/// than folding into `profiles` or `notification_settings` -- see
/// supabase/schema.sql's `public.home_preferences` doc comment.
class HomePreferencesRepository {
  HomePreferencesRepository(this._client);

  final SupabaseClient _client;

  /// A user who has never dismissed the banner has no row here at all --
  /// that's the normal starting state, so this defaults to `false`
  /// (banner shown) either way, same "no row = default" posture as
  /// [NotificationSettingsRepository].
  Future<bool> fetchExplainerBannerDismissed() async {
    final row = await _client
        .from('home_preferences')
        .select('explainer_banner_dismissed')
        .maybeSingle();
    return row?['explainer_banner_dismissed'] as bool? ?? false;
  }

  /// Permanently dismisses the explainer banner for the current account.
  /// `onConflict: 'user_id'` so the very first dismiss both creates the
  /// row and sets this field in a single call -- no separate "create the
  /// row" step needed, same shape as
  /// NotificationSettingsRepository.upsertCategory.
  Future<void> dismissExplainerBanner() async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('home_preferences').upsert(
      {'user_id': userId, 'explainer_banner_dismissed': true},
      onConflict: 'user_id',
    );
  }
}
