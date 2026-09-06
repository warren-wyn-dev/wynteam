import 'open_in_new_tab_stub.dart'
    if (dart.library.js_interop) 'open_in_new_tab_web.dart' as impl;

/// Opens [path] (relative to the site root, e.g. `/add-to-home.html`) in
/// a new browser tab. No-op on native builds -- callers only reach this
/// after [PwaInstallHint] has already gated on `kIsWeb`, but the stub is
/// safe to call unconditionally regardless.
void openInNewTab(String path) => impl.openInNewTab(path);
