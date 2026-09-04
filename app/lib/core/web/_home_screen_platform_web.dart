// WYN-107 -- the real, web-only half of home_screen_platform.dart's
// conditional import. Only ever compiled into an actual web build (see
// that file's own doc comment on the `dart.library.js_interop` guard);
// every function here is called exclusively from behind that file's own
// try/catch fail-closed wrappers, but each still guards itself too so a
// bad read here degrades to a safe default rather than throwing.
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// iOS Safari's own non-standard `navigator.standalone` -- not part of
/// the WebIDL surface `package:web`'s typed bindings cover (it's an
/// Apple-only extension, never standardized), so this is the one place
/// this file drops to a raw `dart:js_interop` static-interop getter
/// instead of `package:web`'s typed `Navigator` API.
@JS('navigator.standalone')
external JSBoolean? get _rawIosNavigatorStandalone;

bool matchesStandaloneDisplayMode() {
  try {
    return web.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}

bool? iosNavigatorStandalone() {
  try {
    return _rawIosNavigatorStandalone?.toDart;
  } catch (_) {
    return null;
  }
}

String userAgent() {
  try {
    return web.window.navigator.userAgent;
  } catch (_) {
    return '';
  }
}
