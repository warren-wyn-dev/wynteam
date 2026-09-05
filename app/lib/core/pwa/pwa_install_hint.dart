import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'pwa_display_mode_stub.dart'
    if (dart.library.js_interop) 'pwa_display_mode_web.dart' as pwa_display_mode;

/// Which "add to home screen" instructions (if any) apply to the browser
/// currently running this Flutter Web build. Both branches are manual
/// steps, not a one-tap install button: Safari has never implemented
/// `beforeinstallprompt` (it's a Chromium-only event) or any other
/// programmatic install trigger, so a button that only ever worked on
/// one of the two platforms would be more confusing than steps that
/// work on both. [unsupported] covers desktop browsers and anything
/// [defaultTargetPlatform] can't place on either -- "add this to your
/// home screen" isn't a coherent ask without one.
enum AddToHomeScreenGuidance { ios, android, unsupported }

/// Whether/how to prompt a *browser visitor* (this file only ever
/// matters for the Flutter Web build -- see [kIsWeb] on every call
/// site) to install WYNOS to their home screen. Founder feedback: users
/// didn't know WYNOS could be added like a real app icon at all.
class PwaInstallHint {
  const PwaInstallHint._();

  static AddToHomeScreenGuidance get guidance {
    if (!kIsWeb) return AddToHomeScreenGuidance.unsupported;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => AddToHomeScreenGuidance.ios,
      TargetPlatform.android => AddToHomeScreenGuidance.android,
      _ => AddToHomeScreenGuidance.unsupported,
    };
  }

  /// True once the visitor already opened WYNOS from the icon they
  /// added -- there is no "add to home screen" left to ask for. See
  /// pwa_display_mode_web.dart for how a browser actually reports this.
  static bool get isRunningAsInstalledApp =>
      kIsWeb && pwa_display_mode.isStandaloneDisplayMode();
}
