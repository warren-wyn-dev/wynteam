import assert from "node:assert/strict";
import test from "node:test";
import { MERCHANT_FLUTTER_STARTUP_EVENT, observeMerchantFlutterStartup, markMerchantFlutterStartup } from "../lib/merchant-flutter-startup.ts";

const detail = (viewId = 7) => ({ viewId, phase: "content-ready", elapsedMs: 410, fontWarmupMs: 120, fontWarmupTimedOut: false });
function setup(t) {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const target = new EventTarget(), ready = [], timeouts = [];
  const monitor = observeMerchantFlutterStartup({ target, onReady: value => ready.push(value), onTimeout: () => timeouts.push(true) });
  t.after(() => monitor.dispose());
  const send = value => target.dispatchEvent(new CustomEvent(MERCHANT_FLUTTER_STARTUP_EVENT, { detail: value }));
  return { monitor, send, ready, timeouts };
}

test("engine readiness alone does not reveal a view; only its own settled content does", t => {
  const { monitor, send, ready } = setup(t);
  monitor.watch(7);
  send(detail(6));
  assert.deepEqual(ready, []);
  send(detail(7));
  assert.deepEqual(ready, [detail(7)]);
  send(detail(7));
  assert.equal(ready.length, 1);
});

test("a synchronous addView signal is retained until the returned view ID is known", t => {
  const { monitor, send, ready } = setup(t);
  send(detail(7));
  send(detail(6));
  assert.deepEqual(ready, []);
  monitor.watch(7);
  assert.deepEqual(ready, [detail(7)]);
});

test("malformed signals cannot settle the startup view or leak arbitrary payload fields", t => {
  const { monitor, send, ready, timeouts } = setup(t);
  monitor.watch(7);
  for (const value of [null, {}, { ...detail(), viewId: "7" }, { ...detail(), phase: "engine-ready" },
    { ...detail(), elapsedMs: NaN }, { ...detail(), fontWarmupMs: -1 }, { ...detail(), fontWarmupTimedOut: "false" }]) send(value);
  assert.deepEqual(ready, []);
  t.mock.timers.tick(20_000);
  assert.deepEqual(timeouts, [true]);
});

test("timeout is bounded after mounting and a late signal cannot reopen a failed view", t => {
  const { monitor, send, ready, timeouts } = setup(t);
  t.mock.timers.tick(30_000);
  assert.deepEqual(timeouts, []);
  monitor.watch(7);
  t.mock.timers.tick(19_999);
  assert.deepEqual(timeouts, []);
  t.mock.timers.tick(1);
  send(detail());
  assert.deepEqual(timeouts, [true]);
  assert.deepEqual(ready, []);
});

test("disposing a view cancels its timeout and ignores removed-view signals", t => {
  const { monitor, send, ready, timeouts } = setup(t);
  monitor.watch(7);
  monitor.dispose();
  send(detail());
  t.mock.timers.tick(20_000);
  assert.deepEqual(ready, []);
  assert.deepEqual(timeouts, []);
});

test("local timing marks stay bounded and contain performance values only", () => {
  markMerchantFlutterStartup("content", { ...detail(), email: "never-include@example.test" });
  markMerchantFlutterStartup("content", detail());
  const marks = performance.getEntriesByName("merchant:flutter:content");
  assert.equal(marks.length, 1);
  assert.deepEqual(marks[0].detail, { elapsedMs: 410, fontWarmupMs: 120, fontWarmupTimedOut: false });
  performance.clearMarks("merchant:flutter:content");
});
