import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import ts from "typescript";

const source = readFileSync(new URL("../proxy.ts", import.meta.url), "utf8");
function router(flag) {
  const output = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
  const exports = {};
  const next = { next: () => ({ kind: "next" }), rewrite: (url) => ({ kind: "rewrite", url: url.toString() }), redirect: (url, code) => ({ kind: "redirect", url: url.toString(), code }) };
  new Function("require", "exports", "process", output)((name) => { assert.equal(name, "next/server"); return { NextResponse: next }; }, exports, { env: { ZOKY_MERCHANT_FLUTTER_ENABLED: flag } });
  return exports.proxy;
}
function request(host, path = "/") {
  const url = new URL(`https://${host}${path}`);
  url.clone = () => new URL(url);
  return { headers: new Headers({ host }), nextUrl: url };
}

test("Merchant Flutter cutover is off by default and only the exact reviewed flag enables it", () => {
  for (const value of [undefined, "0", "true", "yes", ""]) {
    assert.equal(router(value)(request("merchant.wynos.online")).url, "https://merchant.wynos.online/merchant");
  }
  assert.equal(router("1")(request("merchant.wynos.online")).url, "https://merchant.wynos.online/merchant/flutter");
});
test("Merchant root cutover preserves the query and leaves legacy auth/deep links untouched", () => {
  const proxy = router("1");
  assert.equal(proxy(request("merchant.wynos.online", "/?order=abc")).url, "https://merchant.wynos.online/merchant/flutter?order=abc");
  for (const path of ["/merchant", "/merchant/login", "/merchant/reset-password", "/merchant-flutter/main.dart.js", "/sw.js"]) {
    assert.equal(proxy(request("merchant.wynos.online", path)).kind, "next");
  }
});
test("enabling Merchant Flutter does not switch Food, Social or Maps", () => {
  const proxy = router("1");
  assert.equal(proxy(request("food.wynos.online")).url, "https://food.wynos.online/food");
  assert.equal(proxy(request("wynos.online")).kind, "next");
  assert.equal(proxy(request("maps.wynos.online")).url, "https://wynos.online/maps");
  assert.equal(proxy(request("food.wynos.online", "/login")).url, "https://food.wynos.online/food/login");
});
test("the embedded page keeps the existing JS auth owner and has a working legacy fallback", () => {
  const component = readFileSync(new URL("../components/merchant/merchant-flutter-app.tsx", import.meta.url), "utf8");
  assert.match(component, /DeveloperRouteGate signedOutPath="\/merchant\/login"/);
  assert.match(component, /key=\{context.userId\}/);
  assert.match(component, /bridge\.dispose\(\)/);
  assert.match(component, /removeView\(viewId\)/);
  assert.match(component, /href="\/merchant"/);
  const bootstrap = readFileSync(new URL("../merchant_flutter/web/flutter_bootstrap.js", import.meta.url), "utf8");
  assert.doesNotMatch(bootstrap, /\.loader\.load\(|serviceWorker\.register/);
});

test("installed Flutter Merchant launches the authenticated host and keeps the existing PWA identity", () => {
  const manifest = readFileSync(new URL("../app/merchant/flutter/manifest.webmanifest/route.ts", import.meta.url), "utf8");
  const page = readFileSync(new URL("../app/merchant/flutter/page.tsx", import.meta.url), "utf8");
  assert.match(manifest, /merchantManifest\(\)/);
  assert.match(manifest, /start_url: "\/merchant\/flutter"/);
  assert.match(page, /manifest: "\/merchant\/flutter\/manifest.webmanifest"/);
  assert.doesNotMatch(manifest, /id:|scope:/);
});
