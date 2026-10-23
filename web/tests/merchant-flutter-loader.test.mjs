import assert from "node:assert/strict";
import test from "node:test";

let sequence = 0;
function browser(t, { failScript = false } = {}) {
  const previousWindow = globalThis.window, previousDocument = globalThis.document;
  const scripts = [], configurations = [], initializations = [];
  const app = { addView() { return 7; }, removeView() {} };
  globalThis.window = {
    setTimeout, clearTimeout,
    _flutter: { loader: { async load(options) {
      configurations.push(options.config);
      await options.onEntrypointLoaded({ async initializeEngine(options) {
        initializations.push(options); return { async runApp() { return app; } };
      } });
    } } },
  };
  globalThis.document = {
    createElement() { return { dataset: {} }; },
    head: { appendChild(script) { scripts.push(script); queueMicrotask(() => failScript ? script.onerror() : script.onload()); } },
  };
  t.after(() => { globalThis.window = previousWindow; globalThis.document = previousDocument; });
  return { scripts, configurations, initializations, app };
}
async function loader() { return import(`../lib/merchant-flutter-loader.ts?test=${sequence++}`); }

test("the engine is loaded once with fixed same-origin entrypoint and assets", async (t) => {
  const b = browser(t); const { loadMerchantFlutterApp } = await loader();
  const [a, second] = await Promise.all([loadMerchantFlutterApp(), loadMerchantFlutterApp()]);
  assert.equal(a, b.app); assert.equal(second, a); assert.equal(b.scripts.length, 1);
  assert.equal(b.scripts[0].src, "/merchant-flutter/flutter_bootstrap.js");
  assert.deepEqual(b.configurations, [{ entrypointBaseUrl: "/merchant-flutter/", assetBase: "/merchant-flutter/", canvasKitBaseUrl: "/merchant-flutter/canvaskit/" }]);
  assert.deepEqual(b.initializations, [{ multiViewEnabled: true, assetBase: "/merchant-flutter/", canvasKitBaseUrl: "/merchant-flutter/canvaskit/" }]);
});
test("a failed bundle is reported and never re-executes a second Dart entrypoint", async (t) => {
  const b = browser(t, { failScript: true }); const { loadMerchantFlutterApp } = await loader();
  await assert.rejects(loadMerchantFlutterApp(), /merchant_flutter_load_failed/);
  await assert.rejects(loadMerchantFlutterApp(), /merchant_flutter_load_failed/);
  assert.equal(b.scripts.length, 1);
});
