// Push must not look or become "off" by itself: a rotated or dropped token
// is re-registered for an account that turned Push on here, and a failed
// check is reported as unknown (null), never as off.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const compiled = ts.transpileModule(readFileSync(new URL("../lib/push-notifications.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

function fixture({ wanted = true, registered = false, configFails = false, selectFails = false } = {}) {
  const calls = [];
  const store = new Map(wanted ? [["wynos.push.wanted.v1", JSON.stringify(["u1"])]] : []);
  const registration = { active: {}, pushManager: { getSubscription: async () => ({ endpoint: "x" }) } };
  const Notification = { permission: "granted" };
  const window = {
    Notification, PushManager: {}, matchMedia: () => ({ matches: true }),
    localStorage: { getItem: (k) => store.get(k) ?? null, setItem: (k, v) => store.set(k, v), removeItem: (k) => store.delete(k) },
    setTimeout, clearTimeout,
  };
  const navigator = {
    userAgent: "Mozilla/5.0 (Linux; Android 15) Chrome/130", maxTouchPoints: 0,
    serviceWorker: { getRegistration: async () => registration, register: async () => registration, ready: Promise.resolve(registration) },
  };
  const exports = {};
  runInNewContext(compiled, {
    exports, window, navigator, Notification,
    require: (name) => {
      if (name === "firebase/app") return { getApps: () => [], initializeApp: () => ({}) };
      if (name === "firebase/messaging") return { isSupported: async () => true, getMessaging: () => ({}), getToken: async () => "rotated-token", onMessage: () => undefined };
      throw new Error("Unexpected module: " + name);
    },
    fetch: async () => {
      if (configFails) throw new Error("offline");
      return { ok: true, json: async () => ({ configured: true, vapidKey: "v", apiKey: "a", appId: "b", messagingSenderId: "1", projectId: "p" }) };
    },
    Date, setTimeout, clearTimeout,
  });
  const client = {
    from: () => {
      const query = {
        select: () => query, eq: () => query,
        maybeSingle: async () => selectFails ? { data: null, error: { message: "network" } } : { data: registered ? { token: "rotated-token" } : null, error: null },
        upsert: async (row) => { calls.push(`upsert:${row.user_id}:${row.token}`); return { error: null }; },
      };
      return query;
    },
  };
  return { exports, client, calls, store };
}

test("an account that turned Push on gets its rotated token registered again, and shows on", async () => {
  const f = fixture({ wanted: true, registered: false });
  assert.equal(await f.exports.isCurrentDevicePushEnabled(f.client, "u1"), true);
  assert.deepEqual(f.calls, ["upsert:u1:rotated-token"]);
});

test("an account that never turned Push on here stays off and is not registered", async () => {
  const f = fixture({ wanted: false, registered: false });
  assert.equal(await f.exports.isCurrentDevicePushEnabled(f.client, "u1"), false);
  assert.deepEqual(f.calls, []);
});

test("a check that cannot complete is unknown (null), never off", async () => {
  assert.equal(await fixture({ configFails: true }).exports.isCurrentDevicePushEnabled(fixture().client, "u1"), null);
  const f = fixture({ selectFails: true });
  assert.equal(await f.exports.isCurrentDevicePushEnabled(f.client, "u1"), null);
});

test("resync registers the current token once per page load, only when wanted", async () => {
  const f = fixture({ wanted: true });
  await f.exports.resyncPushRegistration(f.client, "u1");
  await f.exports.resyncPushRegistration(f.client, "u1");
  assert.deepEqual(f.calls, ["upsert:u1:rotated-token"]);
  const g = fixture({ wanted: false });
  await g.exports.resyncPushRegistration(g.client, "u1");
  assert.deepEqual(g.calls, []);
});

test("the wanted flag is per account and cleared only by setPushWanted(false)", () => {
  const f = fixture({ wanted: false });
  f.exports.setPushWanted("u1", true);
  f.exports.setPushWanted("u2", true);
  f.exports.setPushWanted("u1", false);
  assert.equal(f.exports.isPushWanted("u1"), false);
  assert.equal(f.exports.isPushWanted("u2"), true);
});

// Founder report: "มันปิดเองตอนสลับบัญชี" (Push turns off on account switch).
test("Push that was on carries over to the account switched to, and back", async () => {
  const f = fixture({ wanted: true });
  assert.equal(await f.exports.isPushOnBeforeAccountChange("u1"), true);
  f.exports.keepPushOnAcrossAccountChange("u1", "u2");
  assert.equal(f.exports.isPushWanted("u2"), true);
  assert.equal(f.exports.isPushWanted("u1"), true);
  // After the hard navigation, the new account's page load registers it.
  await f.exports.resyncPushRegistration(f.client, "u2");
  assert.deepEqual(f.calls, ["upsert:u2:rotated-token"]);
});

test("an active subscription counts as on even without the wanted flag (Push turned on before it existed)", async () => {
  const f = fixture({ wanted: false });
  assert.equal(await f.exports.isPushOnBeforeAccountChange("u1"), true);
});

test("a switch never turns Push on for an account that turned it off in Settings", () => {
  const f = fixture({ wanted: false });
  f.exports.setPushChosen("u2", false);
  f.exports.keepPushOnAcrossAccountChange("u1", "u2");
  assert.equal(f.exports.isPushWanted("u2"), false);
  f.exports.setPushChosen("u2", true);
  f.exports.keepPushOnAcrossAccountChange("u1", "u2");
  assert.equal(f.exports.isPushWanted("u2"), true);
});

test("resync remembers an account already registered on this device, without re-registering", async () => {
  const f = fixture({ wanted: false, registered: true });
  await f.exports.resyncPushRegistration(f.client, "u1");
  assert.equal(f.exports.isPushWanted("u1"), true);
  assert.deepEqual(f.calls, []);
});
