import assert from "node:assert/strict";
import { test } from "node:test";
import { createOrderRecovery } from "../lib/order-recovery.ts";

function environment() {
  const document = new EventTarget();
  document.visibilityState = "hidden";
  return { document, window: new EventTarget() };
}
const settle = async () => { await Promise.resolve(); await Promise.resolve(); };

test("a burst of joined-channel and database events performs one recovery fetch", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  let calls = 0;
  const recovery = createOrderRecovery(async () => { calls += 1; }, environment());
  recovery.onSubscriptionStatus("CHANNEL_ERROR");
  t.mock.timers.tick(120);
  assert.equal(calls, 0);
  recovery.onSubscriptionStatus("SUBSCRIBED");
  recovery.request();
  recovery.request();
  t.mock.timers.tick(119);
  assert.equal(calls, 0);
  t.mock.timers.tick(1);
  await settle();
  assert.equal(calls, 1);
  recovery.onSubscriptionStatus("SUBSCRIBED");
  t.mock.timers.tick(120);
  await settle();
  assert.equal(calls, 2, "successful reconnect fetches the current snapshot");
  recovery.dispose();
});

test("events during an in-flight fetch queue exactly one later refresh", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  let resolve;
  let calls = 0;
  const pending = new Promise((done) => { resolve = done; });
  const recovery = createOrderRecovery(() => { calls += 1; return calls === 1 ? pending : Promise.resolve(); }, environment());
  recovery.request();
  t.mock.timers.tick(120);
  recovery.request();
  recovery.request();
  t.mock.timers.tick(500);
  assert.equal(calls, 1, "never overlaps the pending fetch");
  resolve();
  await settle();
  t.mock.timers.tick(120);
  await settle();
  assert.equal(calls, 2);
  t.mock.timers.tick(500);
  assert.equal(calls, 2);
  recovery.dispose();
});

test("returning visible and network restoration reload missed order state", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const browser = environment();
  let calls = 0;
  const recovery = createOrderRecovery(async () => { calls += 1; }, browser);
  browser.document.dispatchEvent(new Event("visibilitychange"));
  t.mock.timers.tick(120);
  assert.equal(calls, 0, "hidden events do not fetch");
  browser.document.visibilityState = "visible";
  browser.document.dispatchEvent(new Event("visibilitychange"));
  browser.window.dispatchEvent(new Event("online"));
  t.mock.timers.tick(120);
  await settle();
  assert.equal(calls, 1);
  browser.window.dispatchEvent(new Event("online"));
  t.mock.timers.tick(120);
  await settle();
  assert.equal(calls, 2);
  recovery.dispose();
});

test("disposing cancels the pending refresh and removes browser recovery listeners", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const browser = environment();
  let calls = 0;
  const recovery = createOrderRecovery(async () => { calls += 1; }, browser);
  recovery.request();
  recovery.dispose();
  browser.document.visibilityState = "visible";
  browser.document.dispatchEvent(new Event("visibilitychange"));
  browser.window.dispatchEvent(new Event("online"));
  recovery.onSubscriptionStatus("SUBSCRIBED");
  recovery.request();
  t.mock.timers.tick(500);
  await settle();
  assert.equal(calls, 0);
});

test("a failed fetch can recover on the next event without unhandled rejection", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  let calls = 0;
  const recovery = createOrderRecovery(async () => {
    calls += 1;
    if (calls === 1) throw new Error("offline");
  }, environment());
  recovery.request();
  t.mock.timers.tick(120);
  await settle();
  recovery.request();
  t.mock.timers.tick(120);
  await settle();
  assert.equal(calls, 2);
  recovery.dispose();
});

test("disposing during a fetch drops queued events and never starts another fetch", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  let resolve;
  let calls = 0;
  const pending = new Promise((done) => { resolve = done; });
  const recovery = createOrderRecovery(() => { calls += 1; return pending; }, environment());
  recovery.request();
  t.mock.timers.tick(120);
  recovery.request();
  recovery.dispose();
  resolve();
  await settle();
  t.mock.timers.tick(500);
  assert.equal(calls, 1);
});
