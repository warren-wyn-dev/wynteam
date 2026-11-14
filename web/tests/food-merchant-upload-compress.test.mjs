import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

function compile(relative, imports = {}, extra = {}) {
  const source = readFileSync(new URL(relative, import.meta.url), "utf8");
  const output = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
  const mod = { exports: {} };
  runInNewContext(output, { module: mod, exports: mod.exports, ...extra, require(name) { assert.ok(name in imports, `unexpected dependency: ${name}`); return imports[name]; } });
  return mod.exports;
}
const uploadImage = compile("../lib/upload-image.ts");

function load({ compress }) {
  const calls = { compress: 0, strip: 0 };
  const mod = compile("../lib/food-merchant.ts", {
    "@/lib/compress-image": { compressPhoto: async (file) => { calls.compress++; return compress(file); } },
    "@/lib/image-location": { withoutLocation: async (file) => { calls.strip++; return file; } },
    "@/lib/upload-image": uploadImage,
    "@/lib/food-store-availability": {},
    "@/lib/supabase/clock-skew-fetch": {},
    "@/lib/food-delivery-proof": {},
  }, { crypto: { randomUUID: () => "00000000-0000-4000-8000-000000000000" } });
  return { mod, calls };
}
function client() {
  const uploads = [];
  return { uploads, storage: { from: (bucket) => ({ upload: async (path, blob, options) => { uploads.push({ bucket, path, blob, options }); return { error: null }; } }) } };
}
const file = (name, type, size) => ({ name, type, size });

test("compress:true uploads the smaller JPEG at a .jpg path", async () => {
  const small = { size: 400_000, type: "image/jpeg" };
  const { mod, calls } = load({ compress: async () => ({ blob: small }) });
  const c = client();
  const path = await mod.uploadFoodPublicImage(c, file("cover.png", "image/png", 3_930_598), "stores/s/cover", { compress: true });
  assert.equal(path, "stores/s/cover/00000000-0000-4000-8000-000000000000.jpg");
  assert.equal(c.uploads[0].blob, small);
  assert.equal(c.uploads[0].options.contentType, "image/jpeg");
  assert.equal(calls.compress, 1); assert.equal(calls.strip, 0);
});

test("without the option (QR, logo) the original is kept and only JPEG location is stripped", async () => {
  const { mod, calls } = load({ compress: async () => ({ blob: { size: 1 } }) });
  const c = client(); const original = file("qr.png", "image/png", 50_000);
  const path = await mod.uploadFoodPublicImage(c, original, "stores/s/payment");
  assert.match(path, /\.png$/); assert.equal(c.uploads[0].blob, original);
  assert.equal(calls.compress, 0); assert.equal(calls.strip, 1);
});

test("a compression failure or a larger result falls back to the validated original", async () => {
  for (const compress of [async () => { throw new Error("decode"); }, async () => ({ blob: { size: 999_999 } })]) {
    const { mod } = load({ compress });
    const c = client(); const original = file("menu.webp", "image/webp", 100_000);
    const path = await mod.uploadFoodPublicImage(c, original, "stores/s/menu", { compress: true });
    assert.match(path, /\.webp$/); assert.equal(c.uploads[0].blob, original);
  }
});

test("validation still runs before compression: wrong type and oversize are rejected", async () => {
  const { mod, calls } = load({ compress: async () => ({ blob: { size: 1 } }) });
  await assert.rejects(() => mod.uploadFoodPublicImage(client(), file("a.gif", "image/gif", 100), "f", { compress: true }));
  await assert.rejects(() => mod.uploadFoodPublicImage(client(), file("a.png", "image/png", 9 * 1024 * 1024), "f", { compress: true }));
  assert.equal(calls.compress, 0);
});

test("call sites compress covers and menu photos only", () => {
  const bridge = readFileSync(new URL("../lib/merchant-flutter-bridge.ts", import.meta.url), "utf8");
  const app = readFileSync(new URL("../components/merchant/wynos-merchant-app.tsx", import.meta.url), "utf8");
  assert.match(bridge, /\? "profile" : "cover"\}`, \{ compress: kind === "cover" \}\)/);
  assert.match(bridge, /stores\/\$\{storeId\}\/payment`\)/);
  assert.match(app, /stores\/\$\{store\.id\}\/menu`, \{ compress: true \}\)/);
  assert.match(app, /stores\/\$\{store\.id\}\/cover`, \{ compress: true \}\)/);
  assert.match(app, /logoFile, `stores\/\$\{store\.id\}\/profile`\)/);
  assert.match(app, /qrFile, `stores\/\$\{store\.id\}\/payment`\)/);
});
