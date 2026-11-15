import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { registerHooks } from "node:module";
import test from "node:test";

registerHooks({
  resolve(specifier, context, next) {
    if (specifier.startsWith("@/")) return next(new URL(`../${specifier.slice(2)}.ts`, import.meta.url).href, context);
    return next(specifier, context);
  },
});
const lib = await import("../lib/food-merchant.ts");
const bridge = readFileSync(new URL("../lib/merchant-flutter-bridge.ts", import.meta.url), "utf8");
const TAX = ["tax_invoice_enabled", "tax_legal_name", "tax_id", "tax_branch", "tax_address"];

test("the store column list has no tax column and no platform-only column", () => {
  const columns = lib.FOOD_STORE_COLUMNS.split(",");
  for (const name of [...TAX, "gp_rate_bp"]) assert.ok(!columns.includes(name), name);
  assert.equal(new Set(columns).size, columns.length);
  assert.deepEqual([...lib.FOOD_STORE_TAX_COLUMNS], TAX);
  // The production list on 2026-11-15 has 57 columns, 5 of them tax.
  assert.equal(columns.length, 52);
});

function client({ rpc, direct }) {
  const calls = [];
  return {
    calls,
    rpc: async (name, args) => { calls.push(["rpc", name, args]); return rpc(); },
    from: (table) => ({ select: (columns) => ({ eq: () => ({ maybeSingle: async () => { calls.push(["select", table, columns]); return direct(); } }) }) }),
  };
}

test("tax details come from the owner-checked function", async () => {
  const c = client({ rpc: () => ({ data: [{ tax_id: "0000000000001", tax_invoice_enabled: true }], error: null }), direct: () => assert.fail("no direct read") });
  const tax = await lib.fetchFoodStoreTax(c, "s1");
  assert.equal(tax.tax_id, "0000000000001");
  assert.deepEqual(c.calls, [["rpc", "food_store_tax_get", { p_store_id: "s1" }]]);
});

test("while the function is not installed the direct columns are used", async () => {
  const c = client({ rpc: () => ({ data: null, error: { code: "PGRST202" } }), direct: () => ({ data: { tax_id: "1" }, error: null }) });
  assert.equal((await lib.fetchFoodStoreTax(c, "s1")).tax_id, "1");
  assert.deepEqual(c.calls[1], ["select", "food_stores", TAX.join(",")]);
});

test("a caller who may not see the tax details gets null and never falls back to the table", async () => {
  const c = client({ rpc: () => ({ data: null, error: { code: "P0001", message: "Not authorized" } }), direct: () => assert.fail("no direct read") });
  assert.equal(await lib.fetchFoodStoreTax(c, "s1"), null);
});

test("attachFoodStoreTax merges tax into each store and leaves others untouched", async () => {
  const c = client({
    rpc: () => ({ data: [{ tax_id: "9" }], error: null }), direct: () => assert.fail("no direct read"),
  });
  const merged = await lib.attachFoodStoreTax(c, [{ id: "a", name: "A" }]);
  assert.deepEqual(merged, [{ id: "a", name: "A", tax_id: "9" }]);
  const denied = client({ rpc: () => ({ data: null, error: { code: "P0001" } }), direct: () => assert.fail("no direct read") });
  assert.deepEqual(await lib.attachFoodStoreTax(denied, [{ id: "a", name: "A" }]), [{ id: "a", name: "A" }]);
});

test("an older database falls back to the wildcard only for an undefined column", () => {
  assert.equal(lib.isUndefinedColumnError({ code: "42703" }), true);
  assert.equal(lib.isUndefinedColumnError({ code: "42501" }), false);
  assert.equal(lib.isUndefinedColumnError(null), false);
});

test("the Flutter bridge no longer reads tax columns from the table or keeps them in storage", () => {
  assert.doesNotMatch(bridge, /from\("food_stores"\)\.select\("\*"\)/);
  assert.match(bridge, /attachFoodStoreTax\(client, \[\.\.\.stores\.values\(\)\]\)/);
  assert.match(bridge, /fetchFoodStoreTax\(client, storeId\)/);
  assert.match(bridge, /never kept in browser storage/);
});
