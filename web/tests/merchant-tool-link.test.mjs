import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const store = "3f2b8c1a-9d4e-4a6b-8c2d-1e5f7a9b0c3d";
function compile(relative, imports = {}) {
  const source = readFileSync(new URL(relative, import.meta.url), "utf8");
  const output = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
  const mod = { exports: {} };
  runInNewContext(output, { module: mod, exports: mod.exports, URLSearchParams, require(name) { assert.ok(name in imports, `unexpected dependency: ${name}`); return imports[name]; } });
  return mod.exports;
}
const foodShare = compile("../lib/food-share.ts");
const { parseMerchantToolLink } = compile("../lib/merchant-tool-link.ts", { "@/lib/food-share": foodShare });

for (const tool of ["finance", "ads", "campaigns", "promotions", "feedback", "store", "help", "notifications"]) {
  test(`explicit ${tool} shortcut preserves a validated store preference`, () => {
    const result = parseMerchantToolLink(`?merchant-tool=${tool}&merchant-store=${store}`);
    assert.equal(result.tool, tool); assert.equal(result.storeId, store);
  });
}
test("a tool without a store leaves the existing selected-store behavior in control", () => {
  const result = parseMerchantToolLink("?merchant-tool=finance");
  assert.equal(result.tool, "finance"); assert.equal(result.storeId, null);
});
test("UUID normalization lets an uppercase link match the server's canonical store id", () => {
  assert.equal(parseMerchantToolLink(`?merchant-tool=finance&merchant-store=${store.toUpperCase()}`).storeId, store);
});
test("unknown tools, wrong parameter names and malformed store preferences do not navigate", () => {
  for (const query of ["", "?tab=finance", "?merchant-store=" + store, "?merchant-tool=orders", "?merchant-tool=Finance", "?merchant-tool=../admin", "?merchant-tool=https://evil.example", "?merchant-tool=finance&merchant-store=bad", "?merchant-tool=finance&merchant-store=", "?merchant-tool=finance&merchant-store=" + store + "x"]) {
    assert.equal(parseMerchantToolLink(query), null, query);
  }
});
test("duplicate explicit parameters are rejected rather than choosing an ambiguous page or store", () => {
  assert.equal(parseMerchantToolLink("?merchant-tool=finance&merchant-tool=ads"), null);
  assert.equal(parseMerchantToolLink(`?merchant-tool=finance&merchant-store=${store}&merchant-store=${store}`), null);
});
test("order, notification-test and payment return flows retain precedence", () => {
  for (const tool of ["finance", "help", "notifications"]) {
    for (const reserved of ["order=WF0015", "order=bad", "notification-test=1", "notification-test=0", "payments=return", "payments=refresh", "payments="]) {
      assert.equal(parseMerchantToolLink(`?merchant-tool=${tool}&merchant-store=${store}&${reserved}`), null, `${tool}: ${reserved}`);
    }
  }
});
test("an unrelated query is preserved as unrelated rather than interpreted as a store or navigation instruction", () => {
  const result = parseMerchantToolLink("?merchant-tool=feedback&store=invalid&redirect=https://evil.example");
  assert.equal(result.tool, "feedback"); assert.equal(result.storeId, null);
});
test("legacy entry resolves the preference through the existing snapshot, then consumes it only after success", () => {
  const source = readFileSync(new URL("../components/merchant/wynos-merchant-app.tsx", import.meta.url), "utf8");
  assert.match(source, /fetchMerchantSnapshot\(client, requestedTool\?\.storeId \?\? selectedStoreId\)/);
  assert.match(source, /requestedToolRef\.current = null;\s*setTab\(requestedTool\.tool\)/);
  assert.ok(source.indexOf('setTab(requestedTool.tool)') < source.indexOf('clearRequestedOrder();'), "existing order override remains later in the successful snapshot load");
});

const snapshotModule = compile("../lib/food-merchant.ts", {
  "@/lib/image-location": {},
  "@/lib/upload-image": {},
  "@/lib/food-store-availability": {},
  "@/lib/supabase/clock-skew-fetch": {},
  "@/lib/food-delivery-proof": {},
});
function snapshotClient(accessible, permittedStores) {
  const scopedReads = [];
  let reads = 0;
  const client = {
    async rpc(name, args) { assert.equal(name, "food_has_merchant_access"); assert.equal(args.p_store_id, null); return { data: accessible, error: null }; },
    from(table) {
      reads++;
      const response = { data: table === "food_stores" ? permittedStores : [], error: null };
      const builder = new Proxy({}, { get(_target, method) {
        if (method === "then") return Promise.resolve(response).then.bind(Promise.resolve(response));
        return (...args) => { if (method === "eq" && args[0] === "store_id") scopedReads.push(args[1]); return builder; };
      } });
      return builder;
    },
  };
  return { client, scopedReads, get reads() { return reads; } };
}
test("a valid but inaccessible store id falls back through the existing authorized snapshot", async () => {
  const other = "77777777-7777-4777-8777-777777777777";
  const link = parseMerchantToolLink(`?merchant-tool=finance&merchant-store=${other}`);
  const mock = snapshotClient(true, [{ id: store, name: "Accessible store" }]);
  const result = await snapshotModule.fetchMerchantSnapshot(mock.client, link.storeId);
  assert.equal(result.store.id, store);
  assert.ok(mock.scopedReads.length > 0);
  assert.ok(mock.scopedReads.every((id) => id === store), "menu and order reads use the resolved accessible store, never the requested foreign id");
});
test("a shortcut does not grant Merchant access to an account without the server gate", async () => {
  const link = parseMerchantToolLink(`?merchant-tool=finance&merchant-store=${store}`);
  const mock = snapshotClient(false, [{ id: store }]);
  const result = await snapshotModule.fetchMerchantSnapshot(mock.client, link.storeId);
  assert.equal(result.access, false); assert.equal(result.store, null); assert.equal(mock.reads, 0);
});
