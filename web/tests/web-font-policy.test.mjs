import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { checkWebFontPolicy } from "../scripts/check-web-fonts.mjs";

function fixture(t) {
  const root = mkdtempSync(path.join(os.tmpdir(), "merchant-fonts-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  return { root, write(relative, value) { const target = path.join(root, relative); mkdirSync(path.dirname(target), { recursive: true }); writeFileSync(target, value); } };
}
const asset = "public/merchant-flutter/assets/fonts/MaterialIcons-Regular.otf";
const manifest = "public/merchant-flutter/assets/FontManifest.json";
const icons = [{ family: "MaterialIcons", fonts: [{ asset: "fonts/MaterialIcons-Regular.otf" }] }];

test("the compiler's icon-only manifest and exact generated OTF are allowed", (t) => {
  const f = fixture(t); f.write(asset, "OTTO-icon-data"); f.write(manifest, JSON.stringify(icons));
  assert.deepEqual(checkWebFontPolicy(f.root), []);
});
test("a content-addressed Flutter build permits only its independently reviewed icon manifest", (t) => {
  const f = fixture(t);
  const versioned = "public/merchant-flutter/builds/0123456789abcdefabcd/assets";
  f.write(`${versioned}/fonts/MaterialIcons-Regular.otf`, "OTTO-icon-data");
  f.write(`${versioned}/FontManifest.json`, JSON.stringify(icons));
  assert.deepEqual(checkWebFontPolicy(f.root), []);
  f.write(`${versioned}/fonts/unapproved.ttf`, "text-font");
  assert.ok(checkWebFontPolicy(f.root).some((error) => error.includes("unapproved.ttf")));
});
test("a fixed or malformed build directory does not qualify for the versioned icon exception", (t) => {
  const f = fixture(t);
  const unversioned = "public/merchant-flutter/builds/current/assets";
  f.write(`${unversioned}/fonts/MaterialIcons-Regular.otf`, "OTTO-icon-data");
  f.write(`${unversioned}/FontManifest.json`, JSON.stringify(icons));
  assert.ok(checkWebFontPolicy(f.root).some((error) => error.includes("system text fonts")));
});
test("text fonts remain rejected everywhere the original guard checked", (t) => {
  const f = fixture(t);
  for (const directory of ["app", "components", "lib", "public"]) f.write(`${directory}/custom.woff2`, "font");
  assert.equal(checkWebFontPolicy(f.root).length, 4);
});
test("renaming an arbitrary font to the icon path without its manifest is rejected", (t) => {
  const f = fixture(t); f.write(asset, "OTTO-textfont"); assert.equal(checkWebFontPolicy(f.root).length, 1);
});
test("an additional text family in the compiler manifest is rejected", (t) => {
  const f = fixture(t); f.write(asset, "OTTO-icon-data"); f.write(manifest, JSON.stringify([...icons, { family: "NotoSansThai", fonts: [{ asset: "fonts/thai.ttf" }] }]));
  assert.ok(checkWebFontPolicy(f.root).some((e) => e.includes("only the generated MaterialIcons")));
});
test("CSS self-hosted font declarations remain forbidden", (t) => {
  const f = fixture(t); f.write("public/styles.css", '@font-face { font-family: "custom"; }');
  assert.ok(checkWebFontPolicy(f.root).some((e) => e.includes("self-host CSS")));
});

// Founder 2026-11-01: the Flutter Merchant may bundle the reviewed NotoSansThai files only.
const thaiFiles = { "NotoSansThai-Regular.ttf": undefined, "NotoSansThai-Medium.ttf": 500, "NotoSansThai-SemiBold.ttf": 600, "NotoSansThai-Bold.ttf": 700 };
const thaiFamily = { family: "NotoSansThai", fonts: Object.entries(thaiFiles).map(([file, weight]) => weight ? { asset: `assets/fonts/${file}`, weight } : { asset: `assets/fonts/${file}` }) };
function writeThai(f, base, tamper) {
  for (const file of Object.keys(thaiFiles)) {
    const bytes = readFileSync(new URL(`../merchant_flutter/assets/fonts/${file}`, import.meta.url));
    f.write(`${base}/assets/assets/fonts/${file}`, tamper === file ? Buffer.concat([bytes, Buffer.from("x")]) : bytes);
  }
}
test("the approved Merchant Thai family passes only with its exact reviewed files", (t) => {
  const f = fixture(t);
  const base = "public/merchant-flutter/builds/0123456789abcdefabcd";
  f.write(`${base}/assets/fonts/MaterialIcons-Regular.otf`, "OTTO-icon-data");
  f.write(`${base}/assets/FontManifest.json`, JSON.stringify([...icons, thaiFamily]));
  writeThai(f, base);
  assert.deepEqual(checkWebFontPolicy(f.root), []);
  writeThai(f, base, "NotoSansThai-Bold.ttf");
  assert.ok(checkWebFontPolicy(f.root).some((e) => e.includes("NotoSansThai-Bold.ttf")));
});
test("the Thai files are rejected without the approved manifest entry or outside the Merchant build", (t) => {
  const f = fixture(t);
  const base = "public/merchant-flutter/builds/0123456789abcdefabcd";
  f.write(`${base}/assets/fonts/MaterialIcons-Regular.otf`, "OTTO-icon-data");
  f.write(`${base}/assets/FontManifest.json`, JSON.stringify(icons));
  writeThai(f, base);
  assert.equal(checkWebFontPolicy(f.root).length, 4);
  const g = fixture(t);
  writeThai(g, "public/other");
  assert.equal(checkWebFontPolicy(g.root).length, 4);
  const h = fixture(t);
  h.write(`${base}/assets/FontManifest.json`, JSON.stringify([...icons, { ...thaiFamily, fonts: [...thaiFamily.fonts, { asset: "assets/fonts/Extra.ttf" }] }]));
  assert.ok(checkWebFontPolicy(h.root).some((e) => e.includes("approved NotoSansThai")));
});
