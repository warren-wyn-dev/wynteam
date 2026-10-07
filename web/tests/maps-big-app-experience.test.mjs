import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");

test("standalone Maps uses floating search and expanded category shortcuts", () => {
  const map = read("../components/food/food-delivery-map-picker.tsx");
  const css = read("../app/maps/maps-v4.css");
  for (const category of ["ร้านอาหาร", "คาเฟ่", "หอพัก", "ร้านค้า", "โรงพยาบาล", "ปั๊มน้ำมัน", "ATM"]) {
    assert.ok(map.includes(category), `missing quick category: ${category}`);
  }
  assert.ok(map.includes('className="wf-map-floating-search"'));
  assert.ok(css.includes(".wf-map-floating-search"));
});

test("Maps requests and renders route alternatives without changing quota-safe manual reroute", () => {
  const map = read("../components/food/food-delivery-map-picker.tsx");
  const routeApi = read("../app/api/maps/route/route.ts");
  const core = read("../lib/server/wynos-maps-core.ts");
  assert.ok(map.includes("parseWynosRoutes"));
  assert.ok(map.includes("routeAlternatives"));
  assert.ok(map.includes("alternatives: !options?.origin"));
  assert.ok(routeApi.includes("body.alternatives === true"));
  assert.ok(core.includes("alternative_routes"));
  assert.ok(core.includes("target_count: 2"));
  assert.ok(map.includes("คำนวณใหม่"));
});

test("Maps has full-screen navigation camera and WYNOS Food place integration", () => {
  const map = read("../components/food/food-delivery-map-picker.tsx");
  const css = read("../app/maps/maps-v4.css");
  assert.ok(map.includes("position.coords.heading"));
  assert.ok(map.includes("pitch: 46"));
  assert.ok(map.includes("wf-map-navigation-top"));
  assert.ok(map.includes("wf-map-navigation-bottom"));
  assert.ok(css.includes(".wf-map-picker.is-navigating"));
  assert.ok(map.includes("สั่งอาหารได้ใน WYNOS Food"));
  assert.ok(map.includes("wf-map-food-action"));
  assert.ok(map.includes("is-verified"));
  assert.ok(map.includes("is-merchant"));
});
