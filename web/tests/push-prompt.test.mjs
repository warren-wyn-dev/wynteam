// Founder decision (2026-09-27): people who have not answered the
// notification question are asked once in the app; the OS popup opens only
// from the card's Allow tap, and a dismissal waits a week.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const compiled = ts.transpileModule(readFileSync(new URL("../lib/push-notifications.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const exports = {};
runInNewContext(compiled, { exports, require: () => ({}) });
const { pushPromptKind, PUSH_PROMPT_COOLDOWN_MS } = exports;

const now = 1_800_000_000_000;
const base = { path: "/home", permission: "default", availability: { available: true }, dismissedAt: null, now };

test("asks on main screens when the question has not been answered", () => {
  assert.equal(pushPromptKind(base), "ask");
  for (const path of ["/chat", "/chat/abc", "/notifications", "/clubs", "/club/x", "/profile", "/search", "/food"]) {
    assert.equal(pushPromptKind({ ...base, path }), "ask", path);
  }
});

test("never over sign-in, sign-up, onboarding, Settings or the landing page", () => {
  for (const path of ["/", "/login", "/signup", "/onboarding", "/welcome", "/settings", "/auth/callback", "/homepage"]) {
    assert.equal(pushPromptKind({ ...base, path }), null, path);
  }
});

test("granted is never asked again; denied gets recovery only where Push matters most", () => {
  assert.equal(pushPromptKind({ ...base, permission: "granted" }), null);
  assert.equal(pushPromptKind({
    ...base,
    permission: "denied",
    availability: { available: false, reason: "denied" },
  }), null);
  for (const path of ["/chat", "/chat/abc", "/notifications"]) {
    assert.equal(pushPromptKind({
      ...base,
      path,
      permission: "denied",
      availability: { available: false, reason: "denied" },
    }), "settings", path);
  }
});

test("unsupported or unconfigured devices are not asked", () => {
  assert.equal(pushPromptKind({ ...base, availability: { available: false, reason: "unsupported" } }), null);
  assert.equal(pushPromptKind({ ...base, availability: { available: false, reason: "not-configured" } }), null);
  assert.equal(pushPromptKind({ ...base, permission: "unsupported", availability: { available: false, reason: "unsupported" } }), null);
});

test("iPhone in a Safari tab is told to add WYNOS to the Home Screen first", () => {
  assert.equal(pushPromptKind({ ...base, permission: "unsupported", availability: { available: false, reason: "install-required" } }), "install");
});

test("Not now waits seven days", () => {
  assert.equal(pushPromptKind({ ...base, dismissedAt: now - 1000 }), null);
  assert.equal(pushPromptKind({ ...base, dismissedAt: now - PUSH_PROMPT_COOLDOWN_MS + 1 }), null);
  assert.equal(pushPromptKind({ ...base, dismissedAt: now - PUSH_PROMPT_COOLDOWN_MS }), "ask");
});

test("Food subdomain root maps to the Food push prompt path", () => {
  const source = readFileSync(new URL("../components/push-prompt.tsx", import.meta.url), "utf8");
  assert.match(source, /window\.location\.hostname\.toLowerCase\(\) === "food\.wynos\.online"/);
  assert.match(source, /\? "\/food"/);
});

test("the OS permission popup is only requested from the Allow tap", () => {
  const source = readFileSync(new URL("../components/push-prompt.tsx", import.meta.url), "utf8");
  assert.doesNotMatch(source, /requestPermission/);
  const effects = source.slice(0, source.indexOf("const allow = async"));
  assert.doesNotMatch(effects, /subscribeToPushNotifications\(/);
  assert.match(source, /onClick=\{\(\) => void allow\(\)\}/);
});


test("iOS install handoff does not accidentally snooze the Push question for seven days", () => {
  const source = readFileSync(new URL("../components/push-prompt.tsx", import.meta.url), "utf8");
  const start = source.indexOf("const showInstall =");
  const end = source.indexOf("const showPermissionHelp =", start);
  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  const handoff = source.slice(start, end);
  assert.doesNotMatch(handoff, /dismiss\(\)/);
  assert.match(handoff, /setPrompt\(null\)/);
  assert.match(handoff, /OPEN_INSTALL_EVENT/);
});

test("Chat and Notifications use the faster high-intent prompt delay", () => {
  const source = readFileSync(new URL("../components/push-prompt.tsx", import.meta.url), "utf8");
  assert.match(source, /HIGH_INTENT_SHOW_DELAY_MS\s*=\s*1200/);
  assert.match(source, /\^\\\/\(chat\|notifications\)/);
});
