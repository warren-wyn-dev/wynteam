import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import ts from "typescript";

const source = readFileSync(new URL("../proxy.ts", import.meta.url), "utf8");
const foodOrigin = {};
new Function("exports", ts.transpileModule(readFileSync(new URL("../lib/food-origin.ts", import.meta.url), "utf8"), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText)(foodOrigin);
function router(flag, legacyFoodFlag) {
  const output = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
  const exports = {};
  const next = { next: () => ({ kind: "next" }), rewrite: (url) => ({ kind: "rewrite", url: url.toString() }), redirect: (url, code) => ({ kind: "redirect", url: url.toString(), code }) };
  new Function("require", "exports", "process", output)((name) => { if (name === "@/lib/food-origin") return foodOrigin; assert.equal(name, "next/server"); return { NextResponse: next }; }, exports, { env: { ZOKY_MERCHANT_FLUTTER_ENABLED: flag, ZOKY_LEGACY_FOOD_REDIRECT: legacyFoodFlag } });
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
  for (const path of ["/merchant/login", "/merchant/reset-password", "/merchant-flutter/main.dart.js", "/sw.js"]) {
    assert.equal(proxy(request("merchant.wynos.online", path)).kind, "next");
  }
});
test("Stripe Connect callbacks retain the existing payment setup handler", () => {
  for (const action of ["return", "refresh"]) {
    const query = `?payments=${action}&store=store-id`;
    assert.equal(router("1")(request("merchant.wynos.online", "/" + query)).url, "https://merchant.wynos.online/merchant" + query);
  }
});
test("enabling Merchant Flutter does not switch Food, Social or Maps", () => {
  const proxy = router("1");
  assert.equal(proxy(request("food.wynos.online")).url, "https://food.wynos.online/food");
  assert.equal(proxy(request("zoky.wynos.online")).url, "https://zoky.wynos.online/food");
  for (const path of ["/", "/login", "/sw.js", "/food/orders?order=test"]) {
    assert.deepEqual(router("1", "1")(request("food.wynos.online", path)), router("0", "1")(request("food.wynos.online", path)));
  }
  assert.equal(proxy(request("wynos.online")).kind, "next");
  assert.equal(proxy(request("maps.wynos.online")).url, "https://wynos.online/maps");
  assert.equal(proxy(request("food.wynos.online", "/login")).url, "https://food.wynos.online/food/login");
});
test("the embedded page keeps the existing JS auth owner and has a working legacy fallback", () => {
  const component = readFileSync(new URL("../components/merchant/merchant-flutter-app.tsx", import.meta.url), "utf8");
  assert.match(component, /DeveloperRouteGate signedOutPath="\/merchant\/login"/);
  assert.match(component, /key=\{context.userId\}/);
  assert.match(component, /dynamic<DeveloperRouteContext>/);
  assert.doesNotMatch(component, /import.*merchant-flutter-bridge/);
  const authenticated = readFileSync(new URL("../components/merchant/merchant-flutter-authenticated.tsx", import.meta.url), "utf8");
  assert.match(authenticated, /bridge\.dispose\(\)/);
  assert.match(authenticated, /removeView\(viewId\)/);
  assert.match(authenticated, /removeEventListener\("message", wake\)/);
  assert.match(authenticated, /href="\/merchant\?legacy=1"/);
  assert.match(component, /href="\/merchant\?legacy=1"/);
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


test("login returns and installed Merchant entries open Flutter with a deliberate legacy escape", () => {
  const proxy = router("1");
  assert.equal(proxy(request("merchant.wynos.online", "/merchant?order=abc&store=xyz")).url,
    "https://merchant.wynos.online/merchant/flutter?order=abc&store=xyz");
  assert.equal(proxy(request("merchant.wynos.online", "/merchant")).code, 307);
  for (const path of ["/merchant?legacy=1", "/merchant?payments=return", "/merchant?payments=refresh"]) {
    assert.equal(proxy(request("merchant.wynos.online", path)).kind, "next");
  }
  assert.equal(router("0")(request("merchant.wynos.online", "/merchant")).kind, "next");
  assert.equal(proxy(request("wynos.online", "/merchant")).kind, "next");
});

test("the original-store escape link bypasses the Flutter entry redirect; store tools stay in Flutter", () => {
  const home = readFileSync(new URL("../merchant_flutter/lib/screens/merchant_home.dart", import.meta.url), "utf8");
  assert.match(home, /resolve\('\/merchant\?legacy=1'\)/);
  // Founder 2026-11-01: feedback, help, store settings and notifications no longer jump to legacy tools.
  assert.doesNotMatch(home, /merchant-tool/);
  const proxy = router("1");
  assert.equal(proxy(request("merchant.wynos.online", "/merchant?legacy=1&merchant-tool=finance&merchant-store=00000000-0000-4000-8000-000000000001")).kind, "next");
});
