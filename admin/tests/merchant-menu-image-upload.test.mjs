import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { test } from "node:test";
import vm from "node:vm";
import ts from "typescript";

const require = createRequire(import.meta.url);
const storeId = "00000000-0000-4000-8000-000000000001";
const otherStoreId = "00000000-0000-4000-8000-000000000002";
const path = `admin-menu/${storeId}/00000000-0000-4000-8000-000000000003.webp`;
const deferred = () => {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
};
const flush = async () => { for (let i = 0; i < 12; i++) await Promise.resolve(); };
function compile(relative, globals) {
  const source = readFileSync(new URL(relative, import.meta.url), "utf8");
  const output = ts.transpileModule(source, {
    fileName: relative,
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX },
  }).outputText;
  const exports = {};
  vm.runInNewContext(output, { exports, URL, Blob, AbortController, ...globals });
  return exports;
}
function apiFixture({ width = 3200, height = 2400, prepared = new Blob(["normalized JPEG"], { type: "image/jpeg" }), decodeError = null, decodeTask = null, fallback = false } = {}) {
  const calls = { requests: [], decoded: [], closes: 0, draw: [], fill: [], encoding: [], canvas: null, images: [], revoked: [] };
  class FakeXHR {
    constructor() { this.upload = {}; this.headers = {}; this.aborted = false; calls.requests.push(this); }
    open(method, url) { this.method = method; this.url = url; }
    setRequestHeader(name, value) { this.headers[name] = value; }
    send(body) { this.body = body; }
    abort() { this.aborted = true; this.onabort?.(); }
    finish(status = 200, response = { path }) { this.status = status; this.response = response; this.onload?.(); }
  }
  const bitmap = { width, height, close() { calls.closes++; } };
  const api = compile("../lib/admin-merchant-menu-image-upload.ts", {
    XMLHttpRequest: FakeXHR,
    createImageBitmap: fallback ? undefined : function (file) {
      calls.decoded.push(file);
      if (decodeError) return Promise.reject(decodeError);
      return decodeTask ?? Promise.resolve(bitmap);
    },
    ...(fallback ? {
      URL: { createObjectURL: () => "blob:fallback-fixture", revokeObjectURL: value => calls.revoked.push(value) },
      Image: class { constructor() { this.naturalWidth = width; this.naturalHeight = height; calls.images.push(this); } },
    } : {}),
    document: { createElement(tag) {
      assert.equal(tag, "canvas");
      const canvas = { width: 0, height: 0,
        getContext(kind) {
          assert.equal(kind, "2d");
          return { fillRect(...args) { calls.fill.push(args); }, drawImage(...args) { calls.draw.push(args); } };
        },
        toBlob(done, mime, quality) { calls.encoding.push({ mime, quality }); done(prepared); },
      };
      calls.canvas = canvas;
      return canvas;
    } },
  });
  function upload(overrides = {}) {
    const controller = new AbortController();
    const progress = [], processing = [];
    const image = new Blob(["prepared"], { type: "image/jpeg" });
    const result = api.uploadMerchantMenuImage({ supabaseUrl: "https://synthetic.supabase.invalid/", publishableKey: "public-fixture",
      accessToken: "synthetic-user-token", storeId, image, signal: controller.signal,
      onProgress: value => progress.push(value), onProcessing: () => processing.push(true), ...overrides });
    return { result, controller, progress, processing, image, xhr: calls.requests.at(-1) };
  }
  return { api, calls, bitmap, upload };
}
function sourceHeader(mime, width = 800, height = 600, kind = "VP8X") {
  if (mime === "image/jpeg") return Uint8Array.from([255, 216, 255, 192, 0, 17, 8, height >> 8, height & 255, width >> 8, width & 255, 3, 1, 17, 0, 2, 17, 0, 3, 17, 0]);
  if (mime === "image/webp") {
    const bytes = new Uint8Array(30), view = new DataView(bytes.buffer);
    bytes.set(Buffer.from("RIFF")); view.setUint32(4, 22, true); bytes.set(Buffer.from("WEBP"), 8); bytes.set(Buffer.from(kind), 12); view.setUint32(16, 10, true);
    if (kind === "VP8X") {
      for (let i = 0; i < 3; i++) { bytes[24 + i] = (width - 1) >> (i * 8) & 255; bytes[27 + i] = (height - 1) >> (i * 8) & 255; }
    } else if (kind === "VP8 ") {
      bytes.set([0x9d, 1, 0x2a], 23); view.setUint16(26, width, true); view.setUint16(28, height, true);
    } else {
      bytes[20] = 0x2f; view.setUint32(21, ((height - 1) << 14) | (width - 1), true);
    }
    return bytes;
  }
  const bytes = new Uint8Array(24), view = new DataView(bytes.buffer);
  bytes.set([137, 80, 78, 71, 13, 10, 26, 10]); view.setUint32(8, 13); bytes.set(Buffer.from("IHDR"), 12); view.setUint32(16, width); view.setUint32(20, height);
  return bytes;
}
const source = (mime = "image/png", size = 128, header = sourceHeader(mime)) => ({
  type: mime, size,
  slice(start, end) { return { arrayBuffer: () => Promise.resolve(header.slice(start, end).buffer) }; },
});

test("upload forwards prepared binary with the user's bearer token, public key, exact MIME and bounded timeout", async () => {
  const f = apiFixture();
  const u = f.upload();
  assert.equal(u.xhr.method, "POST");
  assert.equal(u.xhr.url, `https://synthetic.supabase.invalid/functions/v1/admin-merchant-menu-image?store_id=${storeId}`);
  assert.equal(u.xhr.body, u.image);
  assert.deepEqual(u.xhr.headers, { Authorization: "Bearer synthetic-user-token", apikey: "public-fixture", "Content-Type": "image/jpeg" });
  assert.equal(u.xhr.timeout, 30_000);
  assert.equal(u.xhr.withCredentials, false);
  assert.equal(u.xhr.responseType, "json");
  u.xhr.finish();
  assert.equal(await u.result, path);
});

test("progress comes from real upload events and sending all bytes enters server processing before success", async () => {
  const f = apiFixture();
  const u = f.upload();
  u.xhr.upload.onprogress({ lengthComputable: true, loaded: 5, total: 20 });
  u.xhr.upload.onprogress({ lengthComputable: false, loaded: 15, total: 20 });
  assert.deepEqual(u.progress, [25]);
  u.xhr.upload.onload();
  assert.deepEqual(u.progress, [25, 100]);
  assert.deepEqual(u.processing, [true]);
  u.xhr.finish();
  await u.result;
  assert.equal(u.xhr.upload.onprogress, null, "settled jobs must release progress callbacks");
});

test("401, permission, size, rate-limit and server failures show useful messages without echoing backend details", async () => {
  for (const [status, expected] of [[401, /เข้าสู่ระบบ/], [403, /ไม่มีสิทธิ์/], [413, /ขนาด/], [429, /รอสักครู่/], [500, /ไม่สำเร็จ/]]) {
    const f = apiFixture();
    const u = f.upload();
    u.xhr.finish(status, { error: "sensitive backend fixture" });
    await assert.rejects(u.result, error => {
      const message = f.api.menuImageUploadErrorMessage(error);
      assert.match(message, expected);
      assert.equal(message.includes("sensitive"), false);
      return true;
    });
  }
});

test("malformed, cross-store and path-traversal success responses never become selected images", async () => {
  const responses = [null, {}, "not JSON", { path: path.replace(storeId, otherStoreId) },
    { path: `admin-menu/${storeId}/../other.webp` }, { path: `${path}?token=unexpected` }, { path: path.replace(".webp", ".svg") }, { path: 123 }];
  for (const response of responses) {
    const f = apiFixture();
    const u = f.upload();
    u.xhr.finish(200, response);
    await assert.rejects(u.result, error => error.code === "response");
  }
});

test("timeout, network failure and cancellation reject once and detach all late callbacks", async () => {
  for (const event of ["timeout", "network", "abort"]) {
    const f = apiFixture();
    const u = f.upload();
    if (event === "timeout") u.xhr.ontimeout();
    if (event === "network") u.xhr.onerror();
    if (event === "abort") u.controller.abort();
    await assert.rejects(u.result, error => error.code === (event === "abort" ? "aborted" : event));
    assert.equal(u.xhr.onload, null);
    assert.equal(u.xhr.upload.onprogress, null);
    if (event === "abort") assert.equal(u.xhr.aborted, true);
    u.xhr.finish();
    assert.deepEqual(u.processing, []);
  }
});

test("already-cancelled jobs and invalid store/config/body never create requests", async () => {
  const f = apiFixture();
  const controller = new AbortController(); controller.abort();
  const cases = [{ signal: controller.signal }, { storeId: "foreign/path" }, { publishableKey: "" }, { accessToken: "" },
    { image: new Blob(["<svg/>"], { type: "image/svg+xml" }) }, { image: new Blob([]) },
    { image: new Blob([new Uint8Array(4 * 1024 * 1024 + 1)], { type: "image/jpeg" }) }];
  for (const overrides of cases) await assert.rejects(f.upload(overrides).result);
  assert.equal(f.calls.requests.length, 0);
});

test("normalization redraws to at most 1600 pixels, strips source bytes and encodes JPEG 0.85 on white", async () => {
  const f = apiFixture();
  const file = source();
  const image = await f.api.prepareMerchantMenuImage(file, new AbortController().signal);
  assert.equal(f.calls.decoded[0], file);
  assert.equal(f.calls.canvas.width, 1600);
  assert.equal(f.calls.canvas.height, 1200);
  assert.deepEqual(f.calls.fill[0], [0, 0, 1600, 1200]);
  assert.deepEqual(f.calls.draw[0].slice(1), [0, 0, 1600, 1200]);
  assert.deepEqual(f.calls.encoding, [{ mime: "image/jpeg", quality: 0.85 }]);
  assert.equal(image.type, "image/jpeg");
  assert.equal(await image.text(), "normalized JPEG");
  assert.equal(f.calls.closes, 1);
});

test("normalization preserves aspect ratio for portrait and tiny images without upscaling", async () => {
  for (const [width, height, expectedWidth, expectedHeight] of [[2400, 3200, 1200, 1600], [400, 300, 400, 300], [1, 4000, 1, 1600]]) {
    const f = apiFixture({ width, height });
    await f.api.prepareMerchantMenuImage(source("image/webp"), new AbortController().signal);
    assert.equal(f.calls.canvas.width, expectedWidth);
    assert.equal(f.calls.canvas.height, expectedHeight);
  }
});

test("8MiB source and 4MiB prepared boundaries are inclusive; oversize and corrupt inputs are rejected", async () => {
  const boundary = apiFixture({ prepared: new Blob([new Uint8Array(4 * 1024 * 1024)], { type: "image/jpeg" }) });
  assert.equal((await boundary.api.prepareMerchantMenuImage(source("image/jpeg", 8 * 1024 * 1024), new AbortController().signal)).size, 4 * 1024 * 1024);
  const rejected = [
    [apiFixture(), source("image/png", 8 * 1024 * 1024 + 1), "source_size"],
    [apiFixture(), source("image/png", 0), "source_size"],
    [apiFixture(), source("image/svg+xml"), "type"],
    [apiFixture({ decodeError: new Error("corrupt") }), source(), "image"],
    [apiFixture({ width: 0 }), source(), "image"],
    [apiFixture({ prepared: new Blob(["unexpected"], { type: "image/png" }) }), source(), "image"],
    [apiFixture({ prepared: new Blob([new Uint8Array(4 * 1024 * 1024 + 1)], { type: "image/jpeg" }) }), source(), "prepared_size"],
  ];
  for (const [f, file, code] of rejected) await assert.rejects(f.api.prepareMerchantMenuImage(file, new AbortController().signal), error => error.code === code);
});

test("cancelling while browser decoding is pending stops immediately and closes the late bitmap", async () => {
  const decode = deferred();
  const f = apiFixture({ decodeTask: decode.promise });
  const controller = new AbortController();
  const prepared = f.api.prepareMerchantMenuImage(source(), controller.signal);
  await flush();
  controller.abort();
  await assert.rejects(prepared, error => error.code === "aborted");
  decode.resolve(f.bitmap);
  await flush();
  assert.equal(f.calls.closes, 1);
  assert.equal(f.calls.canvas, null);
});

test("image-element fallback decodes and releases its object URL on success, decode failure and abort", async () => {
  for (const outcome of ["success", "error", "abort"]) {
    const f = apiFixture({ fallback: true });
    const controller = new AbortController();
    const prepared = f.api.prepareMerchantMenuImage(source(), controller.signal);
    await flush();
    const image = f.calls.images[0];
    assert.equal(image.src, "blob:fallback-fixture");
    if (outcome === "success") {
      image.onload();
      assert.equal((await prepared).type, "image/jpeg");
      assert.equal(image.src, "");
    } else {
      if (outcome === "error") image.onerror();
      else controller.abort();
      await assert.rejects(prepared, error => error.code === (outcome === "abort" ? "aborted" : "image"));
      if (outcome === "abort") assert.equal(image.src, "");
    }
    assert.equal(image.onload, null);
    assert.equal(image.onerror, null);
    assert.deepEqual(f.calls.revoked, ["blob:fallback-fixture"]);
  }
});

test("compressed PNG, JPEG and WebP dimension bombs are rejected before browser raster allocation", async () => {
  for (const [mime, kind, width, height] of [
    ["image/png", "", 100_000, 100_000], ["image/jpeg", "", 12_001, 100],
    ["image/webp", "VP8X", 8000, 8000], ["image/webp", "VP8 ", 8000, 8000], ["image/webp", "VP8L", 8000, 8000],
  ]) {
    const f = apiFixture();
    const header = sourceHeader(mime, width, height, kind);
    await assert.rejects(f.api.prepareMerchantMenuImage(source(mime, header.length, header), new AbortController().signal), error => error.code === "resolution");
    assert.equal(f.calls.decoded.length, 0, `${mime} ${kind}`);
  }
});

test("dimension preflight accepts ordinary 24MP and the exact 32MP boundary and bounds metadata scanning", async () => {
  for (const [mime, kind, width, height] of [["image/jpeg", "", 6000, 4000], ["image/png", "", 8000, 4000], ["image/webp", "VP8X", 12_000, 100], ["image/webp", "VP8 ", 800, 600], ["image/webp", "VP8L", 800, 600]]) {
    const f = apiFixture();
    await f.api.prepareMerchantMenuImage(source(mime, 128, sourceHeader(mime, width, height, kind)), new AbortController().signal);
    assert.equal(f.calls.decoded.length, 1);
  }
  const f = apiFixture(), ranges = [];
  const truncated = { type: "image/jpeg", size: 1024 * 1024,
    slice(start, end) { ranges.push([start, end]); return { arrayBuffer: () => Promise.resolve(Uint8Array.from([255, 216, 255, 225, 255, 255]).buffer) }; },
  };
  await assert.rejects(f.api.prepareMerchantMenuImage(truncated, new AbortController().signal), error => error.code === "image");
  assert.deepEqual(ranges, [[0, 256 * 1024]]);
  assert.equal(f.calls.decoded.length, 0);
});

function elements(node) {
  if (!node || typeof node !== "object") return [];
  return [node, ...[node.props?.children].flat(Infinity).flatMap(elements)];
}
function text(node) {
  if (typeof node === "string" || typeof node === "number") return String(node);
  if (!node || typeof node !== "object") return "";
  return [node?.props?.children].flat(Infinity).map(text).join("");
}
function componentFixture({ session = Promise.resolve({ data: { session: { access_token: "synthetic-token" } }, error: null }), prepare = null } = {}) {
  const state = [], refs = [], effects = [];
  let stateCursor = 0, refCursor = 0, effectCursor = 0;
  const calls = { busy: [], uploaded: [], requests: [], revoked: [], timers: new Map(), preparations: [] };
  const core = apiFixture().api;
  const hooks = {
    useId: () => "synthetic-input",
    useState(initial) {
      const index = stateCursor++;
      if (!(index in state)) state[index] = typeof initial === "function" ? initial() : initial;
      return [state[index], value => { state[index] = typeof value === "function" ? value(state[index]) : value; }];
    },
    useRef(value) { const index = refCursor++; return refs[index] ??= { current: value }; },
    useEffect(effect, deps) {
      const index = effectCursor++;
      const previous = effects[index];
      if (!previous || deps.some((value, key) => value !== previous.deps[key])) {
        previous?.cleanup?.(); effects[index] = { deps, cleanup: effect() };
      }
    },
  };
  const busyChange = value => calls.busy.push(value);
  const uploaded = value => calls.uploaded.push(value);
  const props = { storeId, disabled: false, onUploaded: uploaded, onBusyChange: busyChange };
  const exports = compile("../components/admin/merchant-menu-image-upload.tsx", {
    process: { env: { NEXT_PUBLIC_SUPABASE_URL: "https://synthetic.invalid", NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "public-fixture" } },
    URL: { createObjectURL: () => "blob:synthetic-preview", revokeObjectURL: value => calls.revoked.push(value) },
    window: { setTimeout(action, ms) { assert.equal(ms, 30_000); const key = Symbol("timer"); calls.timers.set(key, action); return key; }, clearTimeout(key) { calls.timers.delete(key); } },
    require(name) {
      if (name === "react") return hooks;
      if (name === "next/image") return { __esModule: true, default: "image-fixture" };
      if (name === "@/lib/supabase/client") return { createClient: () => ({ auth: { getSession: () => session } }) };
      if (name === "@/lib/admin-merchant-menu-image-upload") return { ...core,
        prepareMerchantMenuImage(file, signal) { calls.preparations.push(file); return prepare ? core.waitForMenuImageTask(prepare, signal) : Promise.resolve(new Blob(["jpeg"], { type: "image/jpeg" })); },
        uploadMerchantMenuImage(options) { const response = deferred(); calls.requests.push({ options, response }); return core.waitForMenuImageTask(response.promise, options.signal); },
      };
      return require(name);
    },
  });
  const render = () => { stateCursor = 0; refCursor = 0; effectCursor = 0; return exports.MerchantMenuImageUpload(props); };
  const f = { calls, props, render,
    choose(file = source()) { const input = elements(render()).find(node => node.type === "input" && node.props.type === "file"); input.props.onChange({ target: { files: [file], value: "file" } }); },
    button(label) { return elements(render()).find(node => node.type === "button" && text(node) === label); },
    unmount() { for (const effect of effects) effect?.cleanup?.(); },
  };
  return f;
}

test("component publishes a draft path only after verified success, with progress and explicit save guidance", async () => {
  const f = componentFixture();
  f.choose(); await flush();
  assert.deepEqual(f.calls.busy, [true]);
  assert.deepEqual(f.calls.uploaded, []);
  const request = f.calls.requests[0];
  request.options.onProgress(42);
  assert.match(text(f.render()), /42%/);
  request.options.onProcessing();
  assert.match(text(f.render()), /กำลังตรวจสอบรูป/);
  request.response.resolve(path); await flush();
  assert.deepEqual(f.calls.uploaded, [path]);
  assert.deepEqual(f.calls.busy, [true, false]);
  assert.match(text(f.render()), /กดยืนยันบันทึกเมนู/);
  assert.equal(f.calls.timers.size, 0);
});

test("failed or expired-session uploads preserve the parent's selected image and allow retry", async () => {
  const f = componentFixture();
  f.choose(); await flush();
  f.calls.requests[0].response.reject(new Error("private fixture")); await flush();
  assert.deepEqual(f.calls.uploaded, []);
  assert.equal(text(f.render()).includes("private"), false);
  const retry = f.button("ลองอัปโหลดอีกครั้ง"); assert.ok(retry);
  retry.props.onClick(); await flush();
  assert.equal(f.calls.requests.length, 2);
  f.calls.requests[1].response.resolve(path); await flush();
  assert.deepEqual(f.calls.uploaded, [path]);
  const expired = componentFixture({ session: Promise.resolve({ data: { session: null }, error: null }) });
  expired.choose(); await flush();
  assert.match(text(expired.render()), /เข้าสู่ระบบ/);
  assert.equal(expired.calls.requests.length, 0);
  assert.deepEqual(expired.calls.uploaded, []);
});

test("a second file cannot start another job; cancel and stale completion never replace the selected image", async () => {
  const f = componentFixture();
  f.choose(); f.choose(); await flush();
  assert.equal(f.calls.requests.length, 1);
  f.button("ยกเลิกอัปโหลด").props.onClick();
  assert.equal(f.calls.requests[0].options.signal.aborted, true);
  f.calls.requests[0].response.resolve(path); await flush();
  assert.deepEqual(f.calls.uploaded, []);
  assert.deepEqual(f.calls.busy, [true, false]);
});

test("store changes and unmount abort requests, release previews and suppress stale publication", async () => {
  for (const action of ["store", "unmount"]) {
    const f = componentFixture();
    f.choose(); await flush();
    if (action === "store") { f.props.storeId = otherStoreId; f.render(); }
    else f.unmount();
    const request = f.calls.requests[0];
    assert.equal(request.options.signal.aborted, true);
    assert.deepEqual(f.calls.revoked, ["blob:synthetic-preview"]);
    request.response.resolve(path); await flush();
    assert.deepEqual(f.calls.uploaded, []);
    assert.deepEqual(f.calls.busy, [true, false]);
  }
});

test("the 30-second deadline also cancels a hung preparation or session retrieval", async () => {
  for (const phase of ["prepare", "session"]) {
    const hung = deferred();
    const f = componentFixture(phase === "prepare" ? { prepare: hung.promise } : { session: hung.promise });
    f.choose(); await flush();
    for (const timer of [...f.calls.timers.values()]) timer();
    await flush();
    assert.match(text(f.render()), /30 วินาที/);
    assert.deepEqual(f.calls.uploaded, []);
    assert.deepEqual(f.calls.busy, [true, false]);
    assert.equal(f.calls.requests.length, 0);
    hung.resolve(phase === "prepare" ? new Blob(["jpeg"]) : { data: { session: { access_token: "late-token" } }, error: null });
    await flush();
    assert.equal(f.calls.requests.length, 0);
  }
});
