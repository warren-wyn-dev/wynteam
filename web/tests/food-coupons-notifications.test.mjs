import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const source = (relative) => readFileSync(new URL(relative, import.meta.url), "utf8");
const sql = source("../../supabase/migrations/20261008161000_food_admin_coupons.sql");
const campaign = source("../../supabase/migrations/20261008161100_food_promo_notifications.sql");
const sender = source("../../supabase/functions/send-food-promotion/index.ts");
const senderLib = source("../../supabase/functions/send-food-promotion/_lib.ts");
const food = source("../lib/food-customer.ts");
const checkout = source("../components/food/wynos-food-developer-app.tsx");
const inbox = source("../components/food/food-promotion-center.tsx");
const worker = source("../public/sw.js");
const admin = source("../../admin/components/admin/food-promotion-broadcast-manager.tsx");
const stripe = source("../../supabase/functions/food-stripe-checkout/index.ts");

test("Food coupon is opt-in, server-priced and atomic; old orders unchanged", () => {
  assert.match(sql, /coupon_required boolean not null default false/);
  assert.match(sql, /create or replace function public.food_quote_order_v2/);
  assert.match(sql, /create or replace function public.food_create_order_v2/);
  assert.match(sql, /create or replace function public.food_create_scheduled_order_v2/);
  assert.match(sql, /for update;/i);
  assert.match(sql, /food_coupon_redemptions/);
  assert.match(sql, /coupon_not_applicable_or_better_automatic_discount/);
  assert.match(food, /client\.rpc\("food_create_order_v2"/);
  assert.match(food, /client\.rpc\("food_create_order", params\)/);
  assert.match(food, /client\.rpc\("food_create_scheduled_order_v2"/);
  assert.match(food, /client\.rpc\("food_create_scheduled_order"/);
  assert.match(checkout, /โค้ดส่วนลด WYNOS Food/);
  assert.match(stripe, /Number\(order\.total\)/);
});
test("Food marketing does not share Social or Merchant tokens", () => {
  assert.match(senderLib, /platform=eq\.web&app=eq\.food&select=token/);
  assert.doesNotMatch(senderLib, /app\.is\.null/);
  assert.match(sender, /foodPromoTokenQuery\(recipientId\)/);
  assert.match(sender, /verify_food_promo_cron_key/);
  assert.match(campaign, /pt\.app='food'/);
  assert.match(campaign, /pref\.push_marketing=true/);
  assert.match(inbox, /push_marketing/);
  assert.match(inbox, /in_app_marketing/);
  assert.match(worker, /data\?\.type === "food_promotion"/);
  assert.match(worker, /icons\/food\/icon-192-v10\.png/);
});
test("Admin can schedule or cancel a Food promo; server rechecks role", () => {
  assert.match(campaign, /Only admins can send Food promotions/);
  assert.match(campaign, /Only admins can cancel Food promotions/);
  assert.match(admin, /admin_food_promo_schedule/);
  assert.match(admin, /admin_food_promo_cancel/);
  assert.match(campaign, /food_promo_claim_batch/);
  assert.match(campaign, /grant execute on function public\.food_promo_claim_batch\(integer\) to service_role/);
});
