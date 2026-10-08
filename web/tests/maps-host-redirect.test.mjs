import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const proxy = readFileSync(new URL("../proxy.ts", import.meta.url), "utf8");

test("maps.wynos.online root rewrites to WYNOS Maps without leaving the domain", () => {
  assert.match(proxy, /"maps\\.wynos\\.online": "\\/maps"/);
  assert.match(proxy, /NextResponse\\.rewrite\\(url\\)/);
  assert.doesNotMatch(proxy, /"maps\\.wynos\\.online": "https:/);
});

test("food and merchant subdomains keep their root rewrites", () => {
  assert.match(proxy, /"food\.wynos\.online": "\/food"/);
  assert.match(proxy, /"merchant\.wynos\.online": "\/merchant"/);
});

test("Maps markers keep MapLibre's absolute positioning", () => {
  const css = readFileSync(new URL("../app/maps/maps-v3.css", import.meta.url), "utf8");
  assert.match(css, /\.wynos-maps-page \.maplibregl-marker\.wf-map-user-location,\s*\.wynos-maps-page \.maplibregl-marker\.wf-map-place-marker \{\s*position: absolute;/);
});
