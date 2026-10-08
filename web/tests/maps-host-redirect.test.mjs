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
