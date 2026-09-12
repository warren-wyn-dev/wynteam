import 'looped_thai_font_loader_stub.dart'
    if (dart.library.js_interop) 'looped_thai_font_loader_web.dart' as impl;

/// Loads the looped Thai fallback used by Flutter Web canvas text.
///
/// BrowserSystemText surfaces still render through the browser DOM and keep
/// using the visitor's device system font/emoji. This fallback only protects
/// the many ordinary Flutter Text widgets that have not been migrated to DOM
/// rendering and therefore cannot use an installed Thai system font on the
/// web canvas renderer.
Future<void> loadLoopedThaiFontForWeb() => impl.loadLoopedThaiFontForWeb();
