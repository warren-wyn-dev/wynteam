import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

function load(path, stubs = {}) {
  const compiled = ts.transpileModule(readFileSync(new URL(path, import.meta.url), "utf8"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const mod = { exports: {} };
  runInNewContext(compiled, { module: mod, exports: mod.exports, require: (name) => stubs[name] ?? {}, Math, Number, Error, Array, Map, String, crypto: { randomUUID: () => "00000000-0000-4000-8000-000000000000" } });
  return mod.exports;
}

const { fitWithin, PHOTO_MAX_SIDE } = load("../lib/compress-image.ts", { "@/lib/upload-image": { IMAGE_MAX_BYTES: 1, imageUploadType() {} } });
const { canHavePhotos, uploadPlacePhoto } = load("../lib/maps-place-photos.ts", { "@/lib/compress-image": { compressPhoto: async () => ({ blob: "jpeg", width: 1600, height: 1200 }) } });

test("photos shrink to the max side and never upscale", () => {
  assert.equal(PHOTO_MAX_SIDE, 1600);
  assert.equal(JSON.stringify(fitWithin(4032, 3024)), JSON.stringify({ width: 1600, height: 1200 }));
  assert.equal(JSON.stringify(fitWithin(3024, 4032)), JSON.stringify({ width: 1200, height: 1600 }));
  assert.equal(JSON.stringify(fitWithin(800, 600)), JSON.stringify({ width: 800, height: 600 }));
  assert.throws(() => fitWithin(0, 100));
});

test("only WYNOS Places can carry photos", () => {
  assert.equal(canHavePhotos("wynos_place_" + "a".repeat(32)), true);
  assert.equal(canHavePhotos("p1"), false);
  assert.equal(canHavePhotos(null), false);
});

test("upload removes the object when the server refuses the photo", async () => {
  const removed = [];
  const client = {
    auth: { getSession: async () => ({ data: { session: { user: { id: "u1" } } } }) },
    storage: { from: () => ({ upload: async () => ({ error: null }), remove: async (paths) => { removed.push(...paths); return {}; } }) },
    rpc: async () => ({ error: { message: "place photo limit reached" } }),
  };
  await assert.rejects(uploadPlacePhoto(client, "wynos_place_" + "a".repeat(32), {}), /สูงสุด 5 รูป/);
  assert.equal(removed.length, 1);
  assert.match(removed[0], /^u1\/.+\.jpg$/);
});

test("signed-out uploads stop before touching storage", async () => {
  let touched = false;
  const client = { auth: { getSession: async () => ({ data: { session: null } }) }, storage: { from: () => { touched = true; } } };
  await assert.rejects(uploadPlacePhoto(client, "x", {}), /เข้าสู่ระบบ/);
  assert.equal(touched, false);
});
