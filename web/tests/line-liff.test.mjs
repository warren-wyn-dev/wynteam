import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import {
  foodLoginExternalUrl,
  isLineUserAgent,
  lineAudienceFor,
  lineLinkPath,
  lineLinkStatusFrom,
  lineStatusText,
  liffIdFor,
  safeLineDestination,
} from "../lib/line-liff.ts";

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

test("LINE in-app browser is recognised by user agent only", () => {
  assert.equal(isLineUserAgent("Mozilla/5.0 (iPhone) AppleWebKit Mobile Safari Line/13.1.0"), true);
  assert.equal(isLineUserAgent("Mozilla/5.0 (Linux; Android 14) Chrome/120 Mobile Safari/537.36 Line/14.0.0"), true);
  assert.equal(isLineUserAgent("Mozilla/5.0 (iPhone) Safari/604.1"), false);
  assert.equal(isLineUserAgent("Mozilla/5.0 Baseline/1.0"), false);
  assert.equal(isLineUserAgent(""), false);
  assert.equal(isLineUserAgent(null), false);
});

test("the external login URL carries no query, hash, token or basket", () => {
  assert.equal(foodLoginExternalUrl("https://food.wynos.online"), "https://food.wynos.online/food/login");
});

test("LINE login guidance never redirects, hides Google or touches the guest basket", () => {
  const guidance = readFileSync(new URL("../components/food/line-login-guidance.tsx", import.meta.url), "utf8");
  assert.match(guidance, /external: true/);
  assert.match(guidance, /foodLoginExternalUrl\(window\.location\.origin\)/);
  assert.doesNotMatch(guidance, /location\.(replace|assign|href\s*=)|sessionStorage|localStorage|GUEST_BASKET|removeItem|\.clear\(/);
  assert.match(guidance, /ตะกร้าจะไม่ถูกย้ายไปด้วย/);
  const auth = readFileSync(new URL("../components/food/food-auth.tsx", import.meta.url), "utf8");
  assert.match(auth, /<LineLoginGuidance \/>\s*<button className="wf-auth-google"/);
  assert.match(auth, /disabled=\{loading \|\| googleLoading\} onClick=\{\(\) => void google\(\)\}/);
});

test("LINE guidance is detected synchronously and keeps readable, stable layout", () => {
  const guidance = readFileSync(new URL("../components/food/line-login-guidance.tsx", import.meta.url), "utf8");
  // UA is read in the first client render (no post-mount setState that shifts the Google button).
  assert.match(guidance, /useSyncExternalStore\(noopSubscribe, readInLine, \(\) => false\)/);
  assert.doesNotMatch(guidance, /setInLine/);
  const css = readFileSync(new URL("../app/food/food.css", import.meta.url), "utf8");
  // Beats the late ".wf-auth-note span" polish rule so body text stays 14px.
  assert.match(css, /\.wf-auth-note\.wf-auth-note--line span \{ font-size: 14px;/);
  // The fallback slot is a div: ".wf-auth-note--line p { flex: 1 1 0 }" must not squeeze it into a column.
  assert.doesNotMatch(guidance, /<p className="wf-auth-line-slot"/);
  assert.match(css, /\.wf-auth-line-slot \{[^}]*min-height: 124px/);
  const en = readFileSync(new URL("../lib/i18n/en.ts", import.meta.url), "utf8");
  for (const thai of ["เปิดใน LINE อยู่", "ถ้าเห็นหน้าปฏิเสธจาก Google ให้ใช้อีเมลและรหัสผ่าน หรือเปิดในเบราว์เซอร์"]) {
    assert.ok(en.includes(`"${thai}":`), thai);
  }
});
