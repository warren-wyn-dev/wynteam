import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const code = readFileSync(new URL("../lib/push-notifications.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(code, {
  fileName: "push-notifications.ts",
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

function fixture({
  userAgent = "Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/130",
  installed = true, permission = "default", configured = true,
  registerFails = false, noToken = false, serverFails = false,
} = {}) {
  const calls = [];
  const registration = {
    active: {},
    pushManager: { getSubscription: async () => null },
  };
  const Notification = {
    permission,
    requestPermission: async () => {
      calls.push("permission-request");
      Notification.permission = "granted";
      return "granted";
    },
  };
  const window = {
    Notification,
    PushManager: {},
    matchMedia: () => ({ matches: installed }),
    setTimeout: (fn) => { calls.push("worker-timeout-scheduled"); return setTimeout(fn, 1); },
    clearTimeout: clearTimeout,
  };
  const navigator = {
    userAgent, maxTouchPoints: /iPhone|iPad/i.test(userAgent) ? 5 : 0,
    serviceWorker: {
      register: async (path) => {
        calls.push("worker-register:" + path);
        if (registerFails) throw new Error("worker unavailable");
        return registration;
      },
      ready: Promise.resolve(registration),
      getRegistration: async () => registration,
    },
  };
  let firebaseTokenLookups = 0;
  const exports = {};
  runInNewContext(compiled, {
    exports, window, navigator, Notification,
    require: (name) => {
      if (name === "firebase/app") return {
        getApps: () => [],
        initializeApp: () => ({ name: "mock" }),
      };
      if (name === "firebase/messaging") return {
        isSupported: async () => true,
        getMessaging: () => ({}),
        getToken: async () => {
          firebaseTokenLookups += 1;
          calls.push("get-token");
          return noToken ? "" : "mock-web-token";
        },
        onMessage: () => undefined,
      };
      throw new Error("Unexpected module: " + name);
    },
    fetch: async (path) => {
      assert.equal(path, "/api/push-config");
      calls.push("fetch-config");
      return {
        ok: true,
        json: async () => ({
          configured, vapidKey: configured ? "public-test-vapid" : undefined,
          apiKey: "public-test-api", appId: "test-app",
          messagingSenderId: "123", projectId: "test-project",
        }),
      };
    },
    Date, setTimeout, clearTimeout,
  }, { filename: "push-notifications.compiled.js" });

  const client = {
    from: (table) => {
      assert.equal(table, "push_tokens");
      return {
        upsert: async (row) => {
          calls.push("upsert");
          assert.equal(row.user_id, "test-user");
          assert.equal(row.token, "mock-web-token");
          return { error: serverFails ? { message: "RLS test failure" } : null };
        },
      };
    },
  };
  return {
    availability: () => exports.getPushAvailability(),
    subscribe: () => exports.subscribeToPushNotifications(client, "test-user"),
    checkCurrent: () => exports.isCurrentDevicePushEnabled(client, "test-user"),
    install: (ua, points, standalone) => exports.isIosWebPushInstallRequired(ua, points, standalone),
    get calls() { return calls; },
    get tokenReads() { return firebaseTokenLookups; },
  };
}

const plain = (value) => JSON.parse(JSON.stringify(value));

test("iPhone Safari tab explains Home Screen requirement; installed iOS app is eligible", async () => {
  const ios = fixture({ userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)", installed: false });
  assert.equal(ios.install("Mozilla/5.0 (iPhone)", 5, false), true);
  assert.equal(ios.install("Mozilla/5.0 (iPad)", 5, true), false);
  assert.equal(ios.install("Mozilla/5.0 (Macintosh)", 5, false), true);
  assert.deepEqual(plain(await ios.availability()), { available: false, reason: "install-required" });
  assert.deepEqual(plain(await ios.subscribe()), { ok: false, reason: "install-required" });
  assert.deepEqual(ios.calls, [], "unsupported iPhone tab must not show a nonfunctional OS prompt");
});

test("blocked permission gives a clear denied result without prompting again", async () => {
  const f = fixture({ permission: "denied" });
  assert.deepEqual(plain(await f.availability()), { available: false, reason: "denied" });
  assert.deepEqual(plain(await f.subscribe()), { ok: false, reason: "denied" });
  assert.equal(f.calls.includes("permission-request"), false);
});

test("misconfigured production Firebase never claims Push is enabled", async () => {
  const f = fixture({ configured: false });
  assert.deepEqual(plain(await f.availability()), { available: false, reason: "not-configured" });
  assert.deepEqual(plain(await f.subscribe()), { ok: false, reason: "not-configured" });
  assert.equal(f.calls.includes("upsert"), false);
});

test("a real click prompts BEFORE config/Firebase work and enables only after a successful server write", async () => {
  const f = fixture();
  assert.deepEqual(plain(await f.subscribe()), { ok: true });
  assert.ok(f.calls.indexOf("permission-request") < f.calls.indexOf("fetch-config"));
  assert.ok(f.calls.indexOf("worker-register:/sw.js") < f.calls.indexOf("get-token"));
  assert.ok(f.calls.indexOf("get-token") < f.calls.indexOf("upsert"));
});

test("a failed token or RLS write keeps the toggle OFF with an actionable reason", async () => {
  const noToken = fixture({ noToken: true });
  assert.deepEqual(plain(await noToken.subscribe()), { ok: false, reason: "no-token" });
  assert.equal(noToken.calls.includes("upsert"), false);

  const blocked = fixture({ serverFails: true });
  assert.deepEqual(plain(await blocked.subscribe()), { ok: false, reason: "server-failed" });
  assert.equal(blocked.calls.includes("upsert"), true);
});

test("service worker registration failures no longer leave the user staring at a stuck switch", async () => {
  const f = fixture({ registerFails: true });
  assert.deepEqual(plain(await f.subscribe()), { ok: false, reason: "worker-failed" });
  assert.equal(f.calls.includes("upsert"), false);
});

test("checking an OFF toggle never creates a new Firebase subscription", async () => {
  const f = fixture({ permission: "granted" });
  assert.equal(await f.checkCurrent(), false);
  assert.equal(f.tokenReads, 0);
});

test("Settings always shows the Push row with a clear cause and keeps category toggles usable", () => {
  const source = readFileSync(new URL("../components/settings-route.tsx", import.meta.url), "utf8");
  for (const required of [
    "getPushAvailability()", "pushReasonDescription", "วิธีติดตั้ง WYNOS",
    "setPushEnabled(true)", "setPushEnabled(false)", "pushError",
    "notificationLabels.map", "updateNotificationSetting(client, userId, key, value)",
    'label="การแจ้งเตือนแบบพุช"', "role=\"alert\"",
  ]) assert.ok(source.includes(required), "Missing Push UX contract: " + required);
  assert.doesNotMatch(source, /\{pushAvailable \? <>/);
});

test("production deploy forwards PUBLIC Firebase config to build/runtime and checks Push readiness", () => {
  const source = readFileSync(new URL("../../.github/workflows/wyn-158-production-deploy.yml", import.meta.url), "utf8");
  for (const key of [
    "NEXT_PUBLIC_FIREBASE_API_KEY", "NEXT_PUBLIC_FIREBASE_APP_ID",
    "NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID", "NEXT_PUBLIC_FIREBASE_PROJECT_ID",
    "NEXT_PUBLIC_FIREBASE_VAPID_KEY",
  ]) assert.ok(source.includes(key), "Missing deployed public Firebase config: " + key);
  assert.match(source, /firebase_args\[@\]/);
  assert.match(source, /\/api\/push-config/);
  assert.doesNotMatch(source, /FCM_SERVICE_ACCOUNT|FIREBASE_PRIVATE_KEY/);
});
