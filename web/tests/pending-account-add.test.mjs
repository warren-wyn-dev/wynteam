import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import ts from "typescript";

const source = readFileSync(new URL("../lib/pending-account-add.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

function fixture() {
  const stored = new Map();
  const exports = {};
  const localStorage = {
    getItem: (key) => stored.get(key) ?? null,
    setItem: (key, value) => stored.set(key, value),
    removeItem: (key) => stored.delete(key),
  };
  new Function("exports", "window", compiled)(exports, { localStorage });
  return { api: exports, stored };
}

const A = "wynos.account.11111111-1111-4111-8111-111111111111";
const B = "wynos.account.22222222-2222-4222-8222-222222222222";
const KEY = "wynos.pending-add-account.v1";

test("add-account signup keeps a validated temporary slot without touching the active slot", () => {
  const { api, stored } = fixture();
  api.beginPendingAddAccount(A);
  assert.equal(api.getPendingAddAccountSlot(), A);
  assert.equal(stored.has("wynos.active-account-storage.v1"), false);
  api.beginPendingAddAccount("supabase.auth.token");
  assert.equal(api.getPendingAddAccountSlot(), A);
  api.clearPendingAddAccount(B);
  assert.equal(api.getPendingAddAccountSlot(), A);
  api.clearPendingAddAccount(A);
  assert.equal(api.getPendingAddAccountSlot(), null);
});

test("invalid or expired pending slots are never accepted by callback paths", () => {
  const { api, stored } = fixture();
  assert.equal(api.validAddAccountSlot(A), true);
  assert.equal(api.validAddAccountSlot("wynos.account.no"), false);
  assert.equal(api.validAddAccountSlot(null), false);
  stored.set(KEY, JSON.stringify({ slot: A, startedAt: Date.now() - 25 * 60 * 60 * 1000 }));
  assert.equal(api.getPendingAddAccountSlot(), null);
  assert.equal(stored.has(KEY), false);
  stored.set(KEY, JSON.stringify({ slot: "../active", startedAt: Date.now() }));
  assert.equal(api.getPendingAddAccountSlot(), null);
  assert.equal(stored.has(KEY), false);
});
