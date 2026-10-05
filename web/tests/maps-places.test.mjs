import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const compiled = ts.transpileModule(read("../lib/maps-places.ts"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const mod = { exports: {} };
runInNewContext(compiled, { module: mod, exports: mod.exports, JSON, Number, Math, URL, URLSearchParams, Array });
const {
  loadRecentPlaces, rememberRecentPlace, clearRecentPlaces, mapsShareUrl, parseMapsDeepLink, formatDistanceKm,
  MAPS_RECENTS_KEY, MAPS_RECENTS_LIMIT,
} = mod.exports;

// Values built inside the vm context come from another realm; compare plain copies.
const plain = (value) => JSON.parse(JSON.stringify(value));

function memoryStorage(initial = {}) {
  const data = new Map(Object.entries(initial));
  return {
    getItem: (key) => (data.has(key) ? data.get(key) : null),
    setItem: (key, value) => data.set(key, String(value)),
    removeItem: (key) => data.delete(key),
    data,
  };
}

const place = (name, i = 0) => ({ placeId: `p${i}`, name, address: "มหาสารคาม", latitude: 16.24 + i / 1000, longitude: 103.24, category: "restaurant" });

test("recents put the latest first, dedupe and stay short", () => {
  const storage = memoryStorage();
  rememberRecentPlace(storage, place("A", 1));
  rememberRecentPlace(storage, place("B", 2));
  const list = rememberRecentPlace(storage, place("A", 1));
  assert.deepEqual(plain(list.map((p) => p.name)), ["A", "B"]);
  for (let i = 0; i < 20; i += 1) rememberRecentPlace(storage, place(`P${i}`, 10 + i));
  assert.equal(loadRecentPlaces(storage).length, MAPS_RECENTS_LIMIT);
});

test("recents ignore bad data and storage failures", () => {
  assert.deepEqual(plain(loadRecentPlaces(memoryStorage({ [MAPS_RECENTS_KEY]: "{not json" }))), []);
  assert.deepEqual(plain(loadRecentPlaces(memoryStorage({ [MAPS_RECENTS_KEY]: JSON.stringify([{ name: "x", latitude: 999, longitude: 1 }, { name: "", latitude: 1, longitude: 1 }]) }))), []);
  const broken = { getItem() { throw new Error("blocked"); }, setItem() { throw new Error("blocked"); }, removeItem() { throw new Error("blocked"); } };
  assert.deepEqual(plain(loadRecentPlaces(broken)), []);
  // Saving fails quietly; the caller still gets the in-memory list for this visit.
  assert.equal(rememberRecentPlace(broken, place("A")).length, 1);
  clearRecentPlaces(broken);
  assert.deepEqual(plain(loadRecentPlaces(null)), []);
});

test("clear removes saved recents", () => {
  const storage = memoryStorage();
  rememberRecentPlace(storage, place("A"));
  clearRecentPlaces(storage);
  assert.deepEqual(plain(loadRecentPlaces(storage)), []);
});

test("share links round-trip through the deep-link parser", () => {
  const url = mapsShareUrl("https://wynos.online", 16.2458, 103.2496);
  assert.equal(url, "https://wynos.online/maps?lat=16.245800&lon=103.249600");
  assert.deepEqual(plain(parseMapsDeepLink(new URL(url).search)), { latitude: 16.2458, longitude: 103.2496 });
});

test("deep links reject missing or out-of-range coordinates", () => {
  assert.equal(parseMapsDeepLink(""), null);
  assert.equal(parseMapsDeepLink("?lat=16.2"), null);
  assert.equal(parseMapsDeepLink("?lat=&lon=103"), null);
  assert.equal(parseMapsDeepLink("?lat=95&lon=103"), null);
  assert.equal(parseMapsDeepLink("?lat=abc&lon=103"), null);
});

test("distance labels read naturally in Thai", () => {
  assert.equal(formatDistanceKm(0.004), "10 ม.");
  assert.equal(formatDistanceKm(0.354), "350 ม.");
  assert.equal(formatDistanceKm(1.26), "1.3 กม.");
  assert.equal(formatDistanceKm(23.4), "23 กม.");
  assert.equal(formatDistanceKm(null), null);
  assert.equal(formatDistanceKm(-1), null);
});
