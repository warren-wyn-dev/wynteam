import assert from "node:assert/strict";
import { createServer } from "node:http";
import { registerHooks } from "node:module";
import test from "node:test";

registerHooks({
  resolve(specifier, context, next) {
    if (specifier.startsWith("@/")) return next(new URL(`../${specifier.slice(2)}.ts`, import.meta.url).href, context);
    return next(specifier, context);
  },
});

// A fake Norswor Maps API whose answers depend on the query, like the real index:
// it knows shop names but not the province written after them.
const calls = [];
const rows = {
  "โลตัส": [
    { lat: "16.43", lon: "102.83", name: "โลตัส ขอนแก่น", display_name: "โลตัส ขอนแก่น" },
    { lat: "13.75", lon: "100.50", name: "โลตัส พระราม 4", display_name: "โลตัส พระราม 4" },
  ],
  "ขอนแก่น": [{ lat: "16.44", lon: "102.84", name: "ขอนแก่น", display_name: "ขอนแก่น" }],
  "ศรีนครินทร์": [{ lat: "16.47", lon: "102.82", name: "โรงพยาบาลศรีนครินทร์", display_name: "โรงพยาบาลศรีนครินทร์" }],
  "ล่ม": "fail",
};
const server = createServer((request, response) => {
  const url = new URL(request.url, "http://127.0.0.1");
  const q = url.searchParams.get("q");
  calls.push(q);
  const answer = rows[q];
  if (answer === "fail") { response.writeHead(500).end("{}"); return; }
  response.setHeader("Content-Type", "application/json");
  response.end(JSON.stringify(answer ?? []));
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
process.env.WYNOS_GEO_ORIGIN = `http://127.0.0.1:${server.address().port}/api/geo`;
const core = await import("../lib/server/wynos-maps-core.ts");
test.after(() => server.close());

test("a phrase that matches is answered with one call (nothing changes for it)", async () => {
  calls.length = 0;
  const places = await core.searchWynosGeo("ศรีนครินทร์");
  assert.equal(places.length, 1);
  assert.deepEqual(calls, ["ศรีนครินทร์"]);
});

test("name plus area finds the name, then the area, when the whole phrase finds nothing", async () => {
  calls.length = 0;
  const places = await core.searchWynosGeo("โลตัส ขอนแก่น");
  assert.deepEqual(calls, ["โลตัส ขอนแก่น", "โลตัส", "ขอนแก่น"]);
  assert.deepEqual(places.map((place) => place.name), ["โลตัส ขอนแก่น", "โลตัส พระราม 4", "ขอนแก่น"]);
});

test("a single unknown word is not retried", async () => {
  calls.length = 0;
  assert.deepEqual(await core.searchWynosGeo("ไม่มีคำนี้"), []);
  assert.deepEqual(calls, ["ไม่มีคำนี้"]);
});

test("nothing found at all returns an empty list after at most two extra calls", async () => {
  calls.length = 0;
  assert.deepEqual(await core.searchWynosGeo("ไม่มี คำนี้ เลย"), []);
  assert.deepEqual(calls, ["ไม่มี คำนี้ เลย", "ไม่มี คำนี้", "เลย"]);
});

test("a failing retry does not turn an empty answer into an error, a failing first call still does", async () => {
  calls.length = 0;
  assert.deepEqual(await core.searchWynosGeo("ว่าง ล่ม"), []);
  await assert.rejects(core.searchWynosGeo("ล่ม"));
});
