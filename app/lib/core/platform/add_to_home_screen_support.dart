import 'add_to_home_screen_support_stub.dart'
    if (dart.library.js_interop) 'add_to_home_screen_support_web.dart'
    as impl;

/// Whether the Home banner / side menu link for "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก"
/// should offer to install WYNOS -- true only on the web build, and only
/// when it isn't already running as an installed PWA (checked via the
/// `(display-mode: standalone)` media query, which every major mobile
/// browser -- including iOS Safari since iOS 11 -- sets once a page has
/// been added to the home screen). Native iOS/Android builds are already
/// the installed app, so this is always false there; conditional-imported
/// so the non-web stub (which never touches `package:web`'s JS interop
/// types) is the one that actually compiles into those builds.
bool shouldOfferAddToHomeScreen() => impl.shouldOfferAddToHomeScreen();

/// Opens [path] (relative to the site root, e.g. `/add-to-home.html`) in
/// a new browser tab. No-ops on non-web builds -- call sites only reach
/// this after [shouldOfferAddToHomeScreen] has already gated on
/// `kIsWeb`-equivalent, but the stub is safe to call unconditionally
/// regardless.
void openAddToHomeScreenGuide() => impl.openAddToHomeScreenGuide();
