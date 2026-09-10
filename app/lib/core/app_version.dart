/// WYN-126 (Settings version label): the single source of truth for the
/// two version strings shown at the bottom of Settings -- see
/// `.wyn/company/VERSION_CONTROL.md` for what each build number means.
/// Every future version bump (a new stable release, a new build in
/// development behind WYN-125's developer allowlist) changes exactly
/// these two constants, nowhere else.
class AppVersion {
  AppVersion._();

  /// Shown to every regular (non-developer) account -- the current
  /// stable, publicly-shipped build.
  static const String stable = 'V1.0.0 Beta5';

  /// Shown only to a developer/internal test account (WYN-125's
  /// `DeveloperAccessService.isDeveloperAccount()`) -- the build
  /// currently in development behind that staged-rollout allowlist.
  static const String developerPreview = 'V1.0.0 Beta5';
}
