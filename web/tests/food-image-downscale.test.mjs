// Egress reduction: Food public photos are shrunk in the browser before upload;
// payment QR codes, private proofs and unsupported browsers keep the original.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const transpile = (path) => ts.transpileModule(read(path), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

function loadCompress({ width, height, encodedType, encodedSize, decodeFails = false, probe = null }) {
  const calls = { draw: null, canvas: null, encode: null };
  const canvas = {
    width: 0, height: 0,
    getContext: () => ({ drawImage: (_s, _x, _y, w, h) => { calls.draw = [w, h]; } }),
    toBlob(cb, type, quality) {
      calls.encode = [type, quality];
      cb(encodedType === null ? null : { type: encodedType ?? type, size: encodedSize });
    },
  };
  calls.canvas = canvas;
  const mod = { exports: {} };
  runInNewContext(transpile("../lib/compress-image.ts"), {
    module: mod, exports: mod.exports, Math, Number, Error, Promise,
    require: () => ({ IMAGE_MAX_BYTES: 1, imageUploadType() {} }),
    createImageBitmap: async () => { calls.decoded = true; if (decodeFails) throw new Error("no"); return { width, height, close() {} }; },
    document: { createElement: () => canvas },
    Uint8Array,
    ...(probe ? {
      URL: { createObjectURL: () => "blob:x", revokeObjectURL() {} },
      Image: class { set src(_v) { queueMicrotask(() => { this.naturalWidth = probe[0]; this.naturalHeight = probe[1]; this.onload(); }); } },
    } : {}),
  });
  calls.decoded = false;
  return { ...mod.exports, calls };
}
const file = (size) => ({ size, name: "a.png", type: "image/png" });

test("shrinks a large photo to at most 1600px on the long side and keeps its type", async () => {
  const c = loadCompress({ width: 4000, height: 3000, encodedSize: 300_000 });
  const blob = await c.downscalePhoto(file(5_000_000), "image/webp");
  assert.equal(blob.type, "image/webp");
  assert.deepEqual(c.calls.draw, [1600, 1200]);
  assert.equal(c.calls.encode[0], "image/webp");
  assert.equal(c.calls.encode[1], 0.82);
  const portrait = loadCompress({ width: 3000, height: 4000, encodedSize: 1 });
  await portrait.downscalePhoto(file(5_000_000), "image/jpeg");
  assert.deepEqual(portrait.calls.draw, [1200, 1600]);
});

test("does not enlarge or re-encode images already within the limit", async () => {
  const c = loadCompress({ width: 800, height: 600, encodedSize: 1 });
  assert.equal(await c.downscalePhoto(file(900_000), "image/jpeg"), null);
  assert.equal(c.calls.draw, null);
  const edge = loadCompress({ width: 1600, height: 1000, encodedSize: 1 });
  assert.equal(await edge.downscalePhoto(file(900_000), "image/jpeg"), null);
});

test("falls back to the original when the browser cannot decode or encode", async () => {
  assert.equal(await loadCompress({ width: 4000, height: 3000, encodedSize: 1, decodeFails: true }).downscalePhoto(file(5e6), "image/jpeg"), null);
  // canvas returned PNG for a WebP request (no WebP encoder)
  assert.equal(await loadCompress({ width: 4000, height: 3000, encodedType: "image/png", encodedSize: 1 }).downscalePhoto(file(5e6), "image/webp"), null);
  assert.equal(await loadCompress({ width: 4000, height: 3000, encodedType: null, encodedSize: 1 }).downscalePhoto(file(5e6), "image/jpeg"), null);
  // result not smaller than the original
  assert.equal(await loadCompress({ width: 4000, height: 3000, encodedSize: 6e6 }).downscalePhoto(file(5e6), "image/jpeg"), null);
});

test("uploadFoodPublicImage shrinks photos but never payment QR codes or private images", () => {
  const src = read("../lib/food-merchant.ts");
  assert.match(src, /foodImageBlob\(file, !\/\(\?:\^\|\\\/\)payment\$\/\.test\(folder\)\)/);
  // private uploads (slips, delivery proofs) call it without the downscale flag
  assert.match(src, /uploadFoodPrivateImage[\s\S]*?await foodImageBlob\(file\);/);
  assert.match(src, /\(downscale \? await downscalePhoto\(file, contentType\) : null\) \?\? await withoutLocation\(file, contentType\)/);
  // callers keep the same folders; QR still goes to ".../payment"
  const app = read("../components/merchant/wynos-merchant-app.tsx");
  assert.match(app, /uploadFoodPublicImage\(client, qrFile, `stores\/\$\{store\.id\}\/payment`\)/);
  const bridge = read("../lib/merchant-flutter-bridge.ts");
  assert.match(bridge, /uploadFoodPublicImage\(client, file, `stores\/\$\{storeId\}\/payment`\)/);
});

const webpFile = (bytes, size = 5_000_000) => ({
  size, name: "a.webp", type: "image/webp",
  slice: () => ({ arrayBuffer: async () => new Uint8Array(bytes).buffer }),
});
const ascii = (t) => [...t].map((c) => c.charCodeAt(0));
const riff = (...chunks) => [...ascii("RIFF"), 0, 0, 0, 0, ...ascii("WEBP"), ...chunks.flat()];

test("animated WebP keeps its original (no decode, no re-encode)", async () => {
  const flags = [...ascii("VP8X"), 10, 0, 0, 0, 0x02, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  for (const bytes of [riff(flags), riff([...ascii("VP8X"), 10, 0, 0, 0, 0, 0, 0, 0], ascii("ANIM"))]) {
    const c = loadCompress({ width: 4000, height: 3000, encodedSize: 1 });
    assert.equal(await c.downscalePhoto(webpFile(bytes), "image/webp"), null);
    assert.equal(c.calls.decoded, false);
    assert.equal(c.calls.draw, null);
  }
  // a still WebP is still shrunk
  const still = loadCompress({ width: 4000, height: 3000, encodedSize: 1 });
  const bytes = riff([...ascii("VP8X"), 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
  assert.equal((await still.downscalePhoto(webpFile(bytes), "image/webp")).type, "image/webp");
});

test("huge-dimension images above the decode ceiling keep their original without decoding", async () => {
  const c = loadCompress({ width: 20000, height: 20000, encodedSize: 1, probe: [20000, 20000] });
  assert.equal(await c.downscalePhoto(file(50_000), "image/png"), null);
  assert.equal(c.calls.decoded, false);
  const ok = loadCompress({ width: 4000, height: 3000, encodedSize: 1, probe: [4000, 3000] });
  assert.ok(await ok.downscalePhoto(file(5e6), "image/png"));
  assert.equal(ok.calls.decoded, true);
});
