import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";

// ZOKY-136: the worker served as /sw.js on the retired food.wynos.online origin.
const source = readFileSync(new URL("../public/food/legacy-sw-cleanup.js", import.meta.url), "utf8");

function loadWorker({ subscribed = true } = {}) {
  const calls = [];
  const listeners = {};
  const subscription = subscribed ? { unsubscribe: async () => { calls.push("unsubscribe"); return true; } } : null;
  const self = {
    addEventListener: (type, fn) => { listeners[type] = fn; },
    skipWaiting: () => calls.push("skipWaiting"),
    registration: {
      pushManager: { getSubscription: async () => subscription },
      unregister: async () => { calls.push("unregister"); return true; },
      showNotification: async (title, options) => { calls.push(["notify", title, options]); },
    },
    clients: { openWindow: async (url) => { calls.push(["open", url]); } },
  };
  const caches = {
    keys: async () => ["wynos-static-v2", "other-cache"],
    delete: async (name) => { calls.push(["cache-delete", name]); return true; },
  };
  runInNewContext(source, { self, caches });
  async function dispatch(type, extra = {}) {
    let pending = Promise.resolve();
    listeners[type]({ waitUntil: (p) => { pending = p; }, ...extra });
    await pending;
  }
  return { calls, listeners, dispatch };
}

test("activation unsubscribes push, clears old static caches and unregisters", async () => {
  const worker = loadWorker();
  await worker.dispatch("install");
  await worker.dispatch("activate");
  assert.deepEqual(worker.calls, ["skipWaiting", "unsubscribe", ["cache-delete", "wynos-static-v2"], "unregister"]);
});

test("activation still unregisters when there is no push subscription", async () => {
  const worker = loadWorker({ subscribed: false });
  await worker.dispatch("activate");
  assert.ok(worker.calls.includes("unregister"));
  assert.ok(!worker.calls.includes("unsubscribe"));
});

test("a late push shows only a generic banner (no payload content) and unsubscribes", async () => {
  const worker = loadWorker();
  await worker.dispatch("push", { data: { json: () => ({ notification: { title: "Order WF0001", body: "secret" } }) } });
  const notify = worker.calls.find((c) => Array.isArray(c) && c[0] === "notify");
  assert.equal(notify[1], "ZOKY");
  assert.doesNotMatch(JSON.stringify(notify), /WF0001|secret/);
  assert.ok(worker.calls.includes("unsubscribe"));
});

test("tapping the banner opens ZOKY only", async () => {
  const worker = loadWorker();
  await worker.dispatch("notificationclick", { notification: { close: () => {} } });
  assert.deepEqual(worker.calls, [["open", "https://zoky.wynos.online/"]]);
});

test("the cleanup worker never reads the push payload or contacts the server", () => {
  const code = source.replace(/^\s*\/\/.*$/gm, "");
  assert.doesNotMatch(code, /event\.data|fetch\(|supabase|importScripts/i);
});
