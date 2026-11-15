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
const { FOOD_CUSTOMER_STORE_COLUMNS, selectCustomerStore } = await import("../lib/food-customer.ts");
const source = readFileSync(new URL("../lib/food-customer.ts", import.meta.url), "utf8");

const OWNER_ONLY = ["tax_id", "tax_address", "tax_legal_name", "tax_branch", "tax_invoice_enabled", "gp_rate_bp", "admin_suspended_by"];

test("the customer store column list never includes owner-only data", () => {
  const columns = FOOD_CUSTOMER_STORE_COLUMNS.split(",");
  for (const name of OWNER_ONLY) assert.ok(!columns.includes(name), name);
  assert.equal(new Set(columns).size, columns.length, "duplicate column");
});

test("every listed column is a field of FoodCustomerStore, so the list cannot drift", () => {
  const type = /export type FoodCustomerStore = \{([\s\S]*?)\n\};/.exec(source)?.[1] ?? "";
  const fields = new Set([...type.matchAll(/^\s{2}(\w+)\??:/gm)].map((match) => match[1]));
  for (const column of FOOD_CUSTOMER_STORE_COLUMNS.split(",")) assert.ok(fields.has(column), `${column} is not in the type`);
  for (const field of fields) assert.ok(FOOD_CUSTOMER_STORE_COLUMNS.split(",").includes(field), `${field} missing from the list`);
});

test("no wildcard select on food_stores remains outside the 42703 fallback", () => {
  assert.doesNotMatch(source, /from\("food_stores"\)\s*\.select\("\*"\)/);
  assert.match(source, /code === "42703"/);
});

function fakeClient(respond) {
  const calls = [];
  return {
    calls,
    from(table) {
      assert.equal(table, "food_stores");
      return {
        select(columns) {
          calls.push(columns);
          const chain = { eq: () => chain, order: () => chain, limit: () => chain, maybeSingle: async () => respond(columns) };
          return chain;
        },
      };
    },
  };
}

test("a picked store is read with the explicit column list", async () => {
  const client = fakeClient(() => ({ data: { id: "s1" }, error: null }));
  const result = await selectCustomerStore(client, FOOD_CUSTOMER_STORE_COLUMNS, "s1");
  assert.equal(result.data.id, "s1");
  assert.deepEqual(client.calls, [FOOD_CUSTOMER_STORE_COLUMNS]);
});

test("without a pick, the first store is read with the same columns", async () => {
  const client = fakeClient(() => ({ data: { id: "first" }, error: null }));
  const result = await selectCustomerStore(client, FOOD_CUSTOMER_STORE_COLUMNS, null);
  assert.equal(result.data.id, "first");
  assert.deepEqual(client.calls, [FOOD_CUSTOMER_STORE_COLUMNS]);
});
