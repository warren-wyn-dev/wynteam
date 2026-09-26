import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const source = readFileSync(new URL("../lib/account-switch-preflight.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  fileName: "account-switch-preflight.ts",
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

const SLOT = "wynos.account.test-fast-switch";
const B = "account-b";
const account = { userId: B, storageKey: SLOT };
const normalize = (value) => JSON.parse(JSON.stringify(value));

function fixture({ cookie = "sb-test-auth=account-b" } = {}) {
  const storage = new Map([[SLOT, JSON.stringify({
    access_token: "mock-access-1",
    refresh_token: "mock-refresh-1",
    user: { id: B },
  })]]);
  let now = 100_000;
  let online = true;
  let reads = 0;
  let verifier;
  const document = { cookie };
  const navigator = { onLine: true };
  const exports = {};

  const defaultCheck = async (item) => {
    if (!item.storageKey) return { ok: true };
    const raw = storage.get(item.storageKey);
    if (!raw) return { ok: false, reason: "missing" };
    const session = JSON.parse(raw);
    return session.user?.id === item.userId
      ? { ok: true } : { ok: false, reason: "mismatch" };
  };

  class FakeDate extends Date {
    static now() { return now; }
  }
  runInNewContext(compiled, {
    exports,
    require: (name) => {
      if (name === "@/lib/account-switch-session") {
        return {
          checkSavedAccountSession: async (item) => {
            reads += 1;
            return (verifier ?? defaultCheck)(item);
          },
        };
      }
      throw new Error(`Unexpected module: ${name}`);
    },
    window: { localStorage: { getItem: (key) => storage.get(key) ?? null } },
    document,
    navigator,
    Date: FakeDate,
  }, { filename: "account-switch-preflight.compiled.js" });

  return {
    warm: async (item = account) => normalize(await exports.prewarmSavedAccountSession(item)),
    select: async (item = account) => normalize(await exports.getPreparedSavedAccountSession(item)),
    rawWarm: exports.prewarmSavedAccountSession,
    get reads() { return reads; },
    get ttl() { return exports.SWITCH_PREFLIGHT_TTL_MS; },
    setVerifier: (fn) => { verifier = fn; },
    changeSlot: (value) => { storage.set(SLOT, JSON.stringify(value)); },
    removeSlot: () => { storage.delete(SLOT); },
    changeCookie: (value) => { document.cookie = value; },
    setOnline: (value) => { online = value; navigator.onLine = value; },
    advance: (ms) => { now += ms; },
    isOnline: () => online,
  };
}

test("the menu warms a real Auth check and a tap reuses it without another network read", async () => {
  const f = fixture();
  assert.deepEqual(await f.warm(), { ok: true });
  assert.deepEqual(await f.select(), { ok: true });
  assert.equal(f.reads, 1, "ready saved account should not recheck the network on tap");
  assert.ok(f.ttl > 0 && f.ttl <= 15_000);
});

test("rapid taps and the idle warm-up share one in-flight Auth request", async () => {
  const f = fixture();
  let release;
  f.setVerifier(() => new Promise((resolve) => { release = resolve; }));
  const first = f.rawWarm(account);
  const second = f.rawWarm(account);
  const selected = f.select();
  assert.strictEqual(first, second);
  assert.equal(f.reads, 1);
  release({ ok: true });
  assert.deepEqual(normalize(await first), { ok: true });
  assert.deepEqual(await selected, { ok: true });
  assert.equal(f.reads, 1);
});

test("an expired preflight must reverify before changing accounts", async () => {
  const f = fixture();
  await f.warm();
  f.advance(f.ttl + 1);
  assert.deepEqual(await f.select(), { ok: true });
  assert.equal(f.reads, 2);
});

test("a changed session token after warm-up invalidates its earlier proof", async () => {
  const f = fixture();
  await f.warm();
  f.changeSlot({ access_token: "mock-access-2", refresh_token: "mock-refresh-2", user: { id: B } });
  assert.deepEqual(await f.select(), { ok: true });
  assert.equal(f.reads, 2);
});

test("a different user or a removed slot never reuses the prior verified result", async () => {
  const other = fixture();
  await other.warm();
  other.changeSlot({ access_token: "other", refresh_token: "other", user: { id: "account-c" } });
  assert.deepEqual(await other.select(), { ok: false, reason: "mismatch" });
  assert.equal(other.reads, 2);

  const missing = fixture();
  await missing.warm();
  missing.removeSlot();
  assert.deepEqual(await missing.select(), { ok: false, reason: "missing" });
  assert.equal(missing.reads, 2);
});

test("a session that changes WHILE Auth is verifying is not cached", async () => {
  const f = fixture();
  let release;
  f.setVerifier(() => new Promise((resolve) => { release = resolve; }));
  const pending = f.warm();
  f.changeSlot({ access_token: "changed", refresh_token: "changed", user: { id: B } });
  release({ ok: true });
  assert.deepEqual(await pending, { ok: true });
  f.setVerifier(async () => ({ ok: true }));
  assert.deepEqual(await f.select(), { ok: true });
  assert.equal(f.reads, 2);
});

test("an unsuccessful preflight is not cached, and a later tap can retry", async () => {
  const f = fixture();
  f.setVerifier(async () => f.reads === 1
    ? { ok: false, reason: "network" }
    : { ok: true });
  assert.deepEqual(await f.warm(), { ok: false, reason: "network" });
  assert.deepEqual(await f.select(), { ok: true });
  assert.equal(f.reads, 2);
});

test("offline after preflight cannot silently claim a cached session is verified", async () => {
  const f = fixture();
  await f.warm();
  f.setOnline(false);
  f.setVerifier(async () => ({ ok: false, reason: "network" }));
  assert.deepEqual(await f.select(), { ok: false, reason: "network" });
  assert.equal(f.reads, 2);
});

test("a default cookie account is rechecked when its cookies change in another tab", async () => {
  const f = fixture();
  const defaultAccount = { userId: B, storageKey: null };
  await f.warm(defaultAccount);
  assert.deepEqual(await f.select(defaultAccount), { ok: true });
  assert.equal(f.reads, 1);
  f.changeCookie("sb-test-auth=different-session");
  assert.deepEqual(await f.select(defaultAccount), { ok: true });
  assert.equal(f.reads, 2);
});
