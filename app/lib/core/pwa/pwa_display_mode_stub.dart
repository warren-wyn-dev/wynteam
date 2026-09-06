/// Non-web default (native iOS/Android, and `flutter test`'s VM target,
/// which cannot import `dart:js_interop`/`package:web` at all) --
/// [PwaInstallHint] already gates every caller of this on `kIsWeb`
/// first, so this branch is never actually reached; it only has to
/// exist so the conditional import below always resolves to something
/// that compiles.
bool isStandaloneDisplayMode() => false;
