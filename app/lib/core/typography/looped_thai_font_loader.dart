import 'looped_thai_font_loader_stub.dart'
    if (dart.library.js_interop) 'looped_thai_font_loader_web.dart' as impl;

/// Loads the looped Thai fallback used by Flutter Web.
///
/// Native Apple builds keep using the platform text stack. Flutter Web's
/// canvas renderer cannot read fonts installed on the visitor's device, so
/// the web implementation loads an OFL-licensed Thai fallback explicitly.
Future<void> loadLoopedThaiFontForWeb() => impl.loadLoopedThaiFontForWeb();
