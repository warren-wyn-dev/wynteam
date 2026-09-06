import 'package:web/web.dart' as web;

/// Real web implementation -- see [add_to_home_screen_support.dart] for
/// the public contract both this and the stub satisfy.
bool shouldOfferAddToHomeScreen() =>
    !web.window.matchMedia('(display-mode: standalone)').matches;

void openAddToHomeScreenGuide() {
  web.window.open('/add-to-home.html', '_blank');
}
