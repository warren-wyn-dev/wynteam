// "หน้าจอรับออเดอร์" and unaccepted-order reminders (Founder 2026-10-06).
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");

test("order screen keeps the screen awake and takes the lock again when Merchant returns", () => {
  const lib = read("../lib/merchant-order-screen.ts");
  assert.match(lib, /wakeLock!?\.request\("screen"\)/);
  assert.match(lib, /document\.addEventListener\("visibilitychange", onVisible\)/);
  assert.match(lib, /window\.addEventListener\("pointerdown", onTap\)/);
  assert.match(lib, /if \(sentinel && !sentinel\.released\) void sentinel\.release\(\)/, "released when turned off");
  assert.match(lib, /useSyncExternalStore\(subscribe, orderScreenSupported, \(\) => false\)/, "server render says unsupported (no hydration mismatch)");
});

test("turning the mode on is the tap that unlocks and tests the order sound", () => {
  const screen = read("../components/merchant/merchant-order-screen.tsx");
  assert.match(screen, /setOn\(true\);\s*\/\/[^\n]*\n\s*const played = await previewMerchantOrderSound\(\);/);
  assert.match(screen, /role="switch"/);
  assert.match(screen, /aria-checked=\{on\}/);
  const app = read("../components/merchant/wynos-merchant-app.tsx");
  assert.match(app, /<MerchantOrderScreenCard onMessage=\{onMessage\} \/>/);
  assert.match(app, /\{store \? <MerchantOrderScreenBar soundReady=\{soundReady\} \/> : null\}/);
  const settings = read("../components/merchant/merchant-notification-settings.tsx");
  assert.match(settings, /<MerchantOrderScreenCard onMessage=\{onMessage\} \/>/);
});

test("unaccepted orders are re-notified each minute, at most 5 times, without touching food_orders", () => {
  const sql = read("../../supabase/migrations_wynos_merchant_order_reminders_v1.sql");
  assert.match(sql, /o\.status = 'pending_acceptance'\s+and o\.payment_status in \('submitted', 'paid'\)/);
  assert.match(sql, /coalesce\(r\.sent, 0\) < 5/);
  assert.match(sql, /o\.created_at > now\(\) - interval '3 hours'/);
  assert.match(sql, /'WYNOS Merchant · ออเดอร์ #' \|\| v_order\.order_number \|\| ' รอรับ '/);
  assert.match(sql, /'wynos-merchant-order-reminders', '\* \* \* \* \*'/);
  assert.doesNotMatch(sql.replace(/^--.*$/gm, ""), /update public\.food_orders/);
});

test("order sound asks iPhone for playback audio, so the silent switch does not mute it", () => {
  const alert = read("../components/merchant/merchant-order-alert.tsx");
  assert.match(alert, /session\.type = "playback"/);
  assert.match(alert, /function audioContext\(\)[^]*?preferPlaybackAudioSession\(\);/);
  assert.match(alert, /document\.addEventListener\("visibilitychange", onVisible\)/, "resumes sound when Merchant returns");
});

test("merchant push banners stay until tapped; other apps keep the plain banner", async () => {
  const { runInNewContext } = await import("node:vm");
  const listeners = new Map();
  const banners = [];
  const self = {
    location: { origin: "https://wynos.online" },
    addEventListener: (name, callback) => listeners.set(name, callback),
    skipWaiting: () => undefined,
    clients: { claim: async () => undefined, matchAll: async () => [] },
    registration: { showNotification: async (title, options) => { banners.push({ title, options }); } },
  };
  runInNewContext(read("../public/sw.js"), { self, URL, clients: self.clients });
  const push = async (payload) => {
    let settled;
    listeners.get("push")({ data: { json: () => payload }, waitUntil: (promise) => { settled = promise; } });
    await settled;
  };
  await push({ notification: { title: "WYNOS Merchant", body: "ออเดอร์ #WF0015", tag: "n1" }, data: { app: "merchant", type: "system" } });
  await push({ notification: { title: "Wynos", body: "liked", tag: "n2" }, data: { type: "like_drop" } });
  assert.equal(banners[0].options.requireInteraction, true);
  assert.equal(banners[0].options.renotify, true);
  assert.ok(Array.isArray(banners[0].options.vibrate) && banners[0].options.vibrate.length > 3);
  assert.equal(banners[1].options.requireInteraction, undefined);
  assert.equal(banners[1].options.renotify, undefined);
});
