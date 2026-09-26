import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const PERSIST_KEY = "wynos-query-cache";
const REGISTRY_KEY = "wynos.saved-accounts.v1";
const ACTIVE_KEY = "wynos.active-account-storage.v1";

function harness() {
  const source = readFileSync(new URL("../lib/account-registry.ts", import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    fileName: "account-registry.ts",
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  });
  const cache = new Map();
  const localStorage = {
    getItem: (key) => cache.has(key) ? cache.get(key) : null,
    setItem: (key, value) => cache.set(key, String(value)),
    removeItem: (key) => cache.delete(key),
  };
  const exports = {};
  runInNewContext(outputText, {
    exports,
    require: (path) => {
      if (path === "@/lib/query-persist-key") return { PERSIST_QUERY_CACHE_KEY: PERSIST_KEY };
      throw new Error("Unexpected import: " + path);
    },
    window: { localStorage },
    Date,
  }, { filename: "account-registry.compiled.js" });
  return { registry: exports, localStorage };
}

test("switching saved accounts discards the previous user's persisted queries", () => {
  const { registry, localStorage } = harness();
  localStorage.setItem(REGISTRY_KEY, JSON.stringify([
    { userId: "A", storageKey: "wynos.account.A", lastUsedAt: 1 },
    { userId: "B", storageKey: "wynos.account.B", lastUsedAt: 2 },
  ]));
  localStorage.setItem(ACTIVE_KEY, "wynos.account.A");
  localStorage.setItem(PERSIST_KEY, '{"secret":"A-only-data"}');
  assert.equal(registry.activateSavedAccount("B"), true);
  assert.equal(localStorage.getItem(PERSIST_KEY), null);
  assert.equal(localStorage.getItem(ACTIVE_KEY), "wynos.account.B");
  assert.equal(JSON.parse(localStorage.getItem(REGISTRY_KEY)).length, 2);
});

test("adding a new account clears old cache but resuming the same slot retains it", () => {
  const { registry, localStorage } = harness();
  localStorage.setItem(ACTIVE_KEY, "wynos.account.A");
  localStorage.setItem(PERSIST_KEY, '{"secret":"A-only-data"}');
  registry.markAccountStorageActive("wynos.account.B");
  assert.equal(localStorage.getItem(PERSIST_KEY), null);
  assert.equal(localStorage.getItem(ACTIVE_KEY), "wynos.account.B");
  localStorage.setItem(PERSIST_KEY, '{"content":"B-data"}');
  registry.markAccountStorageActive("wynos.account.B");
  assert.equal(localStorage.getItem(PERSIST_KEY), '{"content":"B-data"}');
});

test("unknown account selection does not discard valid cached data", () => {
  const { registry, localStorage } = harness();
  localStorage.setItem(REGISTRY_KEY, JSON.stringify([{ userId: "A", storageKey: "wynos.account.A" }]));
  localStorage.setItem(PERSIST_KEY, '{"content":"A-data"}');
  assert.equal(registry.activateSavedAccount("unknown"), false);
  assert.equal(localStorage.getItem(PERSIST_KEY), '{"content":"A-data"}');
});

test("query provider and auth gate reuse shared cache key and clear on account identity changes", () => {
  const provider = readFileSync(new URL("../components/query-provider.tsx", import.meta.url), "utf8");
  const gate = readFileSync(new URL("../components/developer-route-gate.tsx", import.meta.url), "utf8");
  assert.match(provider, /key: PERSIST_QUERY_CACHE_KEY/);
  assert.match(gate, /previousSession\.user\.id !== nextSession\?\.user\.id/);
  assert.match(gate, /queryClient\.clear\(\)/);
});

function profileClient(userId, username = "new-account") {
  return {
    from: (table) => {
      assert.equal(table, "profiles");
      return {
        select: () => ({
          eq: (_field, id) => {
            assert.equal(id, userId);
            return { maybeSingle: async () => ({ data: { username, display_name: null, avatar_url: null }, error: null }) };
          },
        }),
      };
    },
  };
}

test("reusing an old signed-out slot replaces its stale identity, never duplicating it", async () => {
  const { registry, localStorage } = harness();
  const slot = "wynos.account.reused-slot";
  localStorage.setItem(REGISTRY_KEY, JSON.stringify([
    { userId: "A", storageKey: slot, lastUsedAt: 1 },
    { userId: "D", storageKey: "wynos.account.other-slot", lastUsedAt: 2 },
  ]));
  localStorage.setItem(ACTIVE_KEY, slot);
  const session = { user: { id: "C", email: "c@example.test", user_metadata: {} } };
  assert.equal(await registry.registerSessionAccount(profileClient("C"), session, slot), true);
  const accounts = JSON.parse(localStorage.getItem(REGISTRY_KEY));
  assert.deepEqual(accounts.map((item) => item.userId), ["C", "D"]);
  assert.equal(accounts.filter((item) => item.storageKey === slot).length, 1);
});

test("explicit logout removes only the old active slot, including stale aliases", () => {
  const { registry, localStorage } = harness();
  const old = "wynos.account.old-slot";
  const other = "wynos.account.other-slot";
  localStorage.setItem(REGISTRY_KEY, JSON.stringify([
    { userId: "A", storageKey: old, lastUsedAt: 1 },
    { userId: "C", storageKey: old, lastUsedAt: 2 },
    { userId: "D", storageKey: other, lastUsedAt: 3 },
  ]));
  localStorage.setItem(ACTIVE_KEY, old);
  localStorage.setItem(old, "old-session");
  localStorage.setItem(other, "another-account-session");
  localStorage.setItem(PERSIST_KEY, '{"private":"A-only"}');
  registry.forgetSignedOutAccount("C", old);
  assert.deepEqual(JSON.parse(localStorage.getItem(REGISTRY_KEY)).map((item) => item.userId), ["D"]);
  assert.equal(localStorage.getItem(ACTIVE_KEY), null);
  assert.equal(localStorage.getItem(old), null);
  assert.equal(localStorage.getItem(other), "another-account-session");
  assert.equal(localStorage.getItem(PERSIST_KEY), null);
});

test("a logout finishing in an old tab does not reset another tab's newer active account", () => {
  const { registry, localStorage } = harness();
  const old = "wynos.account.old-slot";
  const other = "wynos.account.other-slot";
  localStorage.setItem(REGISTRY_KEY, JSON.stringify([
    { userId: "A", storageKey: old, lastUsedAt: 1 },
    { userId: "B", storageKey: other, lastUsedAt: 2 },
  ]));
  localStorage.setItem(ACTIVE_KEY, other);
  localStorage.setItem(other, "B-still-signed-in");
  registry.forgetSignedOutAccount("A", old);
  assert.equal(localStorage.getItem(ACTIVE_KEY), other);
  assert.equal(localStorage.getItem(other), "B-still-signed-in");
  assert.deepEqual(JSON.parse(localStorage.getItem(REGISTRY_KEY)).map((item) => item.userId), ["B"]);
});
