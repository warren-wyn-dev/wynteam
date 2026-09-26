import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import ts from "typescript";

const source = readFileSync(new URL("../lib/pending-account-add.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

function fixture(stored = new Map()) {
  const session = new Map();
  const exports = {};
  const localStorage = {
    getItem: (key) => stored.get(key) ?? null,
    setItem: (key, value) => stored.set(key, value),
    removeItem: (key) => stored.delete(key),
  };
  const sessionStorage = {
    getItem: (key) => session.get(key) ?? null,
    setItem: (key, value) => session.set(key, value),
    removeItem: (key) => session.delete(key),
  };
  new Function("exports", "window", compiled)(exports, { localStorage, sessionStorage });
  return { api: exports, stored, session };
}

const A = "wynos.account.11111111-1111-4111-8111-111111111111";
const B = "wynos.account.22222222-2222-4222-8222-222222222222";
const KEY = "wynos.pending-add-account.v1";

test("add-account signup keeps a validated temporary slot without touching the active slot", () => {
  const { api, stored, session } = fixture();
  assert.equal(api.beginPendingAddAccount(A), true);
  assert.equal(api.hasAddAccountIntent(), true);
  assert.equal(session.get("wynos.add-account-intent.v1"), A);
  assert.equal(api.getPendingAddAccountSlotForTab(), A);
  assert.equal(api.getPendingAddAccountSlot(), A);
  assert.equal(stored.has("wynos.active-account-storage.v1"), false);
  api.beginPendingAddAccount("supabase.auth.token");
  assert.equal(api.getPendingAddAccountSlot(), A);
  api.clearPendingAddAccount(B);
  assert.equal(api.getPendingAddAccountSlot(), A);
  assert.equal(api.hasAddAccountIntent(), true);
  api.clearPendingAddAccount(A);
  assert.equal(api.getPendingAddAccountSlot(), null);
  assert.equal(api.hasAddAccountIntent(), false);
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

test("a provisional slot that expires leaves the explicit Add Account intent until cancellation", () => {
  const { api, stored } = fixture();
  api.beginPendingAddAccount(A);
  stored.set(KEY, JSON.stringify({ slot: A, startedAt: Date.now() - 25 * 60 * 60 * 1000 }));
  assert.equal(api.getPendingAddAccountSlot(), null);
  assert.equal(api.hasAddAccountIntent(), true);
  api.clearPendingAddAccount();
  assert.equal(api.hasAddAccountIntent(), false);
});

test("a normal signup tab cannot inherit another tab's provisional B identity", () => {
  const stored = new Map();
  const firstTab = fixture(stored);
  const secondTab = fixture(stored);
  firstTab.api.beginPendingAddAccount(A);
  assert.equal(secondTab.api.getPendingAddAccountSlot(), A);
  assert.equal(secondTab.api.getPendingAddAccountSlotForTab(), null);
  assert.equal(secondTab.api.hasAddAccountIntent(), false);
  assert.equal(secondTab.api.claimPendingAddAccountSlot(A), true);
  assert.equal(secondTab.api.getPendingAddAccountSlotForTab(), A);
  // A second new signup cannot use the previous tab's slot.
  firstTab.api.beginPendingAddAccount(B);
  assert.equal(secondTab.api.getPendingAddAccountSlotForTab(), null);
  secondTab.api.clearPendingAddAccount();
  assert.equal(firstTab.api.getPendingAddAccountSlotForTab(), B);
});

test("blocked sessionStorage cannot create a new account or mutate shared auth storage", () => {
  const api = {};
  const stored = new Map();
  const localStorage = {
    getItem: (key) => stored.get(key) ?? null,
    setItem: (key, value) => stored.set(key, value),
    removeItem: (key) => stored.delete(key),
  };
  const sessionStorage = {
    getItem: () => null,
    setItem: () => { throw new Error("Storage blocked"); },
    removeItem: () => { throw new Error("Storage blocked"); },
  };
  new Function("exports", "window", compiled)(api, { localStorage, sessionStorage });
  assert.equal(api.beginPendingAddAccount(A), false);
  assert.equal(api.getPendingAddAccountSlot(), null);
  assert.equal(api.getPendingAddAccountSlotForTab(), null);
  assert.equal(stored.size, 0);
});
