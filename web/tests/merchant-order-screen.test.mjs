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
