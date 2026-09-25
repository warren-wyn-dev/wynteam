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
  const draftOperations = { clears: 0, removedUsers: [] };
  runInNewContext(outputText, {
    exports,
    require: (path) => {
      if (path === "@/lib/query-persist-key") return { PERSIST_QUERY_CACHE_KEY: PERSIST_KEY };
      if (path === "@/lib/chat-draft-storage") return {
        clearSessionChatDrafts: () => { draftOperations.clears++; },
        clearChatDraftsForUser: (id) => { draftOperations.removedUsers.push(id); },
      };
      throw new Error("Unexpected import: " + path);
    },
    window: { localStorage },
    Date,
  }, { filename: "account-registry.compiled.js" });
  return { registry: exports, localStorage, draftOperations };
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


test("saved-account switches and removals erase private unsent chat text", () => {
  const { registry, localStorage, draftOperations } = harness();
  localStorage.setItem(REGISTRY_KEY, JSON.stringify([
    { userId: "A", storageKey: "wynos.account.A", lastUsedAt: 1 },
    { userId: "B", storageKey: "wynos.account.B", lastUsedAt: 2 },
  ]));
  localStorage.setItem(ACTIVE_KEY, "wynos.account.A");
  assert.equal(registry.activateSavedAccount("B"), true);
  assert.equal(draftOperations.clears, 1);
  registry.markAccountStorageActive("wynos.account.C");
  assert.equal(draftOperations.clears, 2);
  registry.markAccountStorageActive("wynos.account.C");
  assert.equal(draftOperations.clears, 2, "reopening same slot preserves its own text");
  registry.removeSavedAccount("B");
  assert.deepEqual(draftOperations.removedUsers, ["B"]);
});
