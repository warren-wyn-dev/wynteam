import 'package:shared_preferences/shared_preferences.dart';

const _dismissedPrefKeyPrefix = 'home_explainer_banner_dismissed_';

/// WYNOS Home reference spec, section 4.2 / 5 -- the first-time
/// explainer banner is dismissed permanently (not per-session) the
/// moment the user taps its X. Keyed by [userId] (not a single global
/// flag) so a second account signing into the same device still sees
/// the banner once of its own -- the spec's "persist per-account"
/// requirement. Same free-function + SharedPreferences shape as
/// pop_mute_preference.dart; no server-side sync needed for a single
/// local boolean like that existing precedent.
Future<bool> loadHomeExplainerBannerDismissed(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('$_dismissedPrefKeyPrefix$userId') ?? false;
}

Future<void> saveHomeExplainerBannerDismissed(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('$_dismissedPrefKeyPrefix$userId', true);
}
