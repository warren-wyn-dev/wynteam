/// Non-web default (native iOS/Android, and `flutter test`'s VM target,
/// which cannot import `dart:js_interop`/`package:web` at all) --
/// every call site already gates on `kIsWeb` first (see
/// [open_in_new_tab.dart]'s own doc comment), so this branch is never
/// actually reached; it only has to exist so the conditional import
/// always resolves to something that compiles.
void openInNewTab(String path) {}
