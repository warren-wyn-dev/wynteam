import assert from "node:assert/strict";
import test from "node:test";

import { freshGpsLocation } from "../lib/food-gps.ts";

// The helper only needs window.setTimeout/clearTimeout and navigator.geolocation.
function installGeolocation(watchPosition) {
  const cleared = [];
  globalThis.window = { setTimeout, clearTimeout };
  Object.defineProperty(globalThis, "navigator", {
    configurable: true,
    value: { geolocation: { watchPosition, clearWatch: (id) => cleared.push(id) } },
  });
  return cleared;
}

const fix = (latitude, longitude, accuracy) => ({ coords: { latitude, longitude, accuracy } });

test("rejects when the device has no geolocation", async () => {
  globalThis.window = { setTimeout, clearTimeout };
  Object.defineProperty(globalThis, "navigator", { configurable: true, value: {} });
  await assert.rejects(freshGpsLocation(50), /ไม่รองรับการระบุตำแหน่ง/);
});

test("resolves immediately on an accurate fix and stops watching", async () => {
  const cleared = installGeolocation((success) => {
    queueMicrotask(() => success(fix(16.18, 103.3, 12)));
    return 7;
  });
  const result = await freshGpsLocation(500);
  assert.deepEqual(result.location, { latitude: 16.18, longitude: 103.3 });
  assert.equal(result.accuracyMeters, 12);
  assert.deepEqual(cleared, [7]);
});

test("keeps the most accurate coarse fix when GPS never gets precise", async () => {
  installGeolocation((success) => {
    queueMicrotask(() => {
      success(fix(16.1, 103.1, 900));
      success(fix(16.2, 103.2, 150));
      success(fix(16.3, 103.3, 400));
    });
    return 1;
  });
  const result = await freshGpsLocation(40);
  assert.deepEqual(result.location, { latitude: 16.2, longitude: 103.2 });
  assert.equal(result.accuracyMeters, 150);
});

test("ignores impossible coordinates", async () => {
  installGeolocation((success) => {
    queueMicrotask(() => {
      success(fix(200, 103, 5));
      success(fix(16.5, 103.5, 30));
    });
    return 2;
  });
  const result = await freshGpsLocation(500);
  assert.deepEqual(result.location, { latitude: 16.5, longitude: 103.5 });
});

test("denied permission rejects with the Precise Location hint", async () => {
  installGeolocation((_success, failure) => {
    queueMicrotask(() => failure({ code: 1 }));
    return 3;
  });
  await assert.rejects(freshGpsLocation(500), /อนุญาตตำแหน่งที่แน่นอน/);
});

test("other GPS errors point the customer to place search", async () => {
  installGeolocation((_success, failure) => {
    queueMicrotask(() => failure({ code: 2 }));
    return 4;
  });
  await assert.rejects(freshGpsLocation(500), /ค้นหาสถานที่/);
});
