// The authenticated Next.js Merchant route starts this engine explicitly.
// No app-shell service worker is registered and no second auth client is made.
{{flutter_js}}
{{flutter_build_config}}
// Replaced after compilation with the content-addressed, same-origin build.
_flutter.merchantAssetBase = "__MERCHANT_FLUTTER_ASSET_BASE__";
// The SDK engine has its own content address and stays cached across releases.
_flutter.merchantCanvasKitBase = "__MERCHANT_FLUTTER_CANVASKIT_BASE__";
