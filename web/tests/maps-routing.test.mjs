import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const compiled = ts.transpileModule(read("../lib/maps-routing.ts"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const mod = { exports: {} };
runInNewContext(compiled, { module: mod, exports: mod.exports, Number, Math, Array, Object });
const { decodeValhallaPolyline, parseWynosRoute, nearestRoutePosition, routeRemainingDistanceMeters, routeSegmentBoundsForDistance, nextRouteStep, formatRouteDuration, formatRouteDistance } = mod.exports;

const plain = (value) => JSON.parse(JSON.stringify(value));

function encode(points, precision = 6) {
  const factor = 10 ** precision;
  let previousLat = 0;
  let previousLon = 0;
  let output = "";
  const append = (delta) => {
    let value = delta < 0 ? ~(delta << 1) : (delta << 1);
    while (value >= 0x20) {
      output += String.fromCharCode((0x20 | (value & 0x1f)) + 63);
      value >>= 5;
    }
    output += String.fromCharCode(value + 63);
  };
  for (const [lon, lat] of points) {
    const nextLat = Math.round(lat * factor);
    const nextLon = Math.round(lon * factor);
    append(nextLat - previousLat);
    append(nextLon - previousLon);
    previousLat = nextLat;
    previousLon = nextLon;
  }
  return output;
}

test("Valhalla polyline6 decodes longitude/latitude coordinates", () => {
  const points = [[103.2496, 16.2458], [103.251, 16.2465], [103.255, 16.25]];
  assert.deepEqual(plain(decodeValhallaPolyline(encode(points))), points);
});

test("route response normalizes summary, steps and joined leg shapes", () => {
  const first = [[103.2496, 16.2458], [103.251, 16.2465]];
  const second = [[103.251, 16.2465], [103.255, 16.25]];
  const route = parseWynosRoute({
    trip: {
      summary: { length: 4.2, time: 620 },
      legs: [
        {
          shape: encode(first),
          maneuvers: [{ instruction: "ตรงไป", length: 1.2, time: 180, begin_shape_index: 0, end_shape_index: 1 }],
        },
        {
          shape: encode(second),
          maneuvers: [{ instruction: "เลี้ยวขวา", length: 3, time: 440, begin_shape_index: 0, end_shape_index: 1 }],
        },
      ],
    },
  }, "motorcycle");
  assert.ok(route);
  assert.equal(route.distanceKm, 4.2);
  assert.equal(route.durationSeconds, 620);
  assert.deepEqual(plain(route.coordinates), [[103.2496, 16.2458], [103.251, 16.2465], [103.255, 16.25]]);
  assert.deepEqual(plain(route.steps), [
    {
      instruction: "ตรงไป",
      distanceKm: 1.2,
      durationSeconds: 180,
      beginShapeIndex: 0,
      endShapeIndex: 1,
      coordinate: [103.2496, 16.2458],
    },
    {
      instruction: "เลี้ยวขวา",
      distanceKm: 3,
      durationSeconds: 440,
      beginShapeIndex: 1,
      endShapeIndex: 2,
      coordinate: [103.251, 16.2465],
    },
  ]);
});


test("navigation helpers preserve forward progress and advance maneuvers at boundaries", () => {
  const route = {
    distanceKm: 1,
    durationSeconds: 120,
    mode: "pedestrian",
    coordinates: [[100, 13], [100.001, 13], [100.002, 13]],
    steps: [
      { instruction: "ตรงไป", distanceKm: 0.5, durationSeconds: 60, beginShapeIndex: 0, endShapeIndex: 1, coordinate: [100, 13] },
      { instruction: "เลี้ยวซ้าย", distanceKm: 0.5, durationSeconds: 60, beginShapeIndex: 1, endShapeIndex: 2, coordinate: [100.001, 13] },
    ],
  };
  const match = nearestRoutePosition({ latitude: 13.0001, longitude: 100.0012 }, route.coordinates);
  assert.ok(match);
  assert.ok(match.distanceMeters > 5 && match.distanceMeters < 20);
  assert.ok(match.routeProgress >= 1);
  assert.equal(nextRouteStep(route, 0, 0.2)?.instruction, "ตรงไป");
  assert.equal(nextRouteStep(route, 0, 0.8)?.instruction, "เลี้ยวซ้าย");
  assert.equal(nextRouteStep(route, 1, 0)?.instruction, "เลี้ยวซ้าย");

  const crossing = [[100, 13], [100.001, 13], [100.001, 13.001], [100, 13.001], [100, 13]];
  const unrestricted = nearestRoutePosition({ latitude: 12.9999, longitude: 100.0005 }, crossing);
  const forwardOnly = nearestRoutePosition(
    { latitude: 12.9999, longitude: 100.0005 },
    crossing,
    { minSegmentIndex: 2 },
  );
  assert.equal(unrestricted?.segmentIndex, 0);
  assert.equal(forwardOnly?.segmentIndex, 3);
});

test("route matching window is bounded by along-route distance, not segment count", () => {
  const coordinates = [[100, 13], [100.001, 13], [100.002, 13], [100.003, 13], [100.004, 13]];
  const tight = routeSegmentBoundsForDistance(coordinates, 0, 0, 20, 150);
  assert.equal(tight.minSegmentIndex, 0);
  assert.equal(tight.maxSegmentIndex, 1);

  const wider = routeSegmentBoundsForDistance(coordinates, 1, 0.5, 80, 260);
  assert.ok(wider.minSegmentIndex <= 1);
  assert.ok(wider.maxSegmentIndex >= 3);
});

test("remaining route distance requires progress near the route end before arrival", () => {
  const coordinates = [[100, 13], [100.001, 13], [100.002, 13]];
  const early = routeRemainingDistanceMeters(coordinates, 0, 0.9);
  const late = routeRemainingDistanceMeters(coordinates, 1, 0.9);
  assert.ok(early > 100);
  assert.ok(late > 5 && late < 20);
});

test("invalid route payload is rejected", () => {
  assert.equal(parseWynosRoute({}, "auto"), null);
  assert.equal(parseWynosRoute({ trip: { summary: { length: 1, time: 60 }, legs: [{ shape: "?" }] } }, "auto"), null);
  for (const bad of [null, false, "", "1.2"]) {
    assert.equal(parseWynosRoute({
      trip: {
        summary: { length: bad, time: 60 },
        legs: [{ shape: encode([[103.2496, 16.2458], [103.251, 16.2465]]) }],
      },
    }, "auto"), null);
    assert.equal(parseWynosRoute({
      trip: {
        summary: { length: 1.2, time: bad },
        legs: [{ shape: encode([[103.2496, 16.2458], [103.251, 16.2465]]) }],
      },
    }, "auto"), null);
  }
});

test("route labels are concise in Thai", () => {
  assert.equal(formatRouteDuration(620), "10 นาที");
  assert.equal(formatRouteDuration(3900), "1 ชม. 5 นาที");
  assert.equal(formatRouteDistance(0.34), "340 ม.");
  assert.equal(formatRouteDistance(8.26), "8.3 กม.");
});
