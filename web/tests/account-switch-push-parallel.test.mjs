import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const pushSource = readFileSync(new URL("../lib/push-notifications.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(pushSource, {
  fileName: "push-notifications.ts",
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

function fixture({ active = true } = {}) {
  const calls = [];
  let dbResolve;
  let fcmResolve;
  const serverRequest = new Promise((resolve) => { dbResolve = resolve; });
  const fcmRequest = new Promise((resolve) => { fcmResolve = resolve; });
  const registration = {
    pushManager: {
      getSubscription: async () => active ? { endpoint: "https://push.invalid/test" } : null,
    },
  };
  const modules = {
    "firebase/app": {
      getApps: () => [],
      initializeApp: () => ({ name: "mock-only" }),
    },
    "firebase/messaging": {
      getMessaging: () => ({ name: "mock-only" }),
      getToken: async () => "mock-device-token",
      deleteToken: () => {
        calls.push("fcm-revoke-started");
        return fcmRequest;
      },
    },
  };
  const client = {
    from: (table) => {
      assert.equal(table, "push_tokens");
      return {
        delete: () => ({
          eq: (field, token) => {
            assert.equal(field, "token");
            assert.equal(token, "mock-device-token");
            calls.push("db-revoke-started");
            return serverRequest;
          },
        }),
      };
    },
  };
  const exports = {};
  runInNewContext(compiled, {
    exports,
    require: (name) => {
      if (!(name in modules)) throw new Error("Unexpected module " + name);
      return modules[name];
    },
    navigator: {
      serviceWorker: { getRegistration: async () => registration },
    },
    Notification: { permission: "granted" },
    fetch: async () => {
      calls.push("config-fetched");
      return {
        ok: true,
        json: async () => ({
          configured: true,
          apiKey: "mock-api-key", appId: "mock-app-id",
          messagingSenderId: "123", projectId: "mock-project", vapidKey: "mock-vapid",
        }),
      };
    },
  }, { filename: "push-notifications.compiled.js" });
  return {
    unsubscribe: () => exports.unsubscribeFromPushNotifications(client),
    prewarm: () => exports.prewarmAccountSwitchPush(),
    calls,
    dbResolve,
    fcmResolve,
  };
}

async function settleUntil(predicate) {
  for (let attempt = 0; attempt < 80 && !predicate(); attempt += 1) {
    await Promise.resolve();
  }
  assert.equal(predicate(), true, "Expected both independent Push operations to start");
}

test("Firebase and DB Push detachment start together and BOTH must finish before switching", async () => {
  const f = fixture();
  let finished = false;
  const pending = f.unsubscribe().then((result) => { finished = true; return result; });
  await settleUntil(() =>
    f.calls.includes("db-revoke-started") && f.calls.includes("fcm-revoke-started"));
  assert.equal(f.calls.filter((call) => call === "config-fetched").length, 1);

  f.dbResolve({ error: null });
  await Promise.resolve();
  await Promise.resolve();
  assert.equal(finished, false, "do not activate B while Firebase revoke is still running");

  f.fcmResolve(true);
  assert.equal(await pending, true);
  assert.equal(finished, true);
});

test("an unsuccessful Firebase revoke blocks the switch even after server deletion", async () => {
  const f = fixture();
  const pending = f.unsubscribe();
  await settleUntil(() =>
    f.calls.includes("db-revoke-started") && f.calls.includes("fcm-revoke-started"));
  f.dbResolve({ error: null });
  f.fcmResolve(false);
  assert.equal(await pending, false);
});

test("a failed database deletion also blocks the switch even if FCM revocation succeeds", async () => {
  const f = fixture();
  const pending = f.unsubscribe();
  await settleUntil(() =>
    f.calls.includes("db-revoke-started") && f.calls.includes("fcm-revoke-started"));
  f.dbResolve({ error: { message: "offline" } });
  f.fcmResolve(true);
  assert.equal(await pending, false);
});

test("prewarming with no active Push subscription does not load Firebase or issue revocations", async () => {
  const f = fixture({ active: false });
  f.prewarm();
  for (let i = 0; i < 15; i += 1) await Promise.resolve();
  assert.deepEqual(f.calls, []);
});
