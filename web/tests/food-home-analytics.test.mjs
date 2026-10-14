import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { test } from "node:test";
import { runInNewContext } from "node:vm";

const require = createRequire(import.meta.url);
let ts;
try { ts = require("typescript"); }
catch { ts = createRequire(new URL("../../admin/package.json", import.meta.url))("typescript"); }

const ID = "11111111-1111-4111-8111-111111111111";
const OTHER_ID = "22222222-2222-4222-8222-222222222222";
const flush = () => new Promise((resolve) => setImmediate(resolve));
const source = (path) => readFileSync(new URL(path, import.meta.url), "utf8");

function loadModule(path, globals = {}, imports = {}) {
  const compiled = ts.transpileModule(source(path), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const mod = { exports: {} };
  runInNewContext(compiled, {
    module: mod, exports: mod.exports,
    require(name) {
      if (!(name in imports)) throw new Error(`Unexpected dependency ${name}`);
      return imports[name];
    },
    ...globals,
  });
  return mod.exports;
}

function recorderFixture(responder = () => ({ data: { recorded: true }, error: null }), globals = {}) {
  let nextId = 0;
  const api = loadModule("../lib/food-home-analytics.ts", {
    crypto: { randomUUID: () => `00000000-0000-4000-8000-${String(++nextId).padStart(12, "0")}` },
    AbortSignal,
    ...globals,
  });
  const calls = [];
  const client = { rpc(name, payload) {
    calls.push({ name, payload });
    return { abortSignal(signal) {
      calls[calls.length - 1].signal = signal;
      return responder(calls.length, payload, signal);
    } };
  } };
  return { ...api, analytics: api.createFoodHomeAnalytics(client), client, calls };
}

test("one exposure deduplicates concurrent impressions and clicks, while kinds stay separate", async () => {
  const { analytics, calls } = recorderFixture();
  const first = analytics.observeImpression("banner", ID);
  assert.equal(analytics.observeImpression("banner", ID), first);
  assert.equal(await first, true);
  const click = analytics.recordClick("banner", ID);
  assert.equal(analytics.recordClick("banner", ID), click);
  assert.equal(await click, true);
  assert.equal(await analytics.recordClick("featured", ID), true);
  assert.deepEqual(calls.map(({ payload }) => payload.p_event_type), ["impression", "click", "impression", "click"]);
  assert.equal(calls[0].payload.p_exposure_id, calls[1].payload.p_exposure_id);
  assert.notEqual(calls[0].payload.p_exposure_id, calls[2].payload.p_exposure_id);
});

test("an intentional click starts and awaits its qualifying impression without blocking the caller", async () => {
  let acceptImpression;
  const { analytics, calls } = recorderFixture((_number, payload) => payload.p_event_type === "impression"
    ? new Promise((resolve) => { acceptImpression = resolve; })
    : { data: { recorded: true }, error: null });
  const click = analytics.recordClick("banner", ID);
  assert.deepEqual(calls.map(({ payload }) => payload.p_event_type), ["impression"]);
  assert.equal(analytics.observeImpression("banner", ID), analytics.observeImpression("banner", ID));
  acceptImpression({ data: { recorded: false, reason: "duplicate" }, error: null });
  assert.equal(await click, true);
  assert.deepEqual(calls.map(({ payload }) => payload.p_event_type), ["impression", "click"]);
});

test("transport and RPC errors retry at most once using the same receipt and payload", async () => {
  for (const failure of [() => { throw new Error("offline"); }, () => ({ data: null, error: { message: "network" } })]) {
    const { analytics, calls } = recorderFixture((number) => number === 1
      ? failure() : { data: { recorded: true }, error: null });
    assert.equal(await analytics.observeImpression("featured", ID), true);
    assert.equal(calls.length, 2);
    assert.deepEqual(calls[0].payload, calls[1].payload);
    await analytics.observeImpression("featured", ID);
    assert.equal(calls.length, 2);
  }
  const { analytics, calls } = recorderFixture(() => Promise.reject(new Error("offline")));
  assert.equal(await analytics.recordClick("banner", ID), false);
  assert.equal(calls.length, 2);
});

test("business rejections do not retry and a rejected impression never attributes a click", async () => {
  for (const reason of ["invalid", "limited", "missing_impression"]) {
    const { analytics, calls } = recorderFixture(() => ({ data: { recorded: false, reason }, error: null }));
    assert.equal(await analytics.recordClick("banner", ID), false);
    assert.equal(calls.length, 1);
  }
  const { analytics, calls } = recorderFixture((_number, payload) => ({
    data: payload.p_event_type === "impression" ? { recorded: true } : { recorded: false, reason: "missing_impression" },
    error: null,
  }));
  assert.equal(await analytics.recordClick("banner", ID), false);
  assert.equal(calls.length, 2);
});

test("payloads contain only the four identifiers, with no account, location, URL or storage access", async () => {
  const { analytics, calls } = recorderFixture();
  await analytics.recordClick("banner", ID);
  for (const call of calls) {
    assert.equal(call.name, "food_record_home_placement_event");
    assert.deepEqual(Object.keys(call.payload).sort(), ["p_event_type", "p_exposure_id", "p_placement_id", "p_placement_kind"]);
    assert.equal(call.payload.p_placement_id, ID);
  }
  assert.equal(await analytics.recordClick("unknown", ID), false);
  assert.equal(await analytics.recordClick("banner", "not-a-uuid"), false);
  assert.equal(calls.length, 2);
  const code = source("../lib/food-home-analytics.ts");
  assert.doesNotMatch(code, /localStorage|sessionStorage|document\.|location\.|navigator\.|console\./);
});

test("cleanup prevents new work while an intentional click already in flight finishes after navigation", async () => {
  let acceptFirst;
  const { analytics, calls } = recorderFixture((number) => number === 1
    ? new Promise((resolve) => { acceptFirst = resolve; })
    : { data: { recorded: true }, error: null });
  const pending = analytics.recordClick("banner", ID);
  analytics.dispose();
  assert.equal(await analytics.recordClick("banner", OTHER_ID), false);
  acceptFirst({ data: { recorded: true }, error: null });
  assert.equal(await pending, true);
  assert.deepEqual(calls.map(({ payload }) => payload.p_event_type), ["impression", "click"]);
});

test("unavailable secure randomness skips telemetry", async () => {
  const unavailable = recorderFixture(undefined, { crypto: undefined });
  assert.equal(await unavailable.analytics.recordClick("banner", ID), false);
  assert.equal(unavailable.calls.length, 0);
});

test("stalled telemetry aborts each attempt and never blocks a click indefinitely", async () => {
  const deadlines = [];
  const { analytics, calls } = recorderFixture((_number, _payload, signal) => new Promise((resolve) => {
    signal.addEventListener("abort", () => resolve({ data: null, error: { message: "aborted" } }), { once: true });
  }), { AbortSignal: { timeout(ms) { deadlines.push(ms); return AbortSignal.timeout(20); } } });
  const keepAlive = setTimeout(() => {}, 1000);
  try {
    assert.equal(await analytics.recordClick("banner", ID), false);
    assert.equal(calls.length, 2);
    assert.deepEqual(deadlines, [3000, 3000]);
    assert.ok(calls.every(call => call.signal.aborted));
  } finally { clearTimeout(keepAlive); }
});

class FakeElement {
  constructor(tagName = "div", attrs = {}) {
    this.tagName = tagName.toUpperCase();
    this.attrs = { ...attrs };
    this.children = [];
    this.parent = null;
  }
  append(child) { child.parent = this; this.children.push(child); return child; }
  remove(child) { this.children = this.children.filter((entry) => entry !== child); child.parent = null; }
  getAttribute(name) { return this.attrs[name] ?? null; }
  contains(element) { return this === element || this.children.some((child) => child.contains(element)); }
  matches(selector) {
    if (selector === ":disabled,[aria-disabled='true']") return "disabled" in this.attrs || this.attrs["aria-disabled"] === "true";
    return "data-food-home-kind" in this.attrs && "data-food-home-id" in this.attrs;
  }
  querySelectorAll(selector) {
    return this.children.flatMap((child) => [...(child.matches(selector) ? [child] : []), ...child.querySelectorAll(selector)]);
  }
  closest() {
    if (this.matches("") && (this.tagName === "BUTTON" || (this.tagName === "A" && "href" in this.attrs))) return this;
    return this.parent?.closest() ?? null;
  }
}

function observerFixture() {
  let time = 0;
  let nextTimer = 0;
  const timers = new Map();
  const effects = [];
  const listeners = new Set();
  const intersections = [];
  const mutations = [];
  const document = {
    visibilityState: "visible",
    addEventListener(_name, listener) { listeners.add(listener); },
    removeEventListener(_name, listener) { listeners.delete(listener); },
  };
  class IntersectionObserver {
    constructor(callback) { this.callback = callback; this.targets = new Set(); intersections.push(this); }
    observe(element) { this.targets.add(element); }
    unobserve(element) { this.targets.delete(element); }
    disconnect() { this.targets.clear(); }
    emit(element, ratio) {
      if (this.targets.has(element)) this.callback([{ target: element, isIntersecting: ratio > 0, intersectionRatio: ratio }]);
    }
  }
  class MutationObserver {
    constructor(callback) { this.callback = callback; this.active = false; mutations.push(this); }
    observe() { this.active = true; }
    disconnect() { this.active = false; }
    emit() { if (this.active) this.callback([]); }
  }
  const recorder = recorderFixture();
  const hook = loadModule("../hooks/use-food-home-analytics.ts", {
    document, IntersectionObserver, MutationObserver, Element: FakeElement,
    setTimeout(callback, delay) { const id = ++nextTimer; timers.set(id, { at: time + delay, callback }); return id; },
    clearTimeout(id) { timers.delete(id); },
  }, {
    react: {
      useCallback: (callback) => callback,
      useRef: (initial) => ({ current: initial }),
      useState: (initial) => [initial, () => {}],
      useEffect: (effect) => effects.push(effect),
    },
    "@/lib/food-home-analytics": recorder,
  });
  const root = new FakeElement();
  const placement = (tag = "button", kind = "banner", id = ID, attrs = {}) => new FakeElement(tag, {
    "data-food-home-kind": kind, "data-food-home-id": id, ...attrs,
  });
  return {
    ...hook, ...recorder, root, placement, timers, intersections, mutations, listeners, effects,
    tick(duration) {
      const until = time + duration;
      while (true) {
        const entry = [...timers].sort((a, b) => a[1].at - b[1].at).find(([, timer]) => timer.at <= until);
        if (!entry) break;
        const [id, timer] = entry;
        time = timer.at;
        timers.delete(id);
        timer.callback();
      }
      time = until;
    },
    visibility(state) { document.visibilityState = state; for (const listener of listeners) listener(); },
  };
}

test("an impression requires 50 percent visibility continuously for a full second", async () => {
  const fixture = observerFixture();
  const element = fixture.root.append(fixture.placement());
  const stop = fixture.observeFoodHomeAnalytics(fixture.root, fixture.analytics);
  const observer = fixture.intersections[0];
  observer.emit(element, 0.49);
  fixture.tick(2000);
  assert.equal(fixture.calls.length, 0);
  observer.emit(element, 0.5);
  fixture.tick(700);
  observer.emit(element, 0.4);
  fixture.tick(500);
  assert.equal(fixture.calls.length, 0);
  observer.emit(element, 0.9);
  fixture.tick(999);
  assert.equal(fixture.calls.length, 0);
  fixture.tick(1);
  await flush();
  assert.equal(fixture.calls.length, 1);
  observer.emit(element, 0.1);
  observer.emit(element, 1);
  fixture.tick(2000);
  assert.equal(fixture.calls.length, 1);
  stop();
});

test("hidden documents cancel timers and require a fresh full interval after visibility returns", () => {
  const fixture = observerFixture();
  const element = fixture.root.append(fixture.placement());
  const stop = fixture.observeFoodHomeAnalytics(fixture.root, fixture.analytics);
  const observer = fixture.intersections[0];
  observer.emit(element, 1);
  fixture.tick(800);
  fixture.visibility("hidden");
  fixture.tick(4000);
  observer.emit(element, 1);
  fixture.tick(2000);
  assert.equal(fixture.calls.length, 0);
  fixture.visibility("visible");
  fixture.tick(2000);
  assert.equal(fixture.calls.length, 0);
  observer.emit(element, 0.5);
  fixture.tick(999);
  assert.equal(fixture.calls.length, 0);
  fixture.tick(1);
  assert.equal(fixture.calls.length, 1);
  stop();
});

test("mutation refresh observes new placements and cancels removed or replaced targets", () => {
  const fixture = observerFixture();
  const original = fixture.root.append(fixture.placement());
  const stop = fixture.observeFoodHomeAnalytics(fixture.root, fixture.analytics);
  const observer = fixture.intersections[0];
  observer.emit(original, 1);
  fixture.tick(500);
  fixture.root.remove(original);
  const added = fixture.root.append(fixture.placement("div", "featured", OTHER_ID));
  fixture.mutations[0].emit();
  assert.equal(observer.targets.has(original), false);
  assert.equal(observer.targets.has(added), true);
  fixture.tick(1000);
  assert.equal(fixture.calls.length, 0);
  observer.emit(added, 1);
  fixture.tick(500);
  added.attrs["data-food-home-id"] = ID;
  fixture.mutations[0].emit();
  fixture.tick(500);
  assert.equal(fixture.calls.length, 0);
  observer.emit(added, 1);
  fixture.tick(1000);
  assert.equal(fixture.calls.length, 1);
  assert.equal(fixture.calls[0].payload.p_placement_id, ID);
  assert.equal(fixture.calls[0].payload.p_placement_kind, "featured");
  stop();
});

test("observer cleanup disconnects both observers, visibility listener and pending timers", () => {
  const fixture = observerFixture();
  const element = fixture.root.append(fixture.placement());
  const stop = fixture.observeFoodHomeAnalytics(fixture.root, fixture.analytics);
  fixture.intersections[0].emit(element, 1);
  assert.equal(fixture.timers.size, 1);
  stop();
  assert.equal(fixture.timers.size, 0);
  assert.equal(fixture.intersections[0].targets.size, 0);
  assert.equal(fixture.mutations[0].active, false);
  assert.equal(fixture.listeners.size, 0);
  fixture.tick(2000);
  assert.equal(fixture.calls.length, 0);
});

test("delegated clicks track only tagged buttons and links, leaving navigation untouched", async () => {
  const fixture = observerFixture();
  const { onAnalyticsClickCapture } = fixture.useFoodHomeAnalytics(fixture.client);
  const cleanup = fixture.effects.map((effect) => effect()).filter(Boolean);
  const information = fixture.root.append(fixture.placement("div"));
  const disabled = fixture.root.append(fixture.placement("button", "featured", ID, { disabled: "" }));
  const noHref = fixture.root.append(fixture.placement("a", "featured", OTHER_ID));
  const button = fixture.root.append(fixture.placement());
  const icon = button.append(new FakeElement("span"));
  const link = fixture.root.append(fixture.placement("a", "featured", OTHER_ID, { href: "/food" }));
  let prevented = false;
  const click = (target) => onAnalyticsClickCapture({
    target, currentTarget: fixture.root,
    preventDefault() { prevented = true; }, stopPropagation() { prevented = true; },
  });
  click(information);
  click(disabled);
  click(noHref);
  assert.equal(fixture.calls.length, 0);
  assert.equal(click(icon), undefined);
  click(icon);
  click(link);
  await flush();
  assert.equal(prevented, false);
  assert.deepEqual(fixture.calls.map(({ payload }) => payload.p_event_type), ["impression", "impression", "click", "click"]);
  for (const dispose of cleanup) dispose();
});
