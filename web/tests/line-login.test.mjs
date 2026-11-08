// ZOKY-LINE-002 PR-3: code-level QA harness for LINE Login (design A, T1).
// Pure unit/static checks plus mock Supabase clients. No real LINE/Supabase,
// no secrets, no network. Staging-only cases (T-A1, T-A1b, T-A5..T-A7, T-A9..T-A11,
// T-A14, T-A16, T-A17, T-A19) cannot be proven here and need the real provider.
import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";
import ts from "typescript";

import {
  LINE_OAUTH,
  isLineLoginEnabled,
  isLineLoginTestMode,
  rememberLineAutoLink,
  safeLineDestination,
  takeLineAutoLink,
} from "../lib/line-liff.ts";

const root = new URL("..", import.meta.url).pathname;
const read = (path) => readFileSync(join(root, path), "utf8");
/** Source with comments removed, so prose cannot trip or hide a code assertion. */
const code = (source) => source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:])\/\/.*$/gm, "$1");
const auth = read("components/food/food-auth.tsx");
const button = code(read("components/food/line-login-button.tsx"));
const callback = code(read("app/food/auth/callback/page.tsx"));
const oauth = read("lib/google-pwa-oauth.ts");

/** Source of `async function line() {...}` in food-auth, brace-matched. */
function lineHandlerSource() {
  const start = auth.indexOf("async function line()");
  assert.ok(start > 0, "line() handler exists");
  const open = auth.indexOf("{", start);
  let depth = 0;
  for (let i = open; i < auth.length; i++) {
    if (auth[i] === "{") depth++;
    if (auth[i] === "}" && --depth === 0) return auth.slice(start, i + 1);
  }
  throw new Error("unterminated line()");
}

function walk(dir, out = []) {
  for (const name of readdirSync(join(root, dir))) {
    if (["node_modules", ".next", "merchant_flutter", "tests"].includes(name)) continue;
    const rel = `${dir}/${name}`;
    if (statSync(join(root, rel)).isDirectory()) walk(rel, out);
    else if (/\.(ts|tsx)$/.test(name)) out.push(rel);
  }
  return out;
}

// ---------- T-A18: flag off = no button, no LINE call, old behaviour ----------

test("T-A18 flag is strict: only \"1\" enables LINE Login", () => {
  for (const v of [undefined, "", "0", "true", "yes", "on", "2", " 1", "1 ", "TRUE"]) {
    assert.equal(isLineLoginEnabled(v), false, String(v));
  }
  assert.equal(isLineLoginEnabled("1"), true);
});

test("staging test mode: \"1\" is LIFF-only, only exact \"test\" shows outside LIFF", () => {
  assert.equal(isLineLoginEnabled("1"), true);
  assert.equal(isLineLoginTestMode("1"), false);
  assert.equal(isLineLoginEnabled("test"), true);
  assert.equal(isLineLoginTestMode("test"), true);
  for (const v of [undefined, "", "TEST", "Test", "true", "yes", " test", "test ", "0"]) {
    assert.equal(isLineLoginEnabled(v), false, String(v));
    assert.equal(isLineLoginTestMode(v), false, String(v));
  }
  // Button: test mode bypasses only the LINE-client/LIFF gate, never the iOS PWA refusal or busy state.
  assert.match(button, /testMode \? \(iosPwa \? "unavailable" : "ready"\) : slot/);
  assert.match(button, /if \(!inLine && !testMode\) return null/);
  assert.match(button, /liff\.isInClient\(\) \? "ready" : "unavailable"/);
  assert.match(button, /testMode \? <p className="wf-auth-line-test-badge">/);
  assert.match(button, /disabled=\{busy\}/);
  // Handler is unchanged: canonical callback without query, iOS PWA refused, no prompt/scopes.
  const handler = code(lineHandlerSource());
  assert.match(handler, /new URL\("\/food\/auth\/callback", canonicalOrigin\)/);
  assert.match(handler, /isInstalledIosWebApp\(\)/);
  assert.doesNotMatch(handler, /prompt|scopes|queryParams|isLineLoginTestMode/);
  assert.ok(read("lib/i18n/en.ts").includes('"โหมดทดสอบ (staging) — ไม่ใช่ปุ่มสำหรับผู้ใช้จริง":'));
});

test("T-A18 flag off: the button is not rendered and line() refuses before touching Supabase", () => {
  assert.match(auth, /\{isLineLoginEnabled\(\) \? \(\s*<LineLoginButton[\s\S]*?\) : null\}/);
  const handler = lineHandlerSource();
  assert.ok(handler.indexOf("!isLineLoginEnabled()") > 0);
  assert.ok(handler.indexOf("!isLineLoginEnabled()") < handler.indexOf("startOAuth("));
  // LineLoginButton is only ever mounted by FoodLoginScreen.
  const users = walk("components").concat(walk("app"), walk("lib"))
    .filter((f) => read(f).includes("<LineLoginButton") && f !== "components/food/line-login-button.tsx");
  assert.deepEqual(users, ["components/food/food-auth.tsx"]);
});

test("T-A18/T-A8 flag off keeps Google and email handlers on the original code path", () => {
  assert.match(auth, /startGoogleOAuth\(client, callback\.href\)/);
  assert.match(auth, /signInWithEmail\(client, normalized, password\)/);
  assert.match(oauth, /queryParams: \{ prompt: "select_account" \}/);
  // lineLoading only adds a false-by-default term to existing disabled checks.
  assert.match(auth, /const \[lineLoading, setLineLoading\] = useState\(false\)/);
});

// ---------- scope: food only (T-A13) ----------

test("T-A13 LINE Login provider is referenced only by the allowed Food/lib files", () => {
  const allowed = new Set([
    "lib/line-liff.ts",
    "components/food/food-auth.tsx",
    "components/food/line-login-button.tsx",
  ]);
  const hits = [...walk("components"), ...walk("app"), ...walk("lib"), ...walk("scripts").filter(() => false)]
    .filter((f) => /custom:line|LINE_OAUTH|LINE_LOGIN_PROVIDER|isLineLoginEnabled/.test(read(f)))
    .filter((f) => !allowed.has(f));
  assert.deepEqual(hits, []);
  // Social, Merchant and Admin auth surfaces are untouched.
  for (const file of ["components/auth-flow/screens.tsx", "app/auth/callback/page.tsx"]) {
    assert.doesNotMatch(read(file), /LINE|custom:line/);
  }
});

// ---------- provider request shape (T-A1 precondition, T-A4/T-A17 client side) ----------

test("LINE sign-in request: custom:line, fixed callback, no prompt, no scopes, no email", async () => {
  const previous = { window: globalThis.window, navigator: globalThis.navigator };
  globalThis.window = { location: { origin: "https://zoky.wynos.online" }, matchMedia: () => ({ matches: false }) };
  Object.defineProperty(globalThis, "navigator", { configurable: true, value: { userAgent: "Mozilla/5.0 Line/14.0.0 LIFF", maxTouchPoints: 0 } });
  try {
    const transpiled = ts.transpileModule(oauth, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
    const mod = { exports: {} };
    new Function("module", "exports", "process", transpiled)(mod, mod.exports, process);
    const seen = [];
    const client = { auth: { signInWithOAuth: async (args) => { seen.push(args); return { data: { url: "https://x.supabase.co/auth/v1/authorize" }, error: null }; } } };
    const redirect = "https://zoky.wynos.online/food/auth/callback";
    const result = await mod.exports.startOAuth(client, redirect, LINE_OAUTH);
    assert.equal(result.started, true);
    assert.deepEqual(seen, [{ provider: "custom:line", options: { redirectTo: redirect } }]);
    const sent = JSON.stringify(seen[0]);
    for (const banned of ["select_account", "scopes", "email", "prompt", "skipBrowserRedirect", "nonce", "state"]) {
      assert.equal(sent.includes(banned), false, banned);
    }
  } finally {
    globalThis.window = previous.window;
    if (previous.navigator === undefined) delete globalThis.navigator;
    else Object.defineProperty(globalThis, "navigator", { configurable: true, value: previous.navigator });
  }
});

test("redirect_to is never client-controlled: fixed canonical origin + exact callback path, no input", () => {
  const handler = lineHandlerSource();
  assert.match(handler, /const canonicalOrigin = foodAuthOrigin\(\)/);
  assert.match(handler, /new URL\("\/food\/auth\/callback", canonicalOrigin\)/);
  assert.match(handler, /window\.location\.origin !== canonicalOrigin/);
  assert.doesNotMatch(handler, /searchParams|location\.(search|hash|href)|URLSearchParams|[?&](to|next|redirect)=|document\.referrer|localStorage|sessionStorage/);
  // No source under Food/lib sets Supabase's redirect_to directly.
  for (const file of [...walk("components/food"), "lib/google-pwa-oauth.ts", "lib/line-liff.ts", "app/food/auth/callback/page.tsx"]) {
    assert.doesNotMatch(read(file), /redirect_to/, file);
  }
});

test("LINE button never sets the iOS PWA path or Google-specific messages", () => {
  assert.match(auth, /isInstalledIosWebApp\(\)\) \{\s*setLineError\(failed\)/);
  assert.doesNotMatch(JSON.stringify(LINE_OAUTH.messages), /Google/);
});

// ---------- T-A4: open redirect / destination injection ----------

const EVIL = [
  "https://evil.test", "http://evil.test/food", "//evil.test", "/\\evil.test", "\\\\evil.test",
  "javascript:alert(1)", "/food/../evil", "%2f%2fevil.test", "/%2fevil.test", "/food%5c@evil.test",
  "/food%252f%252fevil.test", "/food\r\nLocation: https://evil.test", "/food?to=https://evil.test",
  "/food?next=//evil.test", "/food/auth/callback?next=https://evil.test", "/s/ABCDEF", "/s/abc", "/s/abcdefg",
  "/s/kbs7xa?next=https://evil.test", "/food?store=not-a-uuid", `/food?order=${"WF".repeat(40)}`,
  "/merchant", "/line?to=/food", "/food#//evil.test", `/${"a".repeat(80)}`, "", null,
];

test("T-A4 safeLineDestination collapses every injected destination to /food", () => {
  for (const bad of EVIL) assert.equal(safeLineDestination("food", bad), "/food", String(bad));
  for (const ok of ["/food", "/food?order=WF0015", "/food?order=ZF-0036", "/s/kbs7xa", "/food?store=1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed"]) {
    assert.equal(safeLineDestination("food", ok), ok);
  }
});

function withStorage(fn) {
  const previous = globalThis.window;
  const store = new Map();
  globalThis.window = { localStorage: {
    getItem: (k) => store.get(k) ?? null,
    setItem: (k, v) => store.set(k, v),
    removeItem: (k) => store.delete(k),
  } };
  try { return fn(store); } finally { globalThis.window = previous; }
}

test("T-A4 auto-link destination survives a LINE Login round trip only through the allowlist, once", () => {
  withStorage((store) => {
    rememberLineAutoLink("/s/kbs7xa");
    assert.equal(store.size, 1);
    assert.equal(takeLineAutoLink(), "/s/kbs7xa");
    assert.equal(store.size, 0);
    assert.equal(takeLineAutoLink(), null);

    rememberLineAutoLink("https://evil.test");
    assert.equal(takeLineAutoLink(), "/food");

    // Tampered storage value is re-validated at read time.
    store.set("zoky.line-autolink.v1", JSON.stringify({ at: Date.now(), to: "//evil.test" }));
    assert.equal(takeLineAutoLink(), "/food");

    // Expired (> 30 min) and malformed values are dropped.
    store.set("zoky.line-autolink.v1", JSON.stringify({ at: Date.now() - 31 * 60 * 1000, to: "/food" }));
    assert.equal(takeLineAutoLink(), null);
    store.set("zoky.line-autolink.v1", "{not json");
    assert.equal(takeLineAutoLink(), null);
  });
});

test("LINE button and handler never read, write or clear the auto-link key or guest basket", () => {
  for (const source of [code(lineHandlerSource()), button]) {
    assert.doesNotMatch(source, /AutoLink|localStorage|sessionStorage|removeItem|\.clear\(|GUEST_BASKET|wynos-food-guest-basket/);
  }
  // The restore path is the existing one, after login, inside LINE only.
  assert.match(read("components/food/wynos-food-developer-app.tsx"), /isLineInAppBrowser\(navigator\.userAgent\)\) return;\s*const destination = takeLineAutoLink\(\)/);
});

// ---------- callback page: no open redirect, no token leakage ----------

test("callback ignores to/next/redirect and only navigates to the fixed ZOKY home", () => {
  assert.deepEqual([...callback.matchAll(/params\.(get|has|getAll)\("([^"]+)"\)/g)].map((m) => `${m[1]}:${m[2]}`).sort(), ["get:code", "has:error"]);
  assert.doesNotMatch(callback, /["'`](to|next|redirect|returnTo|redirect_to)["'`]/);
  const targets = callback.split("\n").filter((line) => /location\.(replace|assign)\(/.test(line)).map((line) => line.trim());
  assert.ok(targets.length > 0);
  for (const target of targets) assert.match(target, /^(if \(!window\.closed\) )?window\.location\.replace\(foodHomeUrl\(\)\);$/);
  assert.doesNotMatch(callback, /location\.href\s*=|window\.open\(|router\.(push|replace)/);
});

test("T-A12 callback clears ?code on every exit and never logs or stores tokens", () => {
  const cleans = callback.match(/history\.replaceState\(null, "", "\/food\/auth\/callback"\)/g) ?? [];
  assert.ok(cleans.length >= 3, "success, popup hand-off and error paths all clear the URL");
  assert.match(callback, /catch \{\s*window\.history\.replaceState\(null, "", "\/food\/auth\/callback"\);\s*setError\(/);
  for (const file of ["app/food/auth/callback/page.tsx", "components/food/line-login-button.tsx", "components/food/food-auth.tsx", "lib/google-pwa-oauth.ts", "lib/line-liff.ts"]) {
    const source = read(file);
    assert.doesNotMatch(source, /console\.(log|info|debug|warn|error)/, file);
    assert.doesNotMatch(source, /access_token|refresh_token|id_token|getIDToken|getAccessToken|getProfile|getDecodedIDToken/, file);
  }
  assert.doesNotMatch(lineHandlerSource(), /\.(session|user|identities)\b|user_metadata/);
});

test("callback copy is provider-neutral and Thai/English keys exist for all new LINE copy", () => {
  assert.doesNotMatch(callback, /"[^"\n]*Google[^"\n]*"/); // identifiers may say Google; user-facing strings may not
  const en = read("lib/i18n/en.ts");
  for (const thai of [
    "เข้าสู่ระบบด้วย LINE", "กำลังเชื่อมต่อ LINE…", "เข้าสู่ระบบด้วย LINE ไม่สำเร็จ กรุณาลองใหม่",
    "ZOKY ไม่ขออีเมลของคุณจาก LINE", "เข้าสู่ระบบไม่สำเร็จ กรุณากลับไปหน้า ZOKY แล้วลองใหม่",
    "LINE จะสร้างบัญชี ZOKY ใหม่ ถ้าเคยใช้ Google หรืออีเมลมาก่อน ให้เข้าด้วยวิธีเดิมเพื่อใช้บัญชีเดิมและประวัติออเดอร์",
    ...Object.values(LINE_OAUTH.messages),
  ]) assert.ok(en.includes(`"${thai}":`), thai);
});

// ---------- UI: gating, a11y, layout ----------

test("button shows only inside the LINE client, with a stable reserved slot and accessible states", () => {
  assert.match(button, /useSyncExternalStore\(noopSubscribe, readInLine, \(\) => false\)/);
  assert.match(button, /liff\.isInClient\(\) \? "ready" : "unavailable"/);
  assert.match(button, /isInstalledIosWebApp\(\)/);
  assert.match(button, /if \(!inLine && !testMode\) return null/);
  assert.match(button, /aria-busy=\{loading\}/);
  assert.match(button, /disabled=\{busy\}/);
  assert.match(button, /role="alert"/);
  assert.match(button, /aria-describedby="wf-auth-line-login-note"/);
  const css = read("app/food/food.css");
  assert.match(css, /\.wf-auth-line-login \{[^}]*min-height: 132px/);
  assert.match(css, /\.wf-auth-line-signin \{[^}]*min-height: 48px/);
  assert.match(css, /\.wf-auth-line-signin:focus-visible/);
  // Does not collide with the existing guidance box classes.
  assert.doesNotMatch(css.match(/\.wf-auth-line-login \{[^}]*\}/)[0], /wf-auth-note|wf-auth-line-slot/);
});

test("LINE Login adds no dependency, migration or design-B artefact", () => {
  const pkg = JSON.parse(read("package.json"));
  assert.equal(Object.keys({ ...pkg.dependencies, ...pkg.devDependencies }).some((n) => /line|liff-login/i.test(n) && n !== "@line/liff"), false);
  for (const file of [...walk("components"), ...walk("app"), ...walk("lib")]) {
    assert.doesNotMatch(read(file), /food_cart_handoffs|food-cart-handoff|\/food\/resume/, file);
  }
});

// ---------- T-A2 / T-A15: users without email ----------

test("T-A15 account registry tolerates users with no email", () => {
  const registry = read("lib/account-registry.ts");
  assert.match(registry, /session\.user\.email\?\.split\("@"\)\[0\]/);
  assert.match(registry, /email: session\.user\.email \?\? null/);
});
