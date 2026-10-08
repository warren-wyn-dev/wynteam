import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const proxy = readFileSync(new URL("../proxy.ts", import.meta.url), "utf8");

test("maps.wynos.online root redirects to signed-in WYNOS Maps on wynos.online", () => {
  assert.match(proxy, /"maps\.wynos\.online": "https:\/\/wynos\.online\/maps"/);
  assert.match(proxy, /NextResponse\.redirect\(target, 307\)/);
  assert.doesNotMatch(proxy, /"maps\.wynos\.online": "\/maps"/);
});

test("food and merchant subdomains keep their root rewrites", () => {
  assert.match(proxy, /"food\.wynos\.online": "\/food"/);
  assert.match(proxy, /"merchant\.wynos\.online": "\/merchant"/);
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
