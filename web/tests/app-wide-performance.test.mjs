import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const prefetchSource = readFileSync(new URL("../lib/app-prefetch.ts", import.meta.url), "utf8");
const cacheSource = readFileSync(new URL("../lib/mount-cache.ts", import.meta.url), "utf8");

function compile(source, name) {
  return ts.transpileModule(source, {
    fileName: name,
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
}

function prefetchFixture({ online = true, visible = true, saveData = false, effectiveType = "4g", idle = true } = {}) {
  let nextHandle = 1;
  const idleJobs = new Map();
  const timeouts = new Map();
  const calls = [];
  const navigator = { onLine: online, connection: { saveData, effectiveType } };
  const document = { visibilityState: visible ? "visible" : "hidden" };
  const window = {
    setTimeout: (fn, delay) => {
      const handle = nextHandle++;
      timeouts.set(handle, { fn, delay });
      return handle;
    },
    clearTimeout: (id) => timeouts.delete(id),
    ...(idle ? {
      requestIdleCallback: (fn, options) => {
        const handle = nextHandle++;
        idleJobs.set(handle, { fn, options });
        return handle;
      },
      cancelIdleCallback: (id) => idleJobs.delete(id),
    } : {}),
  };
  const exports = {};
  runInNewContext(compile(prefetchSource, "app-prefetch.ts"), {
    exports, window, navigator, document, encodeURIComponent,
  }, { filename: "app-prefetch.js" });

  const advance = (queue) => {
    const [id, job] = queue.entries().next().value ?? [];
    if (!job) return false;
    queue.delete(id);
    job.fn();
    return true;
  };
  return {
    schedule: (uid = "user-a", path = "/") => exports.scheduleAppRoutePrefetch(
      (href) => calls.push(href), uid, path,
    ),
    idle: () => advance(idleJobs),
    timer: () => advance(timeouts),
    calls,
    idleJobs,
    timeouts,
    navigator,
    document,
    canWarm: exports.shouldWarmAppRoutes,
  };
}

test("an authenticated page defers global route prefetch until idle and paces the rest", () => {
  const f = prefetchFixture();
  f.schedule("user-a", "/");
  assert.equal(f.calls.length, 0, "no route-manifest requests during first paint");
  assert.equal(f.idleJobs.size, 1);
  f.idle();
  assert.deepEqual(f.calls, ["/clubs"]);
  assert.equal(f.timeouts.size, 1, "schedule later routes instead of a burst");
  f.timer();
  assert.deepEqual(f.calls, ["/clubs"]);
  f.idle();
  assert.deepEqual(f.calls, ["/clubs", "/chat"]);
  for (let n = 0; n < 8 && f.timeouts.size; n++) {
    f.timer();
    f.idle();
  }
  assert.deepEqual(f.calls, [
    "/clubs", "/chat", "/search", "/notifications", "/profile/user-a?from=tab",
  ]);
});

test("anonymous, offline, background and constrained mobile connections do not prefetch", () => {
  const loggedOut = prefetchFixture();
  loggedOut.schedule("", "/welcome");
  assert.equal(loggedOut.idleJobs.size, 0);
  for (const settings of [
    { online: false }, { visible: false },
    { saveData: true }, { effectiveType: "2g" }, { effectiveType: "slow-2g" },
  ]) {
    const f = prefetchFixture(settings);
    f.schedule();
    assert.equal(f.idleJobs.size, 0, JSON.stringify(settings));
    assert.equal(f.calls.length, 0);
  }
});

test("route changes cancel pending requests and next screen resumes remaining hints once", () => {
  const f = prefetchFixture();
  const cancel = f.schedule("user-a", "/");
  f.idle();
  assert.deepEqual(f.calls, ["/clubs"]);
  cancel();
  assert.equal(f.timeouts.size, 0);
  assert.equal(f.idleJobs.size, 0);
  f.schedule("user-a", "/clubs");
  f.idle();
  assert.deepEqual(f.calls, ["/clubs", "/"]);
});

test("network or visibility loss while queued stops further prefetch", () => {
  const f = prefetchFixture();
  f.schedule();
  f.idle();
  f.timer();
  f.navigator.onLine = false;
  f.idle();
  assert.deepEqual(f.calls, ["/clubs"]);
});

test("iOS fallback without requestIdleCallback still defers first route", () => {
  const f = prefetchFixture({ idle: false });
  f.schedule();
  assert.equal(f.calls.length, 0);
  assert.deepEqual([...f.timeouts.values()].map((job) => job.delay), [650]);
  f.timer();
  assert.deepEqual(f.calls, ["/clubs"]);
  assert.deepEqual([...f.timeouts.values()].map((job) => job.delay), [220]);
});

test("bounded mount-cache retains recently used screens and evicts the oldest only", () => {
  const exports = {};
  runInNewContext(compile(cacheSource, "mount-cache.ts"), { exports });
  const { setMountCache: put, getMountCache: get, deleteMountCacheByPrefix: clear } = exports;
  const limit = exports.MAX_MOUNT_CACHE_ENTRIES;
  assert.ok(limit >= 50 && limit <= 150);
  for (let i = 0; i < limit; i++) put(`profile:user-a:${i}`, { index: i });
  assert.equal(get("profile:user-a:0").index, 0);
  put("chat:user-a:recent", { index: "new" });
  assert.equal(get("profile:user-a:1"), undefined, "oldest unused screen was evicted");
  assert.equal(get("profile:user-a:0").index, 0, "recently visited screen stays warm");
  assert.equal(get("chat:user-a:recent").index, "new");
  clear("profile:");
  assert.equal(get("profile:user-a:0"), undefined);
  assert.equal(get("chat:user-a:recent").index, "new", "other cache namespaces survive");
});

test("source: app startup only warms route manifests after authentication; entry animation remains intact", () => {
  const root = readFileSync(new URL("../components/app-navigation-runtime.tsx", import.meta.url), "utf8");
  const chrome = readFileSync(new URL("../components/phase3-ui.tsx", import.meta.url), "utf8");
  const motion = readFileSync(new URL("../components/ui/page-transition.tsx", import.meta.url), "utf8");
  assert.doesNotMatch(root, /for \(const href of PREFETCH_ROUTES\) router\.prefetch/);
  assert.match(root, /requestIdleCallback\(register/);
  // Push display/wake-up lives in the service worker; startup never loads Firebase.
  assert.doesNotMatch(root, /listenForForegroundPush/);
  assert.match(chrome, /scheduleAppRoutePrefetch\(\(href\) => router\.prefetch\(href\), userId, pathname\)/);
  assert.match(motion, /<AnimatePresence mode="wait"/);
  assert.match(motion, /const DURATION = 0\.22;/);
  assert.match(motion, /const EXIT_DURATION = 0\.09;/);
  assert.match(motion, /transition: \{ duration: EXIT_DURATION, ease: EASE \}/);
});

test("source: Club discovery and membership load concurrently; Settings defers Firebase to its notification section", () => {
  const clubs = readFileSync(new URL("../components/clubs-routes.tsx", import.meta.url), "utf8");
  const explore = clubs.slice(clubs.indexOf("async function fetchExplore"), clubs.indexOf("function ExploreClubRow"));
  assert.match(explore, /const \[pages, membership\] = await Promise\.all\(\[/);
  assert.ok(explore.indexOf('client.from("club_members")') < explore.indexOf("const all = pages.flat()"));
  const settings = readFileSync(new URL("../components/settings-route.tsx", import.meta.url), "utf8");
  assert.match(settings, /if \(section !== "notifications"\) return;/);
  assert.match(settings, /\}, \[client, userId, section\]\);/);
  assert.ok(settings.indexOf('if (section !== "notifications") return;') < settings.indexOf("const availability = await getPushAvailability()"));
});
