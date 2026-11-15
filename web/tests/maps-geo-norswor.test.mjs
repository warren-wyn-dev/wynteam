import assert from "node:assert/strict";
import { createServer } from "node:http";
import { registerHooks } from "node:module";
import test from "node:test";

// Resolve the "@/..." alias used by app code, so the real module is imported.
registerHooks({
  resolve(specifier, context, next) {
    if (specifier.startsWith("@/")) return next(new URL(`../${specifier.slice(2)}.ts`, import.meta.url).href, context);
    return next(specifier, context);
  },
});

const TOKEN = "contract-test-token-not-real";
const seen = [];
const server = createServer((request, response) => {
  const url = new URL(request.url, "http://127.0.0.1");
  seen.push({ path: url.pathname, token: request.headers["x-wynos-maps-token"] });
  if (request.headers["x-wynos-maps-token"] !== TOKEN) { response.writeHead(401).end("{}"); return; }
  response.setHeader("Content-Type", "application/json");
  if (url.pathname === "/api/geo/search") {
    response.end(JSON.stringify([{
      lat: "16.4719", lon: "102.8236", name: "โรงพยาบาลศรีนครินทร์", display_name: "โรงพยาบาลศรีนครินทร์",
      osm_type: "node", osm_id: 1, address: {}, address_quality: "name-only", licence: "ODbL",
    }]));
  } else if (url.pathname === "/api/geo/reverse") {
    response.end(url.searchParams.get("lat") === "0" ? "{}" : JSON.stringify({
      lat: "16.4719", lon: "102.8236", name: "ร้านตัวอย่าง", display_name: "ร้านตัวอย่าง", address_quality: "nearest-named-place", distance_m: 20,
    }));
  } else response.writeHead(404).end("{}");
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
process.env.WYNOS_GEO_ORIGIN = `http://127.0.0.1:${server.address().port}/api/geo`;
process.env.WYNOS_MAPS_UPSTREAM_TOKEN = TOKEN;
const core = await import("../lib/server/wynos-maps-core.ts");
test.after(() => server.close());

test("search accepts Norswor Maps rows and sends the token to the /api/geo path", async () => {
  const places = await core.searchWynosGeo("ศรีนครินทร์");
  assert.deepEqual(places, [{ name: "โรงพยาบาลศรีนครินทร์", address: "โรงพยาบาลศรีนครินทร์", lat: 16.4719, lon: 102.8236 }]);
  const call = seen.at(-1);
  assert.equal(call.path, "/api/geo/search");
  assert.equal(call.token, TOKEN);
});

test("reverse accepts a Norswor Maps row and treats {} as no place", async () => {
  const found = await core.reverseWynosGeo(16.47, 102.82);
  assert.equal(found.length, 1);
  assert.equal(found[0].name, "ร้านตัวอย่าง");
  assert.deepEqual(await core.reverseWynosGeo(0, 0), []);
  assert.equal(seen.at(-1).path, "/api/geo/reverse");
});

test("a wrong token is an upstream failure, never an empty success", async () => {
  const previous = process.env.WYNOS_MAPS_UPSTREAM_TOKEN;
  process.env.WYNOS_MAPS_UPSTREAM_TOKEN = "wrong";
  try {
    await assert.rejects(() => core.searchWynosGeo("x"), /401/);
  } finally {
    process.env.WYNOS_MAPS_UPSTREAM_TOKEN = previous;
  }
});
