import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";
import ts from "typescript";

const id = value => `00000000-0000-4000-8000-${String(value).padStart(12, "0")}`;
const banner = (value = 1, fields = {}) => ({
  id: id(value), title: `แบนเนอร์ ${value}`, subtitle: null,
  image_path: `banners/${id(value)}.webp`, destination_store_id: null,
  ...fields,
});
const featured = (value = 1, fields = {}) => ({ store_id: id(value), priority: value, ...fields });
const plain = value => JSON.parse(JSON.stringify(value));

function fixture({ allowed = true, authFailure = false, responses = {} } = {}) {
  const calls = { auth: 0, access: [], clients: 0, rpc: [], deadlines: [], images: [] };
  const signals = [];
  const client = {
    rpc(name) {
      const call = { name, signal: null };
      calls.rpc.push(call);
      const response = responses[name] ?? { data: [], error: null };
      const promise = response instanceof Error ? Promise.reject(response) : Promise.resolve(response);
      const request = {
        abortSignal(signal) { call.signal = signal; return request; },
        then(resolve, reject) { return promise.then(resolve, reject); },
      };
      return request;
    },
    storage: { from(bucket) {
      assert.equal(bucket, "food-banners");
      return { getPublicUrl(path) {
        calls.images.push(path);
        return { data: { publicUrl: `https://synthetic.invalid/storage/${bucket}/${path}` } };
      } };
    } },
  };
  const output = ts.transpileModule(readFileSync(new URL("../lib/admin-platform-marketing.ts", import.meta.url), "utf8"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const exports = {};
  vm.runInNewContext(output, {
    exports,
    AbortSignal: { timeout(ms) {
      calls.deadlines.push(ms);
      const signal = AbortSignal.timeout(ms);
      signals.push(signal);
      return signal;
    } },
    require(name) {
      if (name === "server-only") return {};
      if (name === "@/lib/auth") return {
        requireAdminRole: async () => {
          calls.auth++;
          if (authFailure) throw new Error("Authentication required");
          return { access: { available: true, superAdmin: false, permissions: { food: "view" } } };
        },
        adminCan: (_ctx, system, level) => {
          calls.access.push({ system, level });
          return allowed && system === "food" && level !== "edit";
        },
      };
      assert.equal(name, "@/lib/supabase/server");
      return { createClient: async () => { calls.clients++; return client; } };
    },
  });
  return { api: exports, calls, signals };
}

test("marketing query parsers accept only exact supported single values", () => {
  const { api } = fixture();
  assert.equal(api.marketingArea("featured"), "featured");
  for (const value of [undefined, null, "banners", "FEATURED", " featured", ["featured"], "unknown"]) {
    assert.equal(api.marketingArea(value), "banners");
  }
  for (const value of ["manage", "preview", "analytics"]) assert.equal(api.marketingPanel(value), value);
  for (const value of [undefined, null, "PREVIEW", " preview", ["preview"], "unknown"]) {
    assert.equal(api.marketingPanel(value), "manage");
  }
});

test("preview authorization rejects before creating a client or reading public data", async () => {
  for (const options of [{ allowed: false }, { authFailure: true }]) {
    const { api, calls } = fixture(options);
    await assert.rejects(api.fetchMarketingPreview("banners"));
    assert.equal(calls.auth, 1);
    assert.equal(calls.clients, 0);
    assert.deepEqual(calls.rpc, []);
    assert.deepEqual(calls.images, []);
  }
});

test("banner preview preserves public order and returns only public presentation fields", async () => {
  const rows = [banner(2, { subtitle: "รายละเอียด", destination_store_id: id(9), private_field: "excluded" }), banner(1)];
  const { api, calls } = fixture({ responses: { food_active_home_banners: { data: rows, error: null } } });
  const data = plain(await api.fetchMarketingPreview("banners"));
  assert.equal(data.area, "banners");
  assert.ok(Number.isFinite(Date.parse(data.checkedAt)));
  assert.deepEqual(data.items, rows.map(row => ({
    id: row.id, title: row.title, subtitle: row.subtitle, imagePath: row.image_path,
    imageUrl: `https://synthetic.invalid/storage/food-banners/${row.image_path}`,
    destinationStoreId: row.destination_store_id,
  })));
  assert.doesNotMatch(JSON.stringify(data), /private_field|excluded/);
  assert.equal(calls.auth, 1);
  assert.ok(calls.access.some(call => call.system === "food" && call.level !== "edit"));
  assert.deepEqual(calls.rpc.map(call => call.name), ["food_active_home_banners"]);
  assert.deepEqual(calls.deadlines, [10_000]);
  assert.ok(calls.rpc[0].signal instanceof AbortSignal);
});

test("featured preview keeps public selection order and uses names without adding admin-only rows", async () => {
  const { api, calls } = fixture({ responses: {
    food_active_featured_stores: { data: [featured(2, { priority: 1 }), featured(1, { priority: 1 })], error: null },
    admin_food_featured_stores: { data: [
      { store_id: id(1), store_name: "ร้านหนึ่ง", private_field: "excluded" },
      { store_id: id(3), store_name: "ร้านที่ยังไม่แสดง" },
      { store_id: id(2), store_name: "ร้านสอง" },
    ], error: null },
  } });
  const data = plain(await api.fetchMarketingPreview("featured"));
  assert.equal(data.area, "featured");
  assert.equal(data.namesAvailable, true);
  assert.ok(Number.isFinite(Date.parse(data.checkedAt)));
  assert.deepEqual(data.items, [
    { storeId: id(2), priority: 1, storeName: "ร้านสอง" },
    { storeId: id(1), priority: 1, storeName: "ร้านหนึ่ง" },
  ]);
  assert.doesNotMatch(JSON.stringify(data), /private_field|excluded|ร้านที่ยังไม่แสดง/);
  assert.deepEqual(calls.rpc.map(call => call.name).sort(), ["admin_food_featured_stores", "food_active_featured_stores"]);
  assert.ok(calls.rpc.every(call => call.signal instanceof AbortSignal));
  assert.ok(calls.deadlines.length >= 1 && calls.deadlines.every(ms => ms === 10_000));
  assert.deepEqual(calls.images, []);
});

test("unavailable name lookup preserves public featured rows and exposes uncertainty", async () => {
  for (const response of [{ data: null, error: { message: "names unavailable" } }, new Error("name lookup offline")]) {
    const { api } = fixture({ responses: {
      food_active_featured_stores: { data: [featured(2), featured(1)], error: null },
      admin_food_featured_stores: response,
    } });
    const data = plain(await api.fetchMarketingPreview("featured"));
    assert.equal(data.namesAvailable, false);
    assert.deepEqual(data.items, [
      { storeId: id(2), priority: 2, storeName: null },
      { storeId: id(1), priority: 1, storeName: null },
    ]);
  }
});

test("valid empty public selections remain successful empty results", async () => {
  const { api } = fixture();
  for (const area of ["banners", "featured"]) {
    const data = await api.fetchMarketingPreview(area);
    assert.equal(data.area, area);
    assert.deepEqual(plain(data.items), []);
  }
});

test("public RPC outages reject instead of masquerading as an empty preview", async () => {
  for (const [area, name] of [["banners", "food_active_home_banners"], ["featured", "food_active_featured_stores"]]) {
    for (const response of [{ data: null, error: { message: "public RPC unavailable" } }, new Error("public RPC offline")]) {
      const { api } = fixture({ responses: { [name]: response } });
      await assert.rejects(api.fetchMarketingPreview(area));
    }
  }
});

test("malformed public responses reject instead of claiming no current placements", async () => {
  for (const [area, name] of [["banners", "food_active_home_banners"], ["featured", "food_active_featured_stores"]]) {
    for (const data of [null, {}, { items: [] }, "[]", [null], ["invalid"]]) {
      const { api } = fixture({ responses: { [name]: { data, error: null } } });
      await assert.rejects(api.fetchMarketingPreview(area), `${area} accepted ${JSON.stringify(data)}`);
    }
  }
});

test("banner preview rejects invalid identities, image paths, duplicate rows and excess selection size", async () => {
  const invalid = [
    [banner(1, { id: "invalid" })],
    [banner(1, { destination_store_id: "invalid" })],
    [banner(1, { image_path: "https://outside.invalid/image.webp" })],
    [banner(1, { image_path: `banners/../${id(1)}.webp` })],
    [banner(1, { image_path: `banners/${id(1)}.svg` })],
    [banner(1), banner(1)],
    Array.from({ length: 9 }, (_, index) => banner(index + 1)),
  ];
  for (const data of invalid) {
    const { api } = fixture({ responses: { food_active_home_banners: { data, error: null } } });
    await assert.rejects(api.fetchMarketingPreview("banners"));
  }
});

test("featured preview rejects invalid identities, duplicate rows and excess selection size", async () => {
  const invalid = [
    [featured(1, { store_id: "invalid" })],
    [featured(1, { priority: "1" })],
    [featured(1), featured(1)],
    Array.from({ length: 21 }, (_, index) => featured(index + 1)),
  ];
  for (const data of invalid) {
    const { api } = fixture({ responses: { food_active_featured_stores: { data, error: null } } });
    await assert.rejects(api.fetchMarketingPreview("featured"));
  }
});
