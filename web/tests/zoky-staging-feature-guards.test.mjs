import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");

test("Merchant Zoky chat requires an isolated, explicitly selected staging Supabase project", () => {
  const source = read("../components/merchant/zoky-merchant-order-chat.tsx");
  assert.match(source, /NEXT_PUBLIC_ZOKY_CHAT_STAGING\s*!==\s*"true"/);
  assert.match(source, /NEXT_PUBLIC_ZOKY_CHAT_STAGING_PROJECT_REF/);
  assert.match(source, /\^\[a-z0-9\]\{20\}\$/);
  assert.match(source, /kqokpocajhfbidcxpvhh/);
  assert.match(source, /pcatuxtenluqzjzzwsvl/);
  assert.match(source, /NEXT_PUBLIC_SUPABASE_URL/);
  assert.match(source, /\`https:\/\/\$\{stagingRef\}\.supabase\.co\`/);
  assert.match(source, /merchant\.wynos\.online/);
  assert.match(source, /if \(!enabled\) return null/);
});

test("Android disables Zoky chat, live payments and account mutations in release", () => {
  const gradle = read("../../food-android/app/build.gradle.kts");
  for (const feature of [
    "CHAT_STAGING_ALLOWED",
    "STAGING_ORDER_CREATION_ALLOWED",
    "STAGING_MOBILE_PAYMENT_ALLOWED",
    "ACCOUNT_SIGNUP_ALLOWED",
    "ADDRESS_WRITES_ALLOWED",
  ]) {
    assert.ok(gradle.includes(`buildConfigField("boolean", "${feature}", "false")`),
      `release must fail closed for ${feature}`);
  }
  assert.match(gradle, /verifiedStaging\s*&&\s*foodConfig\("WYNOS_FOOD_CHAT_STAGING"\)\s*==\s*"true"/);
  assert.match(gradle, /projectRef\s*!=\s*"kqokpocajhfbidcxpvhh"/);
});

test("Proposed order chat enforces buyer and merchant participation and denies anonymous access", () => {
  const sql = read("../../supabase/qa/zoky_food_order_chat_staging_v1.sql");
  assert.match(sql, /alter table public\.food_order_chat_messages enable row level security/i);
  assert.match(sql, /revoke all on public\.food_order_chat_messages from public, anon, authenticated/i);
  assert.match(sql, /sender_id\s*=\s*\(select auth\.uid\(\)\)/);
  assert.match(sql, /o\.buyer_id\s*=\s*\(select auth\.uid\(\)\)/);
  assert.match(sql, /public\.merchant_has_store_role/);
  assert.doesNotMatch(sql, /grant\s+(?:delete|update|all)\s+on\s+public\.food_order_chat_messages/i);
  assert.match(sql, /chat_rate_limited/);
  assert.match(sql, /STAGING PROPOSAL ONLY/);
});

test("Native chat is never represented as live when chat staging flag is off", () => {
  const ui = read("../../food-android/app/src/main/java/online/wynos/food/ui/ZokyMessageCenter.kt");
  assert.match(ui, /if \(!state\.chatEnabled\)/);
  assert.match(ui, /ระบบแชตยังไม่เปิดใช้งานใน APK นี้/);
});
