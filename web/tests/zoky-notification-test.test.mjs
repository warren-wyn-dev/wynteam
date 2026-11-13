// Founder 2026-11-13: the on-device "test notifications" button for ZOKY.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const compiled = ts.transpileModule(readFileSync(new URL("../lib/zoky-notification-test.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

// Objects made inside the vm context have another Object prototype, so compare plain copies.
const plain = (value) => JSON.parse(JSON.stringify(value));

function load(env) {
  const exports = {};
  runInNewContext(compiled, { exports, ...env });
  return exports;
}

const shown = [];
const registration = { showNotification: async (title, options) => { shown.push({ title, options }); } };
const goodEnv = (permission, overrides = {}) => ({
  window: {},
  Notification: { permission },
  navigator: { serviceWorker: { getRegistration: async () => registration, ready: Promise.resolve(registration), ...overrides } },
});

test("shows a ZOKY notification on this device when permission is granted", async () => {
  shown.length = 0;
  const { showZokyTestNotification } = load(goodEnv("granted"));
  assert.deepEqual(plain(await showZokyTestNotification()), { ok: true });
  assert.equal(shown.length, 1);
  assert.equal(shown[0].title, "ZOKY");
  assert.equal(shown[0].options.tag, "zoky-notification-test");
  assert.deepEqual(plain(shown[0].options.data), { app: "food" });
});

test("does not show anything without permission", async () => {
  shown.length = 0;
  for (const permission of ["default", "denied"]) {
    const { showZokyTestNotification } = load(goodEnv(permission));
    assert.deepEqual(plain(await showZokyTestNotification()), { ok: false, reason: "not-granted" }, permission);
  }
  assert.equal(shown.length, 0);
});

test("reports unsupported browsers and failures with Thai guidance", async () => {
  const unsupported = load({ window: {}, navigator: {} });
  assert.deepEqual(plain(await unsupported.showZokyTestNotification()), { ok: false, reason: "unsupported" });
  const failing = load(goodEnv("granted", { getRegistration: async () => { throw new Error("boom"); } }));
  const result = await failing.showZokyTestNotification();
  assert.deepEqual(plain(result), { ok: false, reason: "failed" });
  const { zokyNotificationTestMessage } = failing;
  assert.match(zokyNotificationTestMessage({ ok: true }), /ส่งแจ้งเตือนทดสอบแล้ว/);
  assert.match(zokyNotificationTestMessage({ ok: false, reason: "unsupported" }), /iPhone/);
  assert.match(zokyNotificationTestMessage({ ok: false, reason: "not-granted" }), /เปิดการแจ้งเตือนก่อน/);
  assert.match(zokyNotificationTestMessage(result), /ไม่สำเร็จ/);
});

test("the ZOKY settings page has the test button wired to the helper", () => {
  const app = readFileSync(new URL("../components/food/wynos-food-developer-app.tsx", import.meta.url), "utf8");
  assert.match(app, /onClick=\{onTestNotification\}/);
  assert.match(app, /onTestNotification=\{\(\) => void testNotification\(\)\}/);
  assert.match(app, /zokyNotificationTestMessage\(await showZokyTestNotification\(\)\)/);
});

test("ZOKY settings: one notification card with an on/off switch and the test button; no Open WYNOS Social row", () => {
  const app = readFileSync(new URL("../components/food/wynos-food-developer-app.tsx", import.meta.url), "utf8");
  const start = app.indexOf('<div className="fx-menu-list-settings">');
  const end = app.indexOf("</div>\n\n      <button className=\"fx-btn fx-btn--soft fx-btn--block fx-signout\"", start);
  assert.ok(start > 0 && end > start);
  const settings = app.slice(start, end);
  // One card holding the switch (a real button with role=switch) and the test button.
  assert.equal(settings.split('className="fx-notification-card"').length - 1, 1);
  assert.match(settings, /role="switch" aria-checked=\{notificationsEnabled\}/);
  assert.match(settings, /className="fx-switch" onClick=\{onNotifications\}/);
  assert.match(settings, /className="fx-notification-test" onClick=\{onTestNotification\}/);
  // The old separate rows are gone.
  assert.doesNotMatch(settings, /<button type="button" onClick=\{onNotifications\}>/);
  assert.doesNotMatch(settings, /เปิด WYNOS Social/);
  assert.doesNotMatch(settings, /wynos\.online\/login/);
  const css = readFileSync(new URL("../app/food/food-app.css", import.meta.url), "utf8");
  assert.match(css, /\.fx-switch\[aria-checked="true"\]::before/);
  assert.match(css, /\.fx-switch \{[^}]*height: 44px/);
});
