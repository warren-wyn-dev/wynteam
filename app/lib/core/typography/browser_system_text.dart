// WYNOS uses ordinary Flutter text on every platform.
//
// Native iOS/Android therefore keep their OS typography, while Flutter Web
// receives the bundled WYNWebNotoThai family from WynTheme. Keeping one
// renderer avoids DOM platform-view layout/semantics differences in social UI.
export 'browser_system_text_stub.dart';
