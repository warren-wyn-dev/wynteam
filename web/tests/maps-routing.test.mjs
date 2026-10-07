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
const { decodeValhallaPolyline, parseWynosRoute, formatRouteDuration, formatRouteDistance } = mod.exports;

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

test("route response normalizes summary and joins leg shapes", () => {
  const first = [[103.2496, 16.2458], [103.251, 16.2465]];
  const second = [[103.251, 16.2465], [103.255, 16.25]];
  const route = parseWynosRoute({
    trip: {
      summary: { length: 4.2, time: 620 },
      legs: [{ shape: encode(first) }, { shape: encode(second) }],
    },
  }, "motorcycle");
  assert.ok(route);
  assert.equal(route.distanceKm, 4.2);
  assert.equal(route.durationSeconds, 620);
  assert.deepEqual(plain(route.coordinates), [[103.2496, 16.2458], [103.251, 16.2465], [103.255, 16.25]]);
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
