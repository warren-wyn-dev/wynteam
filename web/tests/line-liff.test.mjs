import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import {
  lineAudienceFor,
  lineLinkPath,
  lineLinkStatusFrom,
  lineStatusText,
  isLineInAppBrowser,
  liffIdFor,
  rememberLineAutoLink,
  safeLineDestination,
  takeLineAutoLink,
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
