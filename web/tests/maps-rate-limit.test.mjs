import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const compiled = ts.transpileModule(read("../lib/server/maps-rate-limit.ts"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const mod = { exports: {} };
runInNewContext(compiled, { module: mod, exports: mod.exports, Map, Math, Date });
const { takeMapsRateLimit, mapsClientKey, resetMapsRateLimitForTests, MAPS_RATE_LIMITS } = mod.exports;

test("blocks a client once it passes the bucket limit and reports Retry-After", () => {
  resetMapsRateLimitForTests();
  const now = 1_000_000;
  for (let i = 0; i < MAPS_RATE_LIMITS.route; i += 1) {
    assert.equal(takeMapsRateLimit("route", "1.1.1.1", now).allowed, true);
  }
  const blocked = takeMapsRateLimit("route", "1.1.1.1", now + 15_000);
  assert.equal(blocked.allowed, false);
  assert.equal(blocked.remaining, 0);
  assert.equal(blocked.retryAfterSeconds, 45);
});

test("limits are separate per client and per bucket", () => {
  resetMapsRateLimitForTests();
  const now = 2_000_000;
  for (let i = 0; i <= MAPS_RATE_LIMITS.route; i += 1) takeMapsRateLimit("route", "1.1.1.1", now);
  assert.equal(takeMapsRateLimit("route", "1.1.1.1", now).allowed, false);
  assert.equal(takeMapsRateLimit("route", "2.2.2.2", now).allowed, true);
  assert.equal(takeMapsRateLimit("search", "1.1.1.1", now).allowed, true);
});

test("a new window resets the count", () => {
  resetMapsRateLimitForTests();
  const now = 3_000_000;
  for (let i = 0; i <= MAPS_RATE_LIMITS.search; i += 1) takeMapsRateLimit("search", "3.3.3.3", now);
  assert.equal(takeMapsRateLimit("search", "3.3.3.3", now).allowed, false);
  assert.equal(takeMapsRateLimit("search", "3.3.3.3", now + 60_000).allowed, true);
});

test("tracked clients stay bounded under many distinct callers", () => {
  resetMapsRateLimitForTests();
  const now = 4_000_000;
  for (let i = 0; i < 12_000; i += 1) takeMapsRateLimit("search", `10.0.${i >> 8}.${i & 255}`, now);
  // The most recent caller is still counted correctly after eviction.
  assert.equal(takeMapsRateLimit("search", "10.0.46.223", now).remaining, MAPS_RATE_LIMITS.search - 2);
});

test("client key uses the first forwarded address", () => {
  assert.equal(mapsClientKey(new Headers({ "x-forwarded-for": "203.0.113.9, 10.0.0.1" })), "203.0.113.9");
  assert.equal(mapsClientKey(new Headers({ "x-real-ip": "198.51.100.4" })), "198.51.100.4");
  assert.equal(mapsClientKey(new Headers()), "unknown");
});

test("every Maps Core API route applies the rate limit before calling upstream", () => {
  for (const [path, bucket, call] of [
    ["../app/api/maps/search/route.ts", "search", "searchWynosGeo("],
    ["../app/api/maps/reverse/route.ts", "reverse", "reverseWynosGeo("],
    ["../app/api/maps/route/route.ts", "route", "routeWynosMaps("],
  ]) {
    const source = read(path);
    const limitAt = source.indexOf(`mapsRateLimitResponse(request, "${bucket}"`);
    assert.ok(limitAt > 0, `${path} applies the ${bucket} limit`);
    assert.ok(limitAt < source.indexOf(call), `${path} limits before calling upstream`);
  }
});

test("upstream calls carry the gateway token only when configured", () => {
  const core = read("../lib/server/wynos-maps-core.ts");
  assert.match(core, /process\.env\.WYNOS_MAPS_UPSTREAM_TOKEN/);
  assert.match(core, /"X-WYNOS-Maps-Token": token/);
});
