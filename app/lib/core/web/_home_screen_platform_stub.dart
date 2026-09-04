// WYN-107 -- the non-web half of home_screen_platform.dart's conditional
// import (native iOS/Android, and critically `flutter test`'s own VM
// target -- see that file's own doc comment). None of `matchMedia`/
// `navigator.standalone`/`navigator.userAgent` exist outside a browser,
// so every signal here returns its safe, fail-closed default rather than
// a real value.

bool matchesStandaloneDisplayMode() => false;

bool? iosNavigatorStandalone() => null;

String userAgent() => '';
