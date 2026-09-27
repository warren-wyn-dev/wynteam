import 'package:flutter/foundation.dart';

/// WYN-126 (Settings version label): the single source of truth for the
/// two version strings shown at the bottom of Settings -- see
/// `.wyn/company/VERSION_CONTROL.md` for what each build number means.
/// Every future version bump (a new stable release, a new build in
/// development behind WYN-125's developer allowlist) changes exactly
/// these two constants, nowhere else.
class AppVersion {
  AppVersion._();

  // Founder (2026-09-27): each platform is developed and named on its own:
  // "Wynos Web Beta 1", "Wynos Android v1.0.0 Beta 1", "Wynos iOS v1.0.0 Beta 1".
  static const String android = 'Wynos Android v1.0.0 Beta 1';
  static const String ios = 'Wynos iOS v1.0.0 Beta 1';

  /// Shown to every regular (non-developer) account: this platform's name.
  static String get stable =>
      defaultTargetPlatform == TargetPlatform.iOS ? ios : android;

  /// Shown only to a developer/internal test account (WYN-125's
  /// `DeveloperAccessService.isDeveloperAccount()`). App development is
  /// paused (2026-09-19), so nothing newer is in development: developers
  /// see the same name.
  static String get developerPreview => stable;
}
