import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { test } from "node:test";
import vm from "node:vm";
import ts from "typescript";

const require = createRequire(import.meta.url);
const id = value => `00000000-0000-4000-8000-${String(value).padStart(12, "0")}`;
const imagePath = `banners/${id(1)}.webp`;
const banner = { id: id(1), title: "แบนเนอร์เดิม", subtitle: null, image_path: imagePath,
  destination_store_id: null, sort_order: 10, starts_at: "2026-10-01T00:00:00Z", ends_at: null,
  is_active: false, version: 1, created_at: "2026-10-01T00:00:00Z", updated_at: "2026-10-01T00:00:00Z" };
const placement = { store_id: id(1), store_name: "ร้านหนึ่ง", priority: 3, active: true,
  starts_at: "2026-10-01T00:00:00Z", ends_at: "2026-11-01T00:00:00Z", version: 7 };
const deferred = () => {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
};
function elements(node) {
  if (!node || typeof node !== "object") return [];
  return [node, ...[node.props?.children].flat(Infinity).flatMap(elements)];
}
function text(node) {
  if (typeof node === "string" || typeof node === "number") return String(node);
  if (!node || typeof node !== "object") return "";
  return [node?.props?.children].flat(Infinity).map(text).join("");
}

function fixture(kind, { initial = [], responses = {}, uploadResult = { error: null } } = {}) {
  const calls = { rpc: [], deadlines: [], uploads: [], refreshes: 0 };
  const state = [], tasks = [];
  let cursor = 0;
  const hooks = {
    useState(initialValue) {
      const index = cursor++;
      if (!(index in state)) state[index] = typeof initialValue === "function" ? initialValue() : initialValue;
      return [state[index], value => { state[index] = typeof value === "function" ? value(state[index]) : value; }];
    },
    useTransition() {
      const index = cursor++;
      if (!(index in state)) state[index] = false;
      return [state[index], action => {
        state[index] = true;
        const task = Promise.resolve().then(action).finally(() => { state[index] = false; });
        tasks.push(task);
      }];
    },
  };
  const client = {
    rpc(name, params) {
      const call = { name, params, signal: null };
      calls.rpc.push(call);
      const source = responses[name];
      const response = typeof source === "function" ? source(params) : source ?? { data: [], error: null };
      const promise = response instanceof Error ? Promise.reject(response) : Promise.resolve(response);
      const request = { abortSignal(signal) { call.signal = signal; return request; }, then(resolve, reject) { return promise.then(resolve, reject); } };
      return request;
    },
    storage: { from(bucket) {
      assert.equal(bucket, "food-banners");
      return {
        getPublicUrl: path => ({ data: { publicUrl: `https://synthetic.invalid/${path}` } }),
        upload(path, file, options) { calls.uploads.push({ path, file, options }); return Promise.resolve(uploadResult); },
      };
    } },
  };
  const source = readFileSync(new URL(`../components/admin/food-${kind}-manager.tsx`, import.meta.url), "utf8");
  const output = ts.transpileModule(source, {
    fileName: `food-${kind}-manager.tsx`,
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX },
  }).outputText;
  const exports = {};
  vm.runInNewContext(output, { exports, window: { confirm: () => true }, crypto: { randomUUID: () => id(1) },
    AbortSignal: { timeout(ms) { calls.deadlines.push(ms); return AbortSignal.timeout(ms); } },
    require(name) {
      if (name === "react") return hooks;
      if (name === "next/navigation") return { useRouter: () => ({ refresh: () => { calls.refreshes++; } }) };
      if (name === "@/lib/supabase/client") return { createClient: () => client };
      return require(name);
    },
  });
  const Component = kind === "banner" ? exports.FoodBannerManager : exports.FoodFeaturedManager;
  const render = () => { cursor = 0; return Component({ initial, stores: [{ id: id(1), name: "ร้านหนึ่ง" }, { id: id(2), name: "ร้านสอง" }], canEdit: true }); };
  const controls = label => {
    const match = elements(render()).find(node => node.type === "label" && text(node).startsWith(label));
    assert.ok(match, `missing label: ${label}`);
    const input = elements(match).find(node => ["input", "select", "textarea"].includes(node.type));
    assert.ok(input, label);
    return input;
  };
  return { calls, responses, render, controls,
    button(label) {
      const button = elements(render()).find(node => node.type === "button" && text(node) === label);
      assert.ok(button, `missing button: ${label}`);
      return button;
    },
    change(label, value) { controls(label).props.onChange({ target: { value, checked: value } }); },
    async flush() { while (tasks.length) await tasks.shift(); },
    message(role) { return elements(render()).filter(node => node.props?.role === role).map(text).join(" "); },
  };
}

async function newBanner(f) {
  f.change("หัวข้อแบนเนอร์", "แบนเนอร์ใหม่");
  f.controls("อัปโหลดภาพแบนเนอร์").props.onChange({ target: { files: [{ type: "image/webp", size: 100 }], value: "synthetic" } });
  await new Promise(resolve => setImmediate(resolve));
  f.change("เหตุผลการเปลี่ยนแปลง", "ทดสอบการบันทึกแบนเนอร์");
}

test("featured form initially reflects the first selected store's persisted settings", () => {
  const f = fixture("featured", { initial: [placement] });
  assert.equal(f.controls("เลือกร้าน").props.value, placement.store_id);
  assert.equal(f.controls("ลำดับร้านแนะนำ").props.value, "3");
  assert.equal(f.controls("เปิดใช้งานร้านแนะนำ").props.checked, true);
  assert.notEqual(f.controls("หยุดแสดง").props.value, "");
});

test("confirmed banner creation retains its identity across reload failure and blocks a duplicate write", async () => {
  const f = fixture("banner", { responses: {
    admin_save_food_home_banner: { data: banner, error: null },
    admin_food_home_banners: { data: null, error: { message: "read unavailable" } },
  } });
  await newBanner(f);
  f.button("ตรวจและยืนยันบันทึกจริง").props.onClick();
  await f.flush();
  assert.match(f.message("alert"), /บันทึกสำเร็จ.*โหลดข้อมูลล่าสุดไม่สำเร็จ/);
  assert.equal(f.controls("หัวข้อแบนเนอร์").props.value, "แบนเนอร์ใหม่");
  assert.equal(f.button("ตรวจและยืนยันบันทึกจริง").props.disabled, true);
  f.button("ตรวจและยืนยันบันทึกจริง").props.onClick();
  await f.flush();
  assert.equal(f.calls.rpc.filter(call => call.name === "admin_save_food_home_banner").length, 1);
  f.responses.admin_food_home_banners = { data: [{ ...banner, version: 2 }], error: null };
  f.button("โหลดข้อมูลล่าสุด").props.onClick();
  await f.flush();
  assert.equal(f.controls("เลือกแบนเนอร์").props.value, banner.id);
  assert.equal(f.controls("หัวข้อแบนเนอร์").props.value, banner.title);
  assert.deepEqual(f.calls.deadlines, [20_000, 10_000, 10_000]);
  assert.ok(f.calls.rpc.every(call => call.signal instanceof AbortSignal));
});

test("an unknown new-banner write requires a fresh read and clears the null-id draft before reuse", async () => {
  const f = fixture("banner", { responses: { admin_save_food_home_banner: { data: null, error: { message: "AbortError: timed out", code: "" } } } });
  await newBanner(f);
  f.button("ตรวจและยืนยันบันทึกจริง").props.onClick();
  await f.flush();
  assert.match(f.message("alert"), /ยังยืนยันผลการบันทึกไม่ได้/);
  assert.equal(f.button("ตรวจและยืนยันบันทึกจริง").props.disabled, true);
  assert.equal(f.controls("เลือกแบนเนอร์").props.disabled, true);
  f.responses.admin_food_home_banners = { data: [banner], error: null };
  f.button("โหลดข้อมูลล่าสุด").props.onClick();
  await f.flush();
  assert.equal(f.controls("เลือกแบนเนอร์").props.value, "new");
  assert.equal(f.controls("หัวข้อแบนเนอร์").props.value, "");
  assert.equal(f.button("ตรวจและยืนยันบันทึกจริง").props.disabled, true);
});

test("failed or malformed banner reload preserves draft edits and reason", async () => {
  const f = fixture("banner", { initial: [banner], responses: { admin_food_home_banners: { data: null, error: null } } });
  f.change("เลือกแบนเนอร์", banner.id);
  f.change("หัวข้อแบนเนอร์", "ข้อความที่ยังไม่บันทึก");
  f.change("เหตุผลการเปลี่ยนแปลง", "เหตุผลฉบับร่าง");
  f.button("โหลดข้อมูลล่าสุด").props.onClick();
  await f.flush();
  assert.match(f.message("alert"), /ข้อมูลที่แก้ไขยังอยู่/);
  assert.equal(f.controls("หัวข้อแบนเนอร์").props.value, "ข้อความที่ยังไม่บันทึก");
  assert.equal(f.controls("เหตุผลการเปลี่ยนแปลง").props.value, "เหตุผลฉบับร่าง");
});

test("banner selection remains fixed while an image upload is pending", async () => {
  const upload = deferred();
  const f = fixture("banner", { initial: [banner], uploadResult: upload.promise });
  f.change("หัวข้อแบนเนอร์", "ร่างใหม่");
  f.controls("อัปโหลดภาพแบนเนอร์").props.onChange({ target: { files: [{ type: "image/webp", size: 100 }], value: "synthetic" } });
  assert.equal(f.controls("เลือกแบนเนอร์").props.disabled, true);
  f.change("เลือกแบนเนอร์", banner.id);
  assert.equal(f.controls("หัวข้อแบนเนอร์").props.value, "ร่างใหม่");
  upload.resolve({ error: null });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(f.controls("เลือกแบนเนอร์").props.value, "new");
});

test("featured save reload failures preserve edits, disable retries and recover through a fresh read", async () => {
  const f = fixture("featured", { initial: [placement], responses: {
    admin_save_food_featured_store: { data: { ...placement, version: 8 }, error: null },
    admin_food_featured_stores: { data: null, error: { message: "read unavailable" } },
  } });
  f.change("ลำดับร้านแนะนำ", "5");
  f.change("เหตุผลการเปลี่ยนแปลง", "เปลี่ยนลำดับร้านทดสอบ");
  f.button("ตรวจและยืนยันบันทึกจริง").props.onClick();
  await f.flush();
  assert.match(f.message("alert"), /บันทึกสำเร็จ.*โหลดข้อมูลล่าสุดไม่สำเร็จ/);
  assert.equal(f.controls("ลำดับร้านแนะนำ").props.value, "5");
  assert.equal(f.controls("เหตุผลการเปลี่ยนแปลง").props.value, "เปลี่ยนลำดับร้านทดสอบ");
  assert.equal(f.controls("เลือกร้าน").props.disabled, true);
  assert.equal(f.button("ตรวจและยืนยันบันทึกจริง").props.disabled, true);
  f.change("เลือกร้าน", id(2));
  assert.equal(f.controls("เลือกร้าน").props.value, id(1));
  f.responses.admin_food_featured_stores = { data: [{ ...placement, priority: 5, version: 8 }], error: null };
  f.button("โหลดข้อมูลล่าสุด").props.onClick();
  await f.flush();
  assert.equal(f.controls("เลือกร้าน").props.disabled, false);
  f.change("เหตุผลการเปลี่ยนแปลง", "ตรวจค่าล่าสุดแล้ว");
  assert.equal(f.button("ตรวจและยืนยันบันทึกจริง").props.disabled, false);
  assert.deepEqual(f.calls.deadlines, [20_000, 10_000, 10_000]);
  assert.equal(f.calls.rpc[0].params.p_expected_version, 7);
});

test("pending featured writes disable every way to switch the selected store", async () => {
  const write = deferred();
  const f = fixture("featured", { initial: [placement], responses: {
    admin_save_food_featured_store: write.promise,
    admin_food_featured_stores: { data: [placement], error: null },
  } });
  f.change("เหตุผลการเปลี่ยนแปลง", "ทดสอบการบันทึกร้านแนะนำ");
  f.button("ตรวจและยืนยันบันทึกจริง").props.onClick();
  assert.equal(f.controls("เลือกร้าน").props.disabled, true);
  const listButton = elements(f.render()).find(node => node.type === "button" && text(node).startsWith("ร้านหนึ่ง"));
  assert.equal(listButton.props.disabled, true);
  f.change("เลือกร้าน", id(2));
  assert.equal(f.controls("เลือกร้าน").props.value, id(1));
  write.resolve({ data: placement, error: null });
  await f.flush();
});

test("unknown featured write outcomes require a fresh read before another mutation", async () => {
  const f = fixture("featured", { initial: [placement], responses: {
    admin_save_food_featured_store: { data: null, error: { code: "", message: "AbortError: timed out" } },
  } });
  f.change("ลำดับร้านแนะนำ", "6");
  f.change("เหตุผลการเปลี่ยนแปลง", "ทดสอบผลลัพธ์ไม่แน่นอน");
  f.button("ตรวจและยืนยันบันทึกจริง").props.onClick();
  await f.flush();
  assert.match(f.message("alert"), /ยังยืนยันผลการบันทึกไม่ได้/);
  assert.equal(f.controls("ลำดับร้านแนะนำ").props.value, "6");
  assert.equal(f.button("ตรวจและยืนยันบันทึกจริง").props.disabled, true);
  f.button("ตรวจและยืนยันบันทึกจริง").props.onClick();
  await f.flush();
  assert.equal(f.calls.rpc.filter(call => call.name === "admin_save_food_featured_store").length, 1);
});

test("malformed featured reload preserves draft fields and its original optimistic version", async () => {
  const f = fixture("featured", { initial: [placement], responses: {
    admin_food_featured_stores: { data: [{ ...placement, starts_at: "invalid", priority: 99, version: 20 }], error: null },
    admin_save_food_featured_store: { data: null, error: { code: "P0001", message: "placement changed" } },
  } });
  f.change("ลำดับร้านแนะนำ", "5");
  f.change("เหตุผลการเปลี่ยนแปลง", "เก็บร่างเมื่ออ่านข้อมูลผิดรูปแบบ");
  f.button("โหลดข้อมูลล่าสุด").props.onClick();
  await f.flush();
  assert.match(f.message("alert"), /ข้อมูลที่แก้ไขยังอยู่/);
  assert.equal(f.controls("ลำดับร้านแนะนำ").props.value, "5");
  assert.equal(f.controls("เหตุผลการเปลี่ยนแปลง").props.value, "เก็บร่างเมื่ออ่านข้อมูลผิดรูปแบบ");
  f.button("ตรวจและยืนยันบันทึกจริง").props.onClick();
  await f.flush();
  assert.equal(f.calls.rpc.find(call => call.name === "admin_save_food_featured_store").params.p_expected_version, 7);
});

test("a malformed saved-banner identity locks writes until a fresh read", async () => {
  const f = fixture("banner", { responses: { admin_save_food_home_banner: { data: {}, error: null } } });
  await newBanner(f);
  f.button("ตรวจและยืนยันบันทึกจริง").props.onClick();
  await f.flush();
  assert.equal(f.button("ตรวจและยืนยันบันทึกจริง").props.disabled, true);
  assert.equal(f.calls.rpc.some(call => call.name === "admin_food_home_banners"), false);
  assert.equal(f.controls("หัวข้อแบนเนอร์").props.value, "แบนเนอร์ใหม่");
});

test("CMS server reads use bounded RPCs and malformed payloads never become empty datasets", async () => {
  for (const path of ["admin-food-banners", "admin-food-featured"]) {
    const calls = [], deadlines = [];
    let malformed = false;
    const output = ts.transpileModule(readFileSync(new URL(`../lib/${path}.ts`, import.meta.url), "utf8"), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
    }).outputText;
    const api = {};
    vm.runInNewContext(output, { exports: api, AbortSignal: { timeout(ms) { deadlines.push(ms); return AbortSignal.timeout(ms); } }, require(name) {
      assert.equal(name, "@/lib/supabase/server");
      return { createClient: async () => ({ rpc(name, params) {
        const call = { name, params }; calls.push(call);
        return { abortSignal(signal) { call.signal = signal; return Promise.resolve({ data: malformed ? null : [], error: null }); } };
      } }) };
    } });
    const reads = path === "admin-food-banners" ? [api.fetchAdminFoodBanners, api.fetchAdminBannerStores] : [api.getFoodFeaturedAdminData];
    for (const read of reads) await read();
    assert.ok(calls.every(call => call.signal instanceof AbortSignal));
    assert.deepEqual(deadlines, [10_000, 10_000]);
    malformed = true;
    for (const read of reads) await assert.rejects(read());
  }
});
