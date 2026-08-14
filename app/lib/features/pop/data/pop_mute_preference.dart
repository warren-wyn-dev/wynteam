import 'package:shared_preferences/shared_preferences.dart';

const _mutedPrefKey = 'pop_muted';

/// Shared by PopFeedScreen and any other screen that plays a Pop clip
/// (e.g. the single-clip view opened from a Home Pop card) so the user's
/// last mute/unmute choice is remembered consistently everywhere, not
/// just within one screen. See .wyn/docs/design/wyn-006-pop.md.
///
/// Defaults to false (sound on) the very first time WYN is ever opened.
Future<bool> loadPopMutedPreference() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_mutedPrefKey) ?? false;
}

Future<void> savePopMutedPreference(bool muted) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_mutedPrefKey, muted);
}
