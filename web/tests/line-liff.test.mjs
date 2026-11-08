import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import {
  CUSTOMER_LINE_ADD_FRIEND_URL,
  foodLoginExternalUrl,
  lineAudienceFor,
  lineLinkPath,
  lineLinkStatusFrom,
  lineStatusText,
  isLineInAppBrowser,
  isLineLoginEnabled,
  LINE_LOGIN_PROVIDER,
  LINE_OAUTH,
  liffIdFor,
  rememberLineAutoLink,
  requestStoreLineFriendship,
  safeLineDestination,
  takeLineAutoLink,
} from "../lib/line-liff.ts";

test("store scanners see the native friend prompt before continuing, including guests", async () => {
  const calls = [];
  let dismiss;
  const liff = {
    isApiAvailable: (api) => { calls.push(api); return true; },
    getFriendship: async () => { calls.push("friendship"); return { friendFlag: false }; },
    requestFriendship: () => { calls.push("prompt"); return new Promise((resolve) => { dismiss = resolve; }); },
  };
  let continued = false;
  const pending = requestStoreLineFriendship("/s/kbs7xa", liff).then((outcome) => { continued = true; return outcome; });
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(calls, ["friendship", "requestFriendship", "prompt"]);
  assert.equal(continued, false);
  dismiss();
  assert.equal(await pending, "prompted");
  assert.equal(continued, true);

  const entry = readFileSync(new URL("../components/line/line-entry.tsx", import.meta.url), "utf8");
  const prompt = entry.indexOf("await friendshipPrompt.current");
  assert.ok(prompt > 0 && prompt < entry.indexOf("if (!data.session) rememberLineAutoLink"));
});

test("existing friends and unrelated destinations do not get prompted", async () => {
  const calls = [];
  const liff = {
    isApiAvailable: () => { calls.push("unexpected"); return false; },
    getFriendship: async () => ({ friendFlag: true }),
    requestFriendship: async () => { calls.push("prompt"); },
  };
  assert.equal(await requestStoreLineFriendship("/s/kbs7xa", liff), "friend");
  assert.equal(await requestStoreLineFriendship("/food?store=1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed", liff), "friend");
  liff.getFriendship = async () => { throw new Error("unrelated destination queried"); };
  for (const destination of ["/food", "/food?order=ZF-0036", "/merchant", "/s/kbs7xa?next=https://evil.test"]) {
    assert.equal(await requestStoreLineFriendship(destination, liff), "not_store");
  }
  assert.deepEqual(calls, []);
});

test("unsupported clients, unlinked OA, and failed native prompts request the public-link fallback", async () => {
  for (const failure of ["unsupported", "friendship", "prompt"]) {
    const calls = [];
    const outcome = await requestStoreLineFriendship("/s/kbs7xa", {
      isApiAvailable: () => failure !== "unsupported",
      getFriendship: async () => {
        calls.push("friendship");
        if (failure === "friendship") throw new Error("OA not linked");
        return { friendFlag: false };
      },
      requestFriendship: async () => { calls.push("prompt"); throw new Error("prompt unavailable"); },
    });
    assert.equal(outcome, "unavailable");
    assert.deepEqual(calls, failure === "prompt" ? ["friendship", "prompt"] : ["friendship"]);
  }
});

test("native cancellation is respected without opening a second add-friend flow", async () => {
  assert.equal(await requestStoreLineFriendship("/s/kbs7xa", {
    isApiAvailable: () => true,
    getFriendship: async () => ({ friendFlag: false }),
    requestFriendship: async () => {
      throw Object.assign(new Error("user didn't complete the friend request"), { code: "UNAUTHORIZED" });
    },
  }), "cancelled");
});

test("a stalled friendship lookup times out without showing a late prompt", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  let finishLookup;
  let prompted = false;
  const pending = requestStoreLineFriendship("/s/kbs7xa", {
    isApiAvailable: () => true,
    getFriendship: () => new Promise((resolve) => { finishLookup = resolve; }),
    requestFriendship: async () => { prompted = true; },
  });
  t.mock.timers.tick(4000);
  assert.equal(await pending, "unavailable");
  finishLookup({ friendFlag: false });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(prompted, false);
});

test("store fallback keeps the approved customer OA and the exact safe store destination", () => {
  assert.equal(CUSTOMER_LINE_ADD_FRIEND_URL, "https://line.me/R/ti/p/%40732igmun");
  const entry = readFileSync(new URL("../components/line/line-entry.tsx", import.meta.url), "utf8");
  assert.match(entry, /if \(friendship === "unavailable"\) \{\s*setView\(\{ kind: "store_friendship", destination \}\)/);
  assert.match(entry, /href=\{CUSTOMER_LINE_ADD_FRIEND_URL\} target="_blank" rel="noreferrer">เพิ่มเพื่อน LINE OA/);
  assert.match(entry, /href=\{view\.destination\}>ไปหน้าร้าน/);
  assert.match(entry, /friendshipPrompt\.current \?\?= requestStoreLineFriendship\(destination, liff\)/);
  assert.match(entry, /friendshipFallback\.current \?\?= Promise\.resolve\(\)[\s\S]*?\.openWindow\(\{ url: CUSTOMER_LINE_ADD_FRIEND_URL, external: false \}\)/);
  const fallback = entry.indexOf('if (friendship === "unavailable")');
  const navigation = entry.indexOf("window.location.replace(destination)");
  assert.ok(entry.indexOf("if (!data.session) rememberLineAutoLink") < fallback);
  assert.ok(entry.indexOf("return;", fallback) < navigation, "the fallback screen must remain until the user continues");
});

test("audience follows the Merchant origin unless a known OA is requested", () => {
  assert.equal(lineAudienceFor("merchant.wynos.online", null), "merchant");
  assert.equal(lineAudienceFor("MERCHANT.wynos.online", null), "merchant");
  assert.equal(lineAudienceFor("food.wynos.online", null), "food");
  assert.equal(lineAudienceFor("merchant.wynos.online.attacker.test", null), "food");
  assert.equal(lineAudienceFor("web-abc.vercel.app", "merchant"), "merchant");
  assert.equal(lineAudienceFor("food.wynos.online", "social"), "food");
});

test("only well-formed LIFF IDs are used", () => {
  assert.equal(liffIdFor("food", { food: "1234567890-AbCdEfGh" }), "1234567890-AbCdEfGh");
  assert.equal(liffIdFor("merchant", { food: "1234567890-AbCdEfGh" }), null);
  assert.equal(liffIdFor("food", { food: "javascript:alert(1)" }), null);
  assert.equal(liffIdFor("food", {}), null);
});

test("LINE buttons open only that app's home or one of its orders", () => {
  assert.equal(safeLineDestination("food", "/food?order=WF0015"), "/food?order=WF0015");
  assert.equal(safeLineDestination("merchant", "/merchant?order=WF123456"), "/merchant?order=WF123456");
  assert.equal(safeLineDestination("food", "/food?order=ZF-0036"), "/food?order=ZF-0036");
  // Founder 2026-11-04: a store QR opens the store in LINE.
  assert.equal(safeLineDestination("food", "/s/kbs7xa"), "/s/kbs7xa");
  assert.equal(safeLineDestination("food", "/food?store=1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed"), "/food?store=1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed");
  for (const bad of ["/s/kbs7xa?next=https://evil.test", "/s/KBS7XA", "/s/kbs7x", "//evil.test/s/kbs7xa", "/food?store=x"]) assert.equal(safeLineDestination("food", bad), "/food", bad);
  assert.equal(safeLineDestination("merchant", "/s/kbs7xa"), "/merchant");
  assert.equal(safeLineDestination("merchant", "/merchant"), "/merchant");
  assert.equal(safeLineDestination("food", null), "/food");
});

test("LINE buttons can never become an open redirect or cross apps", () => {
  for (const to of [
    "https://evil.test",
    "//evil.test",
    "/\\evil.test",
    "javascript:alert(1)",
    "/food?order=WF0015&next=https://evil.test",
    "/food@evil.test",
    "/foodevil",
    "/merchant?order=WF0015",
    "/account/delete",
    `/food?order=WF${"1".repeat(80)}`,
  ]) {
    assert.equal(safeLineDestination("food", to), "/food", to);
  }
  assert.equal(safeLineDestination("merchant", "/food?order=WF0015"), "/merchant");
});

test("the settings cards open the same-browser link flow", () => {
  assert.equal(lineLinkPath("food"), "/line?mode=link&oa=food");
  assert.equal(lineLinkPath("merchant"), "/line?mode=link&oa=merchant");
});

test("server status is parsed defensively", () => {
  assert.deepEqual(lineLinkStatusFrom({ linked: true, friendStatus: "friend", addFriendUrl: "https://line.me/R/ti/p/%40abc" }), {
    linked: true, friendStatus: "friend", addFriendUrl: "https://line.me/R/ti/p/%40abc",
  });
  assert.deepEqual(lineLinkStatusFrom({ linked: false, friendStatus: "friend", addFriendUrl: "javascript:x" }), {
    linked: false, friendStatus: null, addFriendUrl: null,
  });
  assert.equal(lineLinkStatusFrom({ friendStatus: "friend" }), null);
  assert.equal(lineLinkStatusFrom(null), null);
});

test("status copy tells a linked user to add the OA when it cannot deliver", () => {
  assert.match(lineStatusText({ linked: true, friendStatus: "not_friend", addFriendUrl: null }), /ยังไม่ได้เพิ่มเพื่อน/);
  assert.match(lineStatusText({ linked: true, friendStatus: "friend", addFriendUrl: null }), /เชื่อม LINE แล้ว/);
  assert.match(lineStatusText({ linked: false, friendStatus: null, addFriendUrl: null }), /ยังไม่ได้เชื่อม/);
});

test("the LIFF page never sends a client-chosen LINE userId", () => {
  const source = readFileSync(new URL("../components/line/line-entry.tsx", import.meta.url), "utf8");
  assert.match(source, /getIDToken\(\)/);
  assert.doesNotMatch(source, /getProfile\(|lineUserId|userId:/);
});

// Founder 2026-11-04 ("ทำแจ้งเตือนอัตโนมัติ").
test("automatic LINE link: LINE browser detection and a one-shot, safe pending destination", () => {
  assert.equal(isLineInAppBrowser("Mozilla/5.0 (iPhone) AppleWebKit Line/14.19.0"), true);
  assert.equal(isLineInAppBrowser("Mozilla/5.0 (iPhone) Safari/604.1"), false);
  const store = new Map();
  globalThis.window = { localStorage: { getItem: (k) => store.get(k) ?? null, setItem: (k, v) => store.set(k, v), removeItem: (k) => store.delete(k) } };
  try {
    rememberLineAutoLink("/s/kbs7xa");
    assert.equal(takeLineAutoLink(), "/s/kbs7xa");
    assert.equal(takeLineAutoLink(), null);
    rememberLineAutoLink("https://evil.test/x");
    assert.equal(takeLineAutoLink(), "/food");
    rememberLineAutoLink("/s/kbs7xa");
    assert.equal(takeLineAutoLink(Date.now() + 31 * 60 * 1000), null);
  } finally {
    delete globalThis.window;
  }
  const entry = readFileSync(new URL("../components/line/line-entry.tsx", import.meta.url), "utf8");
  assert.match(entry, /audience === "food" && liff\?\.isInClient\(\) && liff\.isLoggedIn\(\)/);
  assert.match(entry, /action: "status", audience/);
  assert.match(entry, /if \(!status\.linked && idToken\) await callLineLink\(\{ action: "link", audience, idToken \}\)/);
});

test("LINE UA check for login guidance matches only the Line/<version> token", () => {
  assert.equal(isLineInAppBrowser("Mozilla/5.0 (Linux; Android 14) Chrome/120 Mobile Safari/537.36 Line/14.0.0"), true);
  assert.equal(isLineInAppBrowser("Mozilla/5.0 Baseline/1.0"), false);
  assert.equal(isLineInAppBrowser(""), false);
});

test("the external login URL carries no query, hash, token or basket", () => {
  assert.equal(foodLoginExternalUrl("https://zoky.wynos.online"), "https://zoky.wynos.online/food/login");
});

test("LINE login guidance never redirects, hides Google or touches the guest basket", () => {
  const guidance = readFileSync(new URL("../components/food/line-login-guidance.tsx", import.meta.url), "utf8");
  assert.match(guidance, /external: true/);
  assert.match(guidance, /foodLoginExternalUrl\(window\.location\.origin\)/);
  assert.doesNotMatch(guidance, /location\.(replace|assign|href\s*=)|sessionStorage|localStorage|GUEST_BASKET|removeItem|\.clear\(/);
  assert.match(guidance, /ตะกร้าจะไม่ถูกย้ายไปด้วย/);
  const auth = readFileSync(new URL("../components/food/food-auth.tsx", import.meta.url), "utf8");
  // The Google button still follows the guidance (the LINE button is an optional, flag-gated slot between them).
  assert.match(auth, /<LineLoginGuidance \/>\s*\{isLineLoginEnabled\(\) \? \([\s\S]*?\) : null\}\s*<button className="wf-auth-google"/);
  assert.match(auth, /disabled=\{loading \|\| googleLoading \|\| lineLoading\} onClick=\{\(\) => void google\(\)\}/);
});

test("LINE guidance is detected synchronously and keeps readable, stable layout", () => {
  const guidance = readFileSync(new URL("../components/food/line-login-guidance.tsx", import.meta.url), "utf8");
  assert.match(guidance, /useSyncExternalStore\(noopSubscribe, readInLine, \(\) => false\)/);
  assert.doesNotMatch(guidance, /setInLine/);
  assert.doesNotMatch(guidance, /<p className="wf-auth-line-slot"/);
  const css = readFileSync(new URL("../app/food/food.css", import.meta.url), "utf8");
  assert.match(css, /\.wf-auth-note\.wf-auth-note--line span \{ font-size: 14px;/);
  assert.match(css, /\.wf-auth-line-slot \{[^}]*min-height: 124px/);
  const en = readFileSync(new URL("../lib/i18n/en.ts", import.meta.url), "utf8");
  for (const thai of ["เปิดใน LINE อยู่", "ถ้าเห็นหน้าปฏิเสธจาก Google ให้ใช้อีเมลและรหัสผ่าน หรือเปิดในเบราว์เซอร์"]) {
    assert.ok(en.includes(`"${thai}":`), thai);
  }
});

test("LINE Login flag is off unless it is exactly \"1\"", () => {
  assert.equal(isLineLoginEnabled(undefined), false);
  for (const value of ["", "0", "true", "TRUE", "yes", "on", " 1", "1 ", "01", "1.0", "11"]) {
    assert.equal(isLineLoginEnabled(value), false, JSON.stringify(value));
  }
  assert.equal(isLineLoginEnabled("1"), true);
  const source = readFileSync(new URL("../lib/line-liff.ts", import.meta.url), "utf8");
  assert.match(source, /process\.env\.NEXT_PUBLIC_ZOKY_LINE_LOGIN_ENABLED/);
});

test("LINE OAuth config uses custom:line with no Google prompt and no client-chosen scopes", () => {
  assert.equal(LINE_LOGIN_PROVIDER, "custom:line");
  assert.equal(LINE_OAUTH.provider, "custom:line");
  assert.equal(LINE_OAUTH.queryParams, undefined);
  assert.equal("scopes" in LINE_OAUTH, false);
  assert.match(LINE_OAUTH.messages.failed, /LINE/);
});
