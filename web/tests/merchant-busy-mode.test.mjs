import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";

const require = createRequire(import.meta.url);
const ts = require("typescript");
const source = readFileSync(new URL("../components/merchant/merchant-busy-mode.tsx", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, jsx: ts.JsxEmit.ReactJSX,
} }).outputText;
const component = {};
runInNewContext(compiled, { exports: component, require });
const plain = (value) => JSON.parse(JSON.stringify(value));
const storeId = "00000000-0000-4000-8000-000000000001";
const store = { id: storeId, busy_mode: "off", prep_time_min_minutes: 20, prep_time_max_minutes: 35 };
const draft = (patch = {}) => ({ mode: "off", prepMin: "", prepMax: "", pauseUntil: "", ...patch });
const now = new Date("2026-10-13T09:00").getTime();
const capability = { busy_mode: true, can_manage_store: true };

test("busy mode capabilities fail closed for absent flags, invalid types, roles and network errors", async () => {
  for (const result of [{ data: null }, { data: { busy_mode: false, can_manage_store: true } },
    { data: { busy_mode: "true", can_manage_store: true } }, { data: { busy_mode: true, can_manage_store: "true" } },
    { data: capability, error: { message: "offline" } }]) {
    const calls = [];
    const client = { rpc: async (name, params) => { calls.push([name, params]); return result; } };
    await assert.rejects(component.saveMerchantBusyMode(client, store, draft(), now));
    assert.ok(calls.every(([name]) => name === "food_order_operations_features"));
    assert.equal(calls[0][1].p_store_id, storeId);
  }
  assert.deepEqual(plain(await component.fetchMerchantBusyCapabilities({ rpc: async () => { throw new Error("offline"); } }, storeId)),
    { enabled: false, canManageStore: false });
  assert.deepEqual(plain(await component.fetchMerchantBusyCapabilities({ rpc: () => assert.fail("invalid ID must not call RPC") }, "invalid")),
    { enabled: false, canManageStore: false });
});

test("prep mode sends the exact explicit preparation range without inventing an increment", async () => {
  const calls = [];
  const client = { rpc: async (name, params) => {
    calls.push([name, plain(params)]);
    return { data: name === "food_order_operations_features" ? capability : null, error: null };
  } };
  await component.saveMerchantBusyMode(client, store, draft({ mode: "prep", prepMin: "25", prepMax: "45" }), now);
  assert.deepEqual(calls[1], ["merchant_set_food_busy_mode", {
    p_store_id: storeId, p_mode: "prep", p_prep_min: 25, p_prep_max: 45, p_pause_until: null,
  }]);
});

test("prep mode rejects incomplete, fractional, decreasing and out-of-range times before any RPC", async () => {
  const client = { rpc: () => assert.fail("invalid preparation range must not call RPC") };
  for (const [prepMin, prepMax] of [["", "40"], ["25", ""], ["0", "40"], ["20.5", "40"],
    ["19", "40"], ["20", "34"], ["45", "40"], ["20", "241"]]) {
    await assert.rejects(component.saveMerchantBusyMode(client, store, draft({ mode: "prep", prepMin, prepMax }), now));
  }
});

test("pause mode requires the user's valid future deadline and converts local time to ISO", async () => {
  const calls = [];
  const client = { rpc: async (name, params) => {
    calls.push([name, plain(params)]);
    return { data: name === "food_order_operations_features" ? capability : null, error: null };
  } };
  await component.saveMerchantBusyMode(client, store, draft({ mode: "pause", pauseUntil: "2026-10-13T10:30" }), now);
  assert.deepEqual(calls[1], ["merchant_set_food_busy_mode", {
    p_store_id: storeId, p_mode: "pause", p_prep_min: null, p_prep_max: null,
    p_pause_until: new Date("2026-10-13T10:30").toISOString(),
  }]);
  for (const pauseUntil of ["", "invalid", "2026-10-13T09:00", "2026-10-13T08:59", "2026-02-30T10:30", "2026-10-13T25:00"]) {
    assert.throws(() => component.buildMerchantBusyParams(store, draft({ mode: "pause", pauseUntil }), now));
  }
});

test("off mode leaves preparation values untouched and delegates clearing only the busy pause to the server", async () => {
  const calls = [];
  const client = { rpc: async (name, params) => {
    calls.push([name, plain(params)]);
    return { data: name === "food_order_operations_features" ? capability : null, error: null };
  } };
  await component.saveMerchantBusyMode(client, { ...store, busy_mode: "pause" }, draft({ prepMin: "1", prepMax: "1", pauseUntil: "invalid" }), now);
  assert.deepEqual(calls[1], ["merchant_set_food_busy_mode", {
    p_store_id: storeId, p_mode: "off", p_prep_min: null, p_prep_max: null, p_pause_until: null,
  }]);
});

test("failed busy write uses user-safe error text and refuses invalid mode/store IDs", async () => {
  const client = { rpc: async (name) => name === "food_order_operations_features"
    ? { data: capability } : { error: { message: "sensitive internal detail" } } };
  await assert.rejects(component.saveMerchantBusyMode(client, store, draft(), now),
    (error) => !error.message.includes("sensitive internal detail") && error.message.includes("บันทึก Busy Mode ไม่สำเร็จ"));
  assert.throws(() => component.buildMerchantBusyParams({ ...store, id: "invalid" }, draft(), now));
  assert.throws(() => component.buildMerchantBusyParams(store, draft({ mode: "auto" }), now));
});

function panel(patch = {}) {
  return renderToStaticMarkup(createElement(component.MerchantBusyModePanel, {
    client: {}, store, capabilities: { enabled: true, canManageStore: true }, onReload: () => {}, ...patch,
  }));
}

test("flag off or missing management capability renders no controls", () => {
  assert.equal(panel({ capabilities: { enabled: false, canManageStore: true } }), "");
  assert.equal(panel({ capabilities: { enabled: true, canManageStore: false } }), "");
  assert.equal(renderToStaticMarkup(createElement(component.MerchantBusyMode, { client: {}, store, onReload: () => {} })), "");
});

test("busy controls keep three modes, explicit confirmation and no automatic preparation restoration claim", () => {
  const markup = panel();
  assert.equal((markup.match(/type="radio"/g) ?? []).length, 3);
  assert.match(markup, /ปิด Busy Mode/);
  assert.match(markup, /เพิ่มเวลาเตรียม/);
  assert.match(markup, /พักรับออเดอร์/);
  assert.match(markup, /เวลาเตรียมจะคงค่าปัจจุบัน และไม่ย้อนกลับอัตโนมัติ/);
  assert.match(markup, /ยืนยันโหมดและค่าที่เลือกก่อนบันทึก/);
  assert.match(markup, /<button[^>]*disabled=""[^>]*>บันทึก Busy Mode<\/button>/);
});

test("prep controls prefill actual store values; pause has no guessed duration or deadline", () => {
  const prep = panel({ store: { ...store, busy_mode: "prep" } });
  assert.match(prep, /value="20"/);
  assert.match(prep, /value="35"/);
  const pause = panel({ store: { ...store, busy_mode: "pause" } });
  assert.match(pause, /type="datetime-local"[^>]*value=""/);
  assert.doesNotMatch(pause, /value="2026/);
});
