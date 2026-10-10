import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const text = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const sql = text("../../supabase/migrations/20261010120000_food_public_guest_catalog.sql");
const guest = text("../components/food/food-guest-browse.tsx");
const app = text("../components/food/wynos-food-developer-app.tsx");
const area = text("../lib/food-customer.ts");

test("anonymous catalog exposes only published, unsuspended stores and available menu entries", () => {
  assert.match(sql, /security definer/i);
  assert.match(sql, /set search_path = ''/);
  assert.match(sql, /r\.public_enabled = true/);
  assert.match(sql, /fs\.is_published = true and fs\.admin_suspended_at is null/);
  assert.match(sql, /mi\.is_available = true/);
  assert.match(sql, /revoke all on function public\.food_public_catalog\(\) from public/);
  assert.match(sql, /grant execute on function public\.food_public_catalog\(\) to anon, authenticated/);
  assert.doesNotMatch(sql, /grant\s+select\s+on\s+public\.food_(?:stores|orders|menu_items)/i);
  assert.doesNotMatch(sql, /grant\s+execute\s+on\s+function\s+public\.food_(?:quote|create|submit)/i);
  for (const sensitive of ["buyer_id", "recipient_phone", "promptpay_id", "bank_account_number", "stripe_account_id"]) {
    assert.doesNotMatch(sql, new RegExp("'"+sensitive+"'"));
  }
});

test("guest sees stores and menus without requesting location or placing an anonymous order", () => {
  assert.match(guest, /client\.rpc\("food_public_catalog"\)/);
  assert.doesNotMatch(guest, /navigator\.geolocation|currentFoodLocation|food_service_area_check/);
  assert.doesNotMatch(guest, /client\.rpc\("food_(?:create|quote|submit)/);
  assert.match(guest, /foodCartLineOptionsValid/);
  assert.match(guest, /saveGuestFoodBasket\(basket\)/);
  assert.match(guest, /rememberSharedFoodStore\(basket\.storeId\)/);
  assert.match(guest, /router\.push\("\/food\/login"\)/);
});

test("authenticated Food no longer blocks catalog behind GPS; checkout still checks address and delivery", () => {
  assert.match(app, /if \(!signedIn\) return <FoodGuestBrowse client=\{client\}/);
  assert.doesNotMatch(app, /FoodServiceAreaIntro|area !== "inside"|currentFoodLocation\(\)/);
  assert.match(app, /readGuestFoodBasket\(\)/);
  assert.match(app, /clearGuestFoodBasket\(\)/);
  assert.match(app, /checkFoodDeliveryAvailability\(client, storeId, point\)/);
  assert.match(app, /location: storeHasDeliveryZone\(store\) \? addressLocation\(address\) : null/);
  assert.match(area, /client\.rpc\("food_create_order/);
  assert.match(app, /DeveloperRouteGate signedOutPath="\/food\/login"/);
});
