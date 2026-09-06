/// Non-web fallback for [add_to_home_screen_support.dart] -- selected by
/// its conditional export whenever `dart.library.js_interop` isn't
/// available (native iOS/Android builds). Both always no-op: a native
/// build already *is* the installed app, so there is nothing to offer.
bool shouldOfferAddToHomeScreen() => false;

void openAddToHomeScreenGuide() {}
