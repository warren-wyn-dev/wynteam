import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import {
  foodLoginExternalUrl,
  isLineInAppBrowser,
  liffIdFor,
} from "../lib/line-liff.ts";

test("only well-formed LIFF IDs are used", () => {
  assert.equal(liffIdFor("food", { food: "1234567890-AbCdEfGh" }), "1234567890-AbCdEfGh");
  assert.equal(liffIdFor("merchant", { food: "1234567890-AbCdEfGh" }), null);
  assert.equal(liffIdFor("food", { food: "javascript:alert(1)" }), null);
  assert.equal(liffIdFor("food", {}), null);
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
  assert.match(auth, /<LineLoginGuidance \/>\s*<button className="wf-auth-google"/);
  assert.match(auth, /disabled=\{loading \|\| googleLoading\} onClick=\{\(\) => void google\(\)\}/);
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

test("LINE notification, /line entry and store friend prompts are gone", () => {
  const page = readFileSync(new URL("../app/line/page.tsx", import.meta.url), "utf8");
  assert.match(page, /redirect\("\/food"\)/);
  const food = readFileSync(new URL("../components/food/wynos-food-developer-app.tsx", import.meta.url), "utf8");
  assert.doesNotMatch(food, /lineLinkPath|takeLineAutoLink|lin\.ee|352lvyoi|รับแจ้งเตือนทาง LINE/);
  const merchant = readFileSync(new URL("../components/merchant/merchant-notification-settings.tsx", import.meta.url), "utf8");
  assert.doesNotMatch(merchant, /lineLinkPath|รับแจ้งเตือนทาง LINE/);
  const qr = readFileSync(new URL("../lib/zoky-store-qr.ts", import.meta.url), "utf8");
  assert.doesNotMatch(qr, /liff\.line\.me/);
});
