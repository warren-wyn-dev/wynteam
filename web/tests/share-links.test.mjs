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

function loadInApp() {
  const out = ts.transpileModule(read("../lib/in-app-browser.ts"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const mod = { exports: {} };
  runInNewContext(out, { module: mod, exports: mod.exports });
  return mod.exports;
}

test("in-app browsers of chat/social apps are recognised, real browsers and link-preview bots are not", () => {
  const { detectInAppBrowser } = loadInApp();
  const cases = {
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari Line/14.16.0": "LINE",
    "Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36 Line/14.16.0/IAB": "LINE",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 [FBAN/FBIOS;FBAV/480.0]": "Facebook",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Instagram 350.0": "Instagram",
    "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130.0 Mobile Safari/537.36 musical_ly_2023 BytedanceWebview/d8a21c6": "TikTok",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1": null,
    "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130.0 Mobile Safari/537.36": null,
    "facebookexternalhit/1.1;line-poker/1.0": null,
  };
  for (const [ua, expected] of Object.entries(cases)) assert.equal(detectInAppBrowser(ua), expected, ua);
});

test("LINE's browser is bounced to Safari/Chrome once, never on API, assets or the OAuth return", () => {
  const config = read("../next.config.ts");
  assert.match(config, /source: "\/:path\(\(\?!api\(\?:\/\|\$\)\|_next\/\|auth\(\?:\/\|\$\)\)\[\^\.\]\*\)"/);
  assert.match(config, /value: "\.\* Line\/\.\*"/);
  assert.match(config, /\{ type: "query", key: "openExternalBrowser" \}/);
  assert.match(config, /\{ type: "query", key: "code" \}/);
  assert.match(config, /destination: "\/:path\?openExternalBrowser=1",\n\s+permanent: false/);
});
