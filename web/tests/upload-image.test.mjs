import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const compiled = ts.transpileModule(read("../lib/upload-image.ts"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const mod = { exports: {} };
runInNewContext(compiled, { module: mod, exports: mod.exports, Math });
const { imageUploadType, AVATAR_MAX_BYTES } = mod.exports;
const file = (name, type, size = 1000) => ({ name, type, size });

test("the stored type/extension come from a validated MIME, never the file name", () => {
  assert.deepEqual({ ...imageUploadType(file("photo.html", "image/png")) }, { contentType: "image/png", extension: "png" });
  assert.deepEqual({ ...imageUploadType(file("IMG_1.HEIC", "")) }, { contentType: "image/heic", extension: "heic" });
  assert.deepEqual({ ...imageUploadType(file("a.jpeg", "image/jpeg")) }, { contentType: "image/jpeg", extension: "jpeg" });
  assert.deepEqual({ ...imageUploadType(file("a.png", "image/jpeg")) }, { contentType: "image/jpeg", extension: "jpg" });
});

test("script-capable and non-image files are rejected before upload", () => {
  assert.throws(() => imageUploadType(file("x.svg", "image/svg+xml")), /รองรับเฉพาะไฟล์รูปภาพ/);
  assert.throws(() => imageUploadType(file("x.html", "text/html")), /รองรับเฉพาะไฟล์รูปภาพ/);
  assert.throws(() => imageUploadType(file("x.jpg", "text/html")), /รองรับเฉพาะไฟล์รูปภาพ/);
  assert.throws(() => imageUploadType(file("noext", "")), /รองรับเฉพาะไฟล์รูปภาพ/);
});

test("size limits match the bucket limits", () => {
  assert.throws(() => imageUploadType(file("a.jpg", "image/jpeg", AVATAR_MAX_BYTES + 1), AVATAR_MAX_BYTES), /สูงสุด 10 MB/);
  assert.throws(() => imageUploadType(file("a.jpg", "image/jpeg", 20 * 1024 * 1024 + 1)), /สูงสุด 20 MB/);
  const sql = read("../../supabase/migrations_web_beta1_storage_upload_limits.sql");
  assert.match(sql, /when 'avatars' then 10485760 else 20971520/);
});

test("every web upload path goes through the validator", () => {
  for (const path of ["../lib/phase3-data.ts", "../lib/drop-publication.ts", "../lib/drafts.ts",
    "../components/club-detail-golden.tsx", "../components/clubs-routes.tsx"]) {
    const source = read(path);
    const uploads = source.match(/\.upload\(/g)?.length ?? 0;
    const checks = source.match(/imageUploadType\(/g)?.length ?? 0;
    assert.ok(uploads > 0 && checks >= uploads, `${path}: ${uploads} uploads, ${checks} checks`);
  }
});
