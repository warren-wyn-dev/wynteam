import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const compiled = ts.transpileModule(read("../lib/android-asset-links.ts"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const mod = { exports: {} };
runInNewContext(compiled, { module: mod, exports: mod.exports, Set });
const { androidAssetLinks } = mod.exports;
const key = (byte) => Array(32).fill(byte).join(":");

test("with no fingerprint the site claims no app", () => {
  assert.deepEqual([...androidAssetLinks(undefined)], []);
  assert.deepEqual([...androidAssetLinks("")], []);
  assert.deepEqual([...androidAssetLinks("not-a-fingerprint")], []);
});

test("valid fingerprints are listed once, upper case, for the Android package only", () => {
  const links = androidAssetLinks(` ${key("ab")}, ${key("AB")},${key("01")}, junk, ${key("0g")}`);
  assert.equal(links.length, 1);
  assert.deepEqual([...links[0].relation], ["delegate_permission/common.handle_all_urls"]);
  assert.equal(links[0].target.namespace, "android_app");
  assert.equal(links[0].target.package_name, "io.wyn.wyn");
  assert.deepEqual([...links[0].target.sha256_cert_fingerprints], [key("AB"), key("01")]);
});
