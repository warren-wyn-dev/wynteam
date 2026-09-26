import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const source = readFileSync(new URL("../lib/account-switch-session.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  fileName: "account-switch-session.ts",
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

const SLOT = "wynos.account.bbbbbbbb";
const A = "account-a";
const B = "account-b";
const account = { userId: B, storageKey: SLOT };

function fixture({ slot, user = B, error = null, offline = false } = {}) {
  const storage = new Map();
  if (slot !== false) {
    storage.set(SLOT, JSON.stringify(slot ?? {
      access_token: "mock-access", refresh_token: "mock-refresh", user: { id: B },
    }));
  }
  const calls = [];
  const sessionClient = {
    auth: {
      getUser: async () => {
        calls.push(["getUser"]);
        if (error instanceof Error) throw error;
        return { data: { user: user ? { id: user } : null }, error };
      },
    },
  };
  const exports = {};
  runInNewContext(compiled, {
    exports,
    require: (name) => {
      if (name === "@supabase/supabase-js") return {
        createClient: (url, key, options) => {
          calls.push(["slotClient", url, key, options]);
          return sessionClient;
        },
      };
      if (name === "@supabase/ssr") return {
        createBrowserClient: (url, key, options) => {
          calls.push(["cookieClient", url, key, options]);
          return sessionClient;
        },
      };
      throw new Error("Unexpected import " + name);
    },
    window: {
      localStorage: {
        getItem: (key) => storage.get(key) ?? null,
      },
    },
    navigator: { onLine: !offline },
    process: {
      env: {
        NEXT_PUBLIC_SUPABASE_URL: "https://test.supabase.co",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_test",
      },
    },
  }, { filename: "account-switch-session.compiled.js" });
  // Normalize VM-returned records into this realm for strict assertions.
  return { check: async (item) => JSON.parse(JSON.stringify(await exports.checkSavedAccountSession(item))), calls, storage };
}

test("a saved slot is server-verified without background refresh or OAuth URL detection", async () => {
  const f = fixture();
  assert.deepEqual(await f.check(account), { ok: true });
  assert.equal(f.calls[0][0], "slotClient");
  assert.equal(f.calls[0][3].auth.storageKey, SLOT);
  assert.equal(f.calls[0][3].auth.autoRefreshToken, false);
  assert.equal(f.calls[0][3].auth.detectSessionInUrl, false);
  assert.equal(f.calls.filter((call) => call[0] === "getUser").length, 1);
});

test("a removed slot cannot replace the working account", async () => {
  const f = fixture({ slot: false });
  assert.deepEqual(await f.check(account), { ok: false, reason: "missing" });
  assert.equal(f.calls.length, 0);
});

test("locally mismatched and incomplete sessions are rejected without a network request", async () => {
  const mismatch = fixture({ slot: {
    access_token: "mock-access", refresh_token: "mock-refresh", user: { id: A },
  } });
  assert.deepEqual(await mismatch.check(account), { ok: false, reason: "mismatch" });
  assert.equal(mismatch.calls.length, 0);

  const incomplete = fixture({ slot: { user: { id: B } } });
  assert.deepEqual(await incomplete.check(account), { ok: false, reason: "missing" });
  assert.equal(incomplete.calls.length, 0);
});

test("Auth server identity must match the selected registry entry", async () => {
  const f = fixture({ user: A });
  assert.deepEqual(await f.check(account), { ok: false, reason: "mismatch" });
});

test("a reused refresh token gives an expired-session result without activating the account", async () => {
  const f = fixture({ error: { code: "refresh_token_already_used" } });
  assert.deepEqual(await f.check(account), { ok: false, reason: "expired" });
});

test("offline and thrown network failures never activate another user's session", async () => {
  const offline = fixture({ offline: true });
  assert.deepEqual(await offline.check(account), { ok: false, reason: "network" });
  assert.equal(offline.calls.length, 0);
  const failed = fixture({ error: new Error("Network unavailable") });
  assert.deepEqual(await failed.check(account), { ok: false, reason: "network" });
});

test("the legacy default cookie account is checked through a separate non-refreshing client", async () => {
  const f = fixture();
  assert.deepEqual(await f.check({ userId: B, storageKey: null }), { ok: true });
  assert.equal(f.calls[0][0], "cookieClient");
  assert.equal(f.calls[0][3].isSingleton, false);
  assert.equal(f.calls[0][3].auth.autoRefreshToken, false);
  assert.equal(f.calls[0][3].auth.detectSessionInUrl, false);
});

test("source: account verification precedes Push detachment and slot activation", () => {
  const profile = readFileSync(new URL("../components/profile-route.tsx", import.meta.url), "utf8");
  const switcher = profile.slice(profile.indexOf("const switchToAccount ="), profile.indexOf("const addAnotherAccount ="));
  assert.ok(switcher.indexOf("checkSavedAccountSession(account)") >= 0);
  assert.ok(switcher.indexOf("checkSavedAccountSession(account)") < switcher.indexOf("detachPushBeforeAccountChange()"));
  assert.ok(switcher.indexOf("detachPushBeforeAccountChange()") < switcher.indexOf("activateSavedAccount(account.userId)"));
  assert.ok(switcher.includes("accountOperationInFlight.current"));
  const add = profile.slice(profile.indexOf("const addAnotherAccount ="), profile.indexOf("const removeAccountFromSwitcher ="));
  assert.doesNotMatch(add, /detachPushBeforeAccountChange/);
});

test("source: add-account OAuth completion is serialized and only detaches on success path", () => {
  const add = readFileSync(new URL("../components/account-add-route.tsx", import.meta.url), "utf8");
  assert.match(add, /finishInFlight\.current = true/);
  assert.match(add, /if \(!client \|\| finishInFlight\.current\) return/);
  assert.ok(add.indexOf("unsubscribeFromPushNotifications(prior)") < add.indexOf("markAccountStorageActive(storageKey)"));
});

test("source: other tabs reload their singleton and clear stale queries on active account change", () => {
  const provider = readFileSync(new URL("../components/query-provider.tsx", import.meta.url), "utf8");
  assert.match(provider, /event\.key !== ACTIVE_ACCOUNT_STORAGE_KEY/);
  assert.match(provider, /window\.addEventListener\("storage", handleStorage\)/);
  assert.match(provider, /client\.clear\(\);\s*window\.location\.reload\(\)/);
});
