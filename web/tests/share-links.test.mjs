import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
function load(now = () => 1_000_000) {
  const store = new Map();
  const window = { sessionStorage: {
    getItem: (k) => store.get(k) ?? null, setItem: (k, v) => store.set(k, String(v)), removeItem: (k) => store.delete(k),
  } };
  const out = ts.transpileModule(read("../lib/return-to.ts"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const mod = { exports: {} };
  runInNewContext(out, { module: mod, exports: mod.exports, window, JSON, Date: { now } });
  return { ...mod.exports, store };
}

test("only in-app, non-auth paths are ever remembered (no open redirect)", () => {
  const { isSafeReturnPath } = load();
  for (const ok of ["/drop/abc", "/@wynos_s", "/club/1?tab=posts", "/club-invite/XYZ", "/quote/1", "/quote/1#comments"]) assert.equal(isSafeReturnPath(ok), true, ok);
  for (const bad of ["https://evil.example/", "//evil.example", "/\\evil.example", "javascript:alert(1)", "/", "/welcome", "/login?x=1",
    "/signup/step-1", "/auth/callback", "drop/abc", "/drop/\nx", "/" + "a".repeat(600)]) assert.equal(isSafeReturnPath(bad), false, bad);
});

test("a shared link survives the login wall exactly once and expires", () => {
  let clock = 1_000_000;
  const r = load(() => clock);
  r.rememberReturnPath("/drop/abc");
  assert.equal(r.consumeReturnPath(), "/drop/abc");
  assert.equal(r.consumeReturnPath(), null, "consumed once");
  r.rememberReturnPath("https://evil.example/");
  assert.equal(r.consumeReturnPath(), null);
  r.rememberReturnPath("/club/1");
  clock += 61 * 60 * 1000;
  assert.equal(r.consumeReturnPath(), null, "expired after an hour");
  r.store.set("wynos.return-to.v1", JSON.stringify({ path: "//evil.example", at: clock }));
  assert.equal(r.consumeReturnPath(), null, "tampered storage is rejected");
});

test("login wall, sign-in, onboarding and sign-out are wired to the return path", () => {
  const gate = read("../components/developer-route-gate.tsx");
  const auth = read("../components/auth-flow/screens.tsx");
  // Shared-link visit keeps path, query and #fragment…
  assert.match(gate, /else rememberReturnPath\(`\$\{window\.location\.pathname\}\$\{window\.location\.search\}\$\{window\.location\.hash\}`\);\n\s+router\.replace\("\/welcome"\)/);
  // …but a tab that just lost a session (incl. cross-tab sign-out) clears it.
  assert.match(gate, /if \(previousSession && !nextSession\) signedOutFromSessionRef\.current = true;/);
  assert.match(gate, /if \(signedOutFromSessionRef\.current\) clearReturnPath\(\);/);
  assert.match(gate, /clearReturnPath\(\);\n\s+window\.location\.replace\("\/welcome"\)/);
  assert.match(auth, /hasProfile \? consumeReturnPath\(\) \?\? "\/" : "\/signup\/step-1"/);
  assert.match(auth, /router\.push\(consumeReturnPath\(\) \?\? "\/"\)/);
});
