import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";
import ts from "typescript";

const code = ts.transpileModule(readFileSync(new URL("../lib/admin-merchant-menu-form.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const api = {};
vm.runInNewContext(code, { exports: api });
const item = {
  id: "menu-fixture", store_id: "store-fixture", store_name: "ร้านทดสอบ", name: "Rice", category: "Main",
  description: null, price: 55, is_available: true, daily_stock_limit: null, sold_out_until: "2026-10-14T18:02:37.000Z",
  image_path: null, archived_at: null, updated_at: "2026-10-14T00:00:00.000Z",
  options: [{ id: "size", name: "Size", required: true, max_select: 1, choices: [{ id: "large", name: "Large", price: 10.5 }] }],
};
const clone = value => JSON.parse(JSON.stringify(value));

test("menu drafts preserve stable option IDs, exact prices and unchanged pause timestamp", () => {
  const draft = api.menuForm(item);
  assert.equal(draft.sold_out_until, "2026-10-15T01:02");
  assert.equal(api.menuFormError(draft), null);
  const values = api.menuValues(draft, item);
  assert.equal(values.sold_out_until, item.sold_out_until);
  assert.equal(values.options[0].choices[0].price, 10.5);
  assert.equal(values.options[0].id, "size");
  draft.options[0].choices[0].name = "Changed";
  assert.equal(item.options[0].choices[0].name, "Large", "draft must not mutate original stale-write snapshot");
});

test("Thai pause time converts across day boundary and invalid calendar dates are rejected", () => {
  const draft = api.menuForm(item);
  draft.sold_out_until = "2026-10-15T02:30";
  assert.equal(api.menuValues(draft, item).sold_out_until, "2026-10-14T19:30:00.000Z");
  for (const value of ["2026-02-30T12:00", "2026-10-15T25:00", "2026-10-15", "garbage"]) {
    assert.ok(api.menuFormError({ ...draft, sold_out_until: value }), value);
  }
  assert.equal(api.menuValues({ ...draft, sold_out_until: "" }, item).sold_out_until, null);
});

test("new menus start unavailable and stock accepts whole counts within supported bounds", () => {
  const draft = { ...api.menuForm(), name: "New menu", price: "0" };
  assert.equal(draft.is_available, false);
  assert.equal(api.menuFormError(draft), null);
  assert.equal(api.menuValues(draft).daily_stock_limit, null);
  for (const value of ["0", "1.5", "10000", "NaN", "Infinity"]) {
    assert.ok(api.menuFormError({ ...draft, daily_stock_limit: value }), value);
  }
  for (const value of ["1", "9999"]) assert.equal(api.menuFormError({ ...draft, daily_stock_limit: value }), null);
  for (const price of ["", "NaN", "Infinity", "-1", "100000.01", "1.001"]) assert.ok(api.menuFormError({ ...draft, price }), price);
});

test("option editor rejects duplicate IDs, impossible selection limits and invalid surcharge values", () => {
  const valid = api.menuForm(item);
  const cases = [
    draft => draft.options.push(clone(draft.options[0])),
    draft => draft.options[0].choices.push(clone(draft.options[0].choices[0])),
    draft => draft.options[0].choices.push({ id: " large ", name: "Duplicate after normalization", price: "0" }),
    draft => { draft.options[0].max_select = 2; },
    draft => { draft.options[0].choices = []; },
    draft => { draft.options[0].choices[0].price = ""; },
    draft => { draft.options[0].choices[0].price = "-1"; },
    draft => { draft.options[0].choices[0].price = "0.001"; },
    draft => { draft.options[0].choices[0].price = "Infinity"; },
  ];
  for (const mutate of cases) {
    const draft = clone(valid); mutate(draft);
    assert.ok(api.menuFormError(draft), mutate.toString());
  }
  assert.equal(api.menuFormError(valid), null);
});

test("menu errors preserve actionable conflicts without echoing backend data", () => {
  assert.match(api.menuErrorMessage({ message: "Menu item changed; refresh before saving" }), /โหลดข้อมูลล่าสุด/);
  assert.match(api.menuErrorMessage({ message: "Invalid menu image" }), /รูปภาพ/);
  assert.match(api.menuErrorMessage({ message: "Not authorized" }), /ไม่มีสิทธิ์/);
  assert.equal(api.menuErrorMessage({ message: "sensitive fixture backend detail" }).includes("sensitive"), false);
});
