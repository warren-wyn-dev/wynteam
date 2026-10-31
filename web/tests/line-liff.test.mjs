import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import {
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
