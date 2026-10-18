import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const proxy = readFileSync(new URL("../proxy.ts", import.meta.url), "utf8");

test("maps.wynos.online root redirects to signed-in WYNOS Maps on wynos.online", () => {
  assert.match(proxy, /"maps\.wynos\.online": "https:\/\/wynos\.online\/maps"/);
  assert.match(proxy, /NextResponse\.redirect\(target, 307\)/);
  assert.doesNotMatch(proxy, /"maps\.wynos\.online": "\/maps"/);
});

// ZOKY-114: run proxy.ts against a minimal NextResponse/NextRequest stand-in.
function loadProxy() {
  const transpile = (path) => ts.transpileModule(readFileSync(new URL(path, import.meta.url), "utf8"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const origin = { exports: {} };
  runInNewContext(transpile("../lib/food-origin.ts"), { module: origin, exports: origin.exports, Set, URL });
  const NextResponse = {
    next: () => ({ kind: "next" }),
    redirect: (url, status) => ({ kind: "redirect", url: String(url), status }),
    rewrite: (url) => ({ kind: "rewrite", url: String(url) }),
  };
  const modules = { "next/server": { NextResponse }, "@/lib/food-origin": origin.exports };
  const mod = { exports: {} };
  runInNewContext(transpile("../proxy.ts"), { module: mod, exports: mod.exports, URL, require: (name) => modules[name] });
  return mod.exports;
}

function run(href) {
  const { proxy } = loadProxy();
  const url = new URL(href);
  const nextUrl = Object.assign(new URL(url), { clone: () => new URL(url) });
  return proxy({ headers: { get: (key) => (key === "host" ? url.host : null) }, nextUrl });
}

test("zoky.wynos.online serves the Food (ZOKY) app at its root and keeps deep links", () => {
  assert.deepEqual(run("https://zoky.wynos.online/"), { kind: "rewrite", url: "https://zoky.wynos.online/food" });
  assert.deepEqual(run("https://zoky.wynos.online/?store=3f2b8c1a-9d4e-4a6b-8c2d-1e5f7a9b0c3d"), {
    kind: "rewrite", url: "https://zoky.wynos.online/food?store=3f2b8c1a-9d4e-4a6b-8c2d-1e5f7a9b0c3d",
  });
  assert.deepEqual(run("https://zoky.wynos.online/food/auth/callback?code=abc"), { kind: "next" });
  assert.deepEqual(run("https://merchant.wynos.online/"), { kind: "rewrite", url: "https://merchant.wynos.online/merchant" });
});

test("zoky.wynos.online/login and /signup open Food's own auth pages, only on the Food host", () => {
  assert.deepEqual(run("https://zoky.wynos.online/login?x=1"), { kind: "redirect", url: "https://zoky.wynos.online/food/login?x=1", status: 307 });
  assert.deepEqual(run("https://zoky.wynos.online/signup/step-1"), { kind: "redirect", url: "https://zoky.wynos.online/food/signup", status: 307 });
  assert.deepEqual(run("https://wynos.online/login"), { kind: "next" });
});

test("every food.wynos.online URL moves to zoky.wynos.online with the same path and query (307)", () => {
  for (const path of [
    "/", "/s/k7m2qx", "/?store=3f2b8c1a-9d4e-4a6b-8c2d-1e5f7a9b0c3d", "/?order=WF0001", "/?promo=CODE",
    "/food/login", "/food/signup", "/food/auth/callback?code=abc", "/?order=WF0001&stripe=success",
  ]) {
    assert.deepEqual(run(`https://food.wynos.online${path}`), { kind: "redirect", url: `https://zoky.wynos.online${path}`, status: 307 }, path);
  }
});

test("wynos.online/food* moves to zoky.wynos.online, /food itself to the root", () => {
  assert.deepEqual(run("https://wynos.online/food?promo=CODE"), { kind: "redirect", url: "https://zoky.wynos.online/?promo=CODE", status: 307 });
  assert.deepEqual(run("https://www.wynos.online/food/login"), { kind: "redirect", url: "https://zoky.wynos.online/food/login", status: 307 });
  assert.deepEqual(run("https://wynos.online/"), { kind: "next" });
  assert.deepEqual(run("https://wynos.online/foodie"), { kind: "next" });
});

test("proxy runs on every page of the old Food host but not on build assets or API calls", () => {
  assert.match(proxy, /matcher: \[\s*"\/", "\/food", "\/food\/:path\*", "\/login", "\/signup", "\/signup\/:path\*",/);
  assert.match(proxy, /\{ source: "\/\(\(\?!_next\/\|api\/\)\.\*\)", has: \[\{ type: "host", value: "food\.wynos\.online" \}\] \}/);
  assert.doesNotMatch(proxy, /zoky\.online/);
});

test("Maps markers keep MapLibre's absolute positioning", () => {
  const css = readFileSync(new URL("../app/maps/maps-v3.css", import.meta.url), "utf8");
  assert.match(css, /\.wynos-maps-page \.maplibregl-marker\.wf-map-user-location,\s*\.wynos-maps-page \.maplibregl-marker\.wf-map-place-marker \{\s*position: absolute;/);
});

test("standalone Maps hides manual zoom controls but retains pinch-to-zoom", () => {
  const map = readFileSync(new URL("../components/food/food-delivery-map-picker.tsx", import.meta.url), "utf8");
  assert.doesNotMatch(map, /className="wf-map-zoom-control"/);
  assert.doesNotMatch(map, /aria-label="ซูมเข้า"/);
  assert.doesNotMatch(map, /aria-label="ซูมออก"/);
  assert.match(map, /touchZoomRotate: true/);
});

test("standalone Maps requests a fresh high-accuracy GPS fix and reports coarse fixes", () => {
  const map = readFileSync(new URL("../components/food/food-delivery-map-picker.tsx", import.meta.url), "utf8");
  assert.match(map, /function freshMapsGpsLocation\(/);
  assert.match(map, /watchPosition\(/);
  assert.match(map, /enableHighAccuracy: true, maximumAge: 0/);
  assert.match(map, /freshMapsGpsLocation\(\)/);
  assert.match(map, /setGpsMessage\(/);
  assert.match(map, /setUserLocation\(next\);[\s\S]*?moveTo\(next\);/);
});

test("standalone Maps never overlays its destination pin on the current GPS dot", () => {
  const map = readFileSync(new URL("../components/food/food-delivery-map-picker.tsx", import.meta.url), "utf8");
  // An explicit manual/search/deep-linked selection has a red pin. Merely
  // opening Maps or locating yourself does not, so the GPS blue dot is clear.
  assert.match(map, /\(!standalone \|\| \(chosen && !currentLocationSelected && !navigating && !directionsTarget\)\)/);
  assert.match(map, /setUserLocation\(next\);[\s\S]*?moveTo\(next\);[\s\S]*?setCurrentLocationSelected\(true\);/);
  assert.match(map, /const \[chosen, setChosen\] = useState\(Boolean\(initialLocation\)\)/);
});

test("Maps launch UI has clear saved places, distinctive POI markers and readable near labels", () => {
  const map = readFileSync(new URL("../components/food/food-delivery-map-picker.tsx", import.meta.url), "utf8");
  const css = readFileSync(new URL("../app/maps/maps-v6.css", import.meta.url), "utf8");
  assert.match(map, /className="wf-map-saved-shortcut" aria-label="สถานที่ที่บันทึก"/);
  assert.match(map, /<Bookmark size=\{21\}/);
  assert.doesNotMatch(map, /<span>W<\/span>/);
  assert.match(map, /const showLabel = selected \|\| \(standalone \? \(mapZoom >= 15\.5/);
  assert.match(map, /M19 10c0 5-7 11-7 11S5 15 5 10a7 7 0 0 1 14 0Z/);
  assert.match(css, /wf-map-place-marker\.has-label:not\(\.is-selected\) \.wf-map-place-label/);
  assert.match(css, /min-height: 44px/);
});

test("Maps reports the browser GPS accuracy without showing a red selection pin over the blue dot", () => {
  const source = readFileSync(new URL("../components/food/food-delivery-map-picker.tsx", import.meta.url), "utf8");
  const css = readFileSync(new URL("../app/maps/maps-v6.css", import.meta.url), "utf8");
  assert.match(source, /const \[gpsAccuracyMeters, setGpsAccuracyMeters\] = useState<number \| null>\(null\)/);
  assert.match(source, /setGpsAccuracyMeters\(Math\.ceil\(fix\.accuracyMeters\)\)/);
  assert.match(source, /currentLocationSelected && gpsAccuracyMeters !== null/);
  assert.match(source, /\(!standalone \|\| \(chosen && !currentLocationSelected && !navigating && !directionsTarget\)\)/);
  assert.match(css, /\.wynos-maps-page \.wf-map-gps-accuracy/);
});

test("Maps uses real labeled road tiles and distinct icons for hospitals, fuel and ATMs", () => {
  const source = readFileSync(new URL("../components/food/food-delivery-map-picker.tsx", import.meta.url), "utf8");
  const style = JSON.parse(readFileSync(new URL("../public/maps/wynos-green.json", import.meta.url), "utf8"));
  for (const name of ["highway-name-minor", "highway-name-path", "poi_r1", "poi_r7"]) {
    const layer = style.layers.find((entry) => entry.id === name);
    assert.ok(layer, `missing named map style layer: ${name}`);
    assert.ok(JSON.stringify(layer.layout?.["text-field"] ?? "").includes("name"), `place names must be sourced from real tiles: ${name}`);
    assert.ok(source.includes(`["${name}", `), `standalone Maps should show named ${name} earlier`);
  }
  assert.match(source, /map\.setLayerZoomRange\(layerId, minzoom, 24\)/);
  for (const kind of ["hospital", "fuel", "atm"]) {
    assert.ok(source.includes(`kind === "${kind}"`), `missing marker glyph ${kind}`);
  }
});
