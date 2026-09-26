import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const source = readFileSync(new URL("../lib/app-prefetch.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  fileName: "app-prefetch.ts",
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

function fixture({ online = true, visible = true, saveData = false, effectiveType = "4g", idle = true } = {}) {
  const jobs = new Map();
  const cancelled = new Set();
  const observed = [];
  let nextId = 1;
  const window = {
    setTimeout: (callback) => { const id = nextId++; jobs.set(id, callback); return id; },
    clearTimeout: (id) => { jobs.delete(id); cancelled.add(id); },
    ...(idle ? {
      requestIdleCallback: (callback) => { const id = nextId++; jobs.set(id, callback); return id; },
      cancelIdleCallback: (id) => { jobs.delete(id); cancelled.add(id); },
    } : {}),
  };
  const exports = {};
  const navigator = { onLine: online, connection: { saveData, effectiveType } };
  const document = { visibilityState: visible ? "visible" : "hidden" };
  runInNewContext(compiled, { exports, window, navigator, document }, { filename: "app-prefetch.compiled.js" });
  const pump = (count = 1) => {
    for (let step = 0; step < count; step += 1) {
      const next = jobs.entries().next().value;
      if (!next) break;
      jobs.delete(next[0]);
      next[1]();
    }
  };
  return {
    ...exports,
    warm: (userId = "account-one", currentPath = "/") =>
      exports.scheduleAppRoutePrefetch((href) => observed.push(href), userId, currentPath),
    observed,
    get queued() { return jobs.size; },
    cancelled,
    pump,
    navigator,
    document,
  };
}

test("only authenticated visible pages schedule a gradual prefetch; current route is omitted", () => {
  const app = fixture();
  const cancel = app.warm();
  assert.equal(app.observed.length, 0, "no route loads synchronously with first paint");
  app.pump();
  assert.deepEqual(app.observed, ["/clubs"]);
  app.pump(2);
  assert.deepEqual(app.observed, ["/clubs", "/chat"]);
  app.pump(20);
  assert.deepEqual(app.observed,
    ["/clubs", "/chat", "/search", "/notifications", "/profile/account-one?from=tab"]);
  assert.equal(app.queued, 0);
  cancel();
});

test("slow networks, offline, hidden tabs and Save-Data never schedule speculative loads", () => {
  for (const options of [
    { online: false }, { visible: false }, { saveData: true },
    { effectiveType: "slow-2g" }, { effectiveType: "2g" },
  ]) {
    const app = fixture(options);
    app.warm();
    assert.equal(app.queued, 0, JSON.stringify(options));
    assert.deepEqual(app.observed, []);
  }
});

test("auth-free routes cannot start account-specific prefetches", () => {
  const app = fixture();
  app.warm("", "/welcome");
  assert.equal(app.queued, 0);
  assert.deepEqual(app.observed, []);
});

test("navigation cleanup cancels idle prefetch without touching real route navigation", () => {
  const app = fixture();
  const cancel = app.warm();
  cancel();
  app.pump(20);
  assert.deepEqual(app.observed, []);
  assert.equal(app.queued, 0);
});

test("changing to background mid-warmup stops all remaining speculative requests", () => {
  const app = fixture();
  app.warm();
  app.pump();
  app.document.visibilityState = "hidden";
  app.pump(20);
  assert.deepEqual(app.observed, ["/clubs"]);
});

test("setTimeout fallback still schedules one route at a time on older Safari", () => {
  const app = fixture({ idle: false });
  app.warm();
  assert.equal(app.queued, 1);
  app.pump();
  assert.deepEqual(app.observed, ["/clubs"]);
  app.pump(20);
  assert.equal(app.observed.length, 5);
});

test("app-wide changes retain Push safety, privacy-aware warming and approved arrival motion", () => {
  const read = (name) => readFileSync(new URL(name, import.meta.url), "utf8");
  const nav = read("../components/app-navigation-runtime.tsx");
  const chrome = read("../components/phase3-ui.tsx");
  const transition = read("../components/ui/page-transition.tsx");
  const clubs = read("../components/clubs-routes.tsx");
  const settings = read("../components/settings-route.tsx");

  assert.doesNotMatch(nav, /for \(const href of PREFETCH_ROUTES\)/);
  assert.match(chrome, /scheduleAppRoutePrefetch/);
  assert.match(nav, /navigator\.serviceWorker\.register\("\/sw\.js"\)/);
  assert.match(nav, /listenForForegroundPush\(\)/);
  assert.match(nav, /Notification\.permission !== "granted"/);
  assert.match(transition, /mode="wait"/);
  assert.match(transition, /const DURATION = 0\.22/);
  assert.match(transition, /const EXIT_DURATION = 0\.09/);
  assert.match(transition, /transition: \{ duration: EXIT_DURATION/);
  assert.match(clubs, /const \[pages, membership\] = await Promise\.all/);
  assert.match(settings, /if \(section !== "notifications"\) return/);
});
