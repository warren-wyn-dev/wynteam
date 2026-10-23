import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
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
