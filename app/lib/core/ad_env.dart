/// Compile-time AdMob configuration for WYN-106 (Native In-Feed Ads,
/// Home feed "สำหรับคุณ") -- read the same way [Env]/[PushEnv] read
/// theirs: `--dart-define`, never a checked-in file/secret.
///
/// Founder has not supplied a real AdMob App ID / native ad unit id at
/// the time this was implemented. An unconfigured build (every CI run,
/// every `flutter test`, every dev's local `flutter run` without these
/// defines) gets empty strings, so [isConfigured] is false and the
/// whole feature -- see
/// `app/lib/features/home/presentation/widgets/home_native_ad_card.dart`
/// and `_HomeFeedScreenState._buildBodySlivers`'s own `adsEnabled` gate
/// in home_feed_screen.dart -- collapses to "no ad-slots exist at all",
/// per the design spec's explicit requirement (Handoff item 6): "ต้องมี
/// toggle/flag ปิดโฆษณาทั้งหมดได้ง่ายๆ ... ป้องกันไม่ให้ CI/dev build
/// พังเพราะพยายามยิง request หา AdMob จริง". See
/// .wyn/docs/design/wyn-106-feed-native-ads.md.
///
/// [nativeAdUnitId] alone is deliberately not enough to enable ads --
/// [appId] must also be set, since a real deploy also needs the native
/// AndroidManifest.xml `<meta-data android:name=
/// "com.google.android.gms.ads.APPLICATION_ID">` / Info.plist
/// `GADApplicationIdentifier`, and a registered platform `NativeAdFactory`
/// (Android)/`FLTNativeAdFactory` (iOS) rendering the "โฆษณา"-labelled
/// card layout the design spec's "Components" section describes.
/// None of that native platform work is part of this change -- see
/// home_native_ad_card.dart's own doc comment for why, which mirrors
/// this repo's existing precedent for `firebase_core`/`firebase_messaging`
/// in pubspec.yaml (added, and safely no-op'd via a try/catch in
/// main.dart, before the Founder had real `google-services.json`/
/// `GoogleService-Info.plist` to drop in).
class AdEnv {
  const AdEnv._();

  static const appId = String.fromEnvironment('ADMOB_APP_ID');
  static const nativeAdUnitId =
      String.fromEnvironment('ADMOB_NATIVE_AD_UNIT_ID');

  /// Whether this build carries enough configuration to ever attempt
  /// loading a real ad. False for every unconfigured build (CI,
  /// `flutter test`, a bare local `flutter run`) -- see the file-level
  /// doc comment.
  static bool get isConfigured => appId.isNotEmpty && nativeAdUnitId.isNotEmpty;
}
