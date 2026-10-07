import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

function compile(path) {
  const source = readFileSync(new URL(path, import.meta.url), "utf8")
    .replace('import type { MapsRoute, MapsTravelMode } from "@/lib/maps-routing";', "");
  return ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
}

const mod = { exports: {} };
runInNewContext(compile("../lib/maps-ors.ts"), {
  module: mod,
  exports: mod.exports,
  Number,
  Math,
  Array,
  Object,
});
const { orsProfileForCosting, normalizeOrsGeoJson, normalizeOrsGeoJsonRoutes } = mod.exports;

const plain = (value) => JSON.parse(JSON.stringify(value));

test("ORS maps WYNOS travel modes to supported profiles", () => {
  assert.equal(orsProfileForCosting("auto"), "driving-car");
  assert.equal(orsProfileForCosting("motorcycle"), "driving-car");
  assert.equal(orsProfileForCosting("pedestrian"), "foot-walking");
  assert.equal(orsProfileForCosting("bicycle"), "cycling-regular");
  assert.equal(orsProfileForCosting("airplane"), null);
});

test("ORS GeoJSON normalizes into WYNOS route data", () => {
  const route = normalizeOrsGeoJson({
    features: [{
      properties: {
        summary: { distance: 4250, duration: 620 },
        segments: [{
          steps: [
            { instruction: "Head north", distance: 1200, duration: 180, way_points: [0, 1] },
            { instruction: "Turn right", distance: 3050, duration: 440, way_points: [1, 2] },
          ],
        }],
      },
      geometry: {
        type: "LineString",
        coordinates: [[103.2496, 16.2458], [103.251, 16.2465], [103.255, 16.25]],
      },
    }],
  }, "motorcycle");

  assert.ok(route);
  assert.equal(route.distanceKm, 4.25);
  assert.equal(route.durationSeconds, 620);
  assert.deepEqual(plain(route.coordinates), [[103.2496, 16.2458], [103.251, 16.2465], [103.255, 16.25]]);
  assert.deepEqual(plain(route.steps), [
    {
      instruction: "Head north",
      distanceKm: 1.2,
      durationSeconds: 180,
      beginShapeIndex: 0,
      endShapeIndex: 1,
      coordinate: [103.2496, 16.2458],
    },
    {
      instruction: "Turn right",
      distanceKm: 3.05,
      durationSeconds: 440,
      beginShapeIndex: 1,
      endShapeIndex: 2,
      coordinate: [103.251, 16.2465],
    },
  ]);
});

test("ORS GeoJSON exposes multiple route alternatives", () => {
  const routes = normalizeOrsGeoJsonRoutes({
    features: [
      {
        properties: { summary: { distance: 4200, duration: 600 }, segments: [] },
        geometry: { type: "LineString", coordinates: [[103.2, 16.2], [103.21, 16.21]] },
      },
      {
        properties: { summary: { distance: 4600, duration: 640 }, segments: [] },
        geometry: { type: "LineString", coordinates: [[103.2, 16.2], [103.22, 16.215]] },
      },
    ],
  }, "auto");
  assert.equal(routes.length, 2);
  assert.equal(routes[0].distanceKm, 4.2);
  assert.equal(routes[1].durationSeconds, 640);
});

test("ORS rejects invalid route payloads", () => {
  assert.equal(normalizeOrsGeoJson({}, "auto"), null);
  assert.equal(normalizeOrsGeoJson({
    features: [{
      properties: { summary: { distance: null, duration: 20 } },
      geometry: { coordinates: [[100, 13], [100.1, 13.1]] },
    }],
  }, "auto"), null);
  assert.equal(normalizeOrsGeoJson({
    features: [{
      properties: { summary: { distance: 100, duration: 20 } },
      geometry: { coordinates: [[100, 13]] },
    }],
  }, "auto"), null);
});
