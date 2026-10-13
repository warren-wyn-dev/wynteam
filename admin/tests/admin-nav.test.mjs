import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { test } from "node:test";
import ts from "typescript";

const require = createRequire(import.meta.url);

// Run the actual navigation functions without importing server auth or a DB.
function loadTypeScript(path) {
  const source = readFileSync(new URL(path, import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  });
  const loadedModule = { exports: {} };
  const localRequire = (name) => name === "@/lib/admin-systems"
    ? loadTypeScript("../lib/admin-systems.ts")
    : require(name);
  new Function("require", "module", "exports", outputText)(localRequire, loadedModule, loadedModule.exports);
  return loadedModule.exports;
}

const {
  ADMIN_NAV_ITEMS,
  adminNavItemsForRole,
  findActiveAdminNavItem,
  isAdminNavItemAvailable,
  searchAdminNavItems,
} = loadTypeScript("../lib/admin-nav.ts");

const superAdmin = adminNavItemsForRole("admin", {
  available: true, superAdmin: true, permissions: {},
});
const ids = (items) => items.map((item) => item.id);

test("empty search restores all permitted items without mutating the menu", () => {
  const before = ids(superAdmin);
  assert.equal(searchAdminNavItems(superAdmin, " \t "), superAdmin);
  searchAdminNavItems(superAdmin, "ร้านค้า");
  assert.deepEqual(ids(superAdmin), before);
});

test("Thai aliases and English labels find the same existing pages", () => {
  for (const [query, id] of [
    ["คำสั่งซื้อ", "food-orders"], ["Orders", "food-orders"],
    ["ผู้ใช้", "users"], ["สิทธิ์ทีมงาน", "roles"],
    ["finance", "merchant-finance"], ["การเงินร้านค้า", "merchant-finance"],
    ["คูปอง", "coupons"], ["สถานที่", "places"],
  ]) {
    assert.ok(ids(searchAdminNavItems(superAdmin, query)).includes(id), query);
  }
});

test("search normalizes casing, surrounding whitespace and Unicode width", () => {
  assert.deepEqual(ids(searchAdminNavItems(superAdmin, "  ＯＲＤＥＲＳ  ")), ["food-orders"]);
  assert.deepEqual(ids(searchAdminNavItems(superAdmin, "  mErChAnT   FiNaNcE  ")), ["merchant-finance"]);
});

test("all query terms must match the item or its current category", () => {
  assert.deepEqual(ids(searchAdminNavItems(superAdmin, "Social รายงาน")), ["reports"]);
  assert.deepEqual(searchAdminNavItems(superAdmin, "Social Orders"), []);
});

test("category search preserves order and the existing Merchant grouping", () => {
  assert.deepEqual(
    ids(searchAdminNavItems(superAdmin, "WYNOS Merchant")),
    ids(superAdmin.filter((item) => item.group === "merchant")),
  );
  assert.equal(searchAdminNavItems(superAdmin, "Stores")[0].href, "/food");
});

test("unmatched search has no results", () => {
  assert.deepEqual(searchAdminNavItems(superAdmin, "ไม่มีเมนูชื่อนี้"), []);
});

test("search never reveals super admin or Food items to Social staff", () => {
  const social = adminNavItemsForRole("staff", {
    available: true, superAdmin: false, permissions: { social: "edit" },
  });
  assert.deepEqual(searchAdminNavItems(social, "สิทธิ์"), []);
  assert.deepEqual(searchAdminNavItems(social, "Orders"), []);
  assert.deepEqual(searchAdminNavItems(social, "Audit"), []);
  assert.deepEqual(ids(searchAdminNavItems(social, "ผู้ใช้")), ["users"]);
});

test("Food view staff retain Stores access while Orders and Ads stay hidden", () => {
  const food = adminNavItemsForRole("staff", {
    available: true, superAdmin: false, permissions: { food: "view" },
  });
  assert.deepEqual(searchAdminNavItems(food, "Orders"), []);
  assert.deepEqual(searchAdminNavItems(food, "Ads"), []);
  assert.deepEqual(ids(searchAdminNavItems(food, "ร้านค้า")), ["stores"]);
});

test("legacy moderator visibility and available route matching remain intact", () => {
  const moderator = adminNavItemsForRole("moderator", {
    available: false, superAdmin: false, permissions: {},
  });
  assert.deepEqual(searchAdminNavItems(moderator, "Orders"), []);
  assert.deepEqual(searchAdminNavItems(moderator, "Ads"), []);
  assert.equal(findActiveAdminNavItem("/food/orders/123", ADMIN_NAV_ITEMS).id, "food-orders");
  assert.equal(findActiveAdminNavItem("/food/stores/123", ADMIN_NAV_ITEMS).group, "merchant");
  assert.equal(findActiveAdminNavItem("/food-other", ADMIN_NAV_ITEMS), undefined);
});

test("planned pages remain searchable but cannot become functional links", () => {
  const [payments] = searchAdminNavItems(superAdmin, "คืนเงิน");
  assert.equal(payments.id, "food-payments");
  assert.equal(isAdminNavItemAvailable(payments), false);
  assert.equal(payments.href, undefined);
});
