import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
function load() {
  const out = ts.transpileModule(read("../lib/android-asset-links.ts"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const mod = { exports: {} };
  runInNewContext(out, { module: mod, exports: mod.exports });
  // Values built inside the vm context carry its Array prototype; round-trip
  // through JSON so deepEqual compares plain data from this realm.
  const plain = (fn) => (...args) => JSON.parse(JSON.stringify(fn(...args)));
  return { ...mod.exports, assetLinks: plain(mod.exports.assetLinks), parseFingerprints: plain(mod.exports.parseFingerprints) };
}

const A = Array.from({ length: 32 }, () => "AB").join(":");
const B = Array.from({ length: 32 }, (_, i) => i.toString(16).padStart(2, "0")).join(":");

test("no fingerprint configured trusts no app", () => {
  const { assetLinks } = load();
  for (const raw of [undefined, "", " , ", "not-a-fingerprint"]) assert.deepEqual(assetLinks(raw), [], String(raw));
});

test("valid fingerprints are normalised, de-duplicated and bound to the WYNOS package", () => {
  const { assetLinks, ANDROID_PACKAGE_NAME } = load();
  const [statement, ...rest] = assetLinks(` ${A}, ${B} ,${A.toLowerCase()}`);
  assert.equal(rest.length, 0);
  assert.deepEqual(statement, {
    relation: ["delegate_permission/common.handle_all_urls"],
    target: { namespace: "android_app", package_name: ANDROID_PACKAGE_NAME, sha256_cert_fingerprints: [A, B.toUpperCase()] },
  });
});

test("malformed entries never reach the statement", () => {
  const { parseFingerprints } = load();
  assert.deepEqual(parseFingerprints(`${A}:CD,${A.replace(/:/g, "")},ZZ${A.slice(2)},${A}`), [A]);
});

test("package name matches the Android app", () => {
  const { ANDROID_PACKAGE_NAME } = load();
  assert.match(read("../../android/app/build.gradle.kts"), new RegExp(`applicationId = "${ANDROID_PACKAGE_NAME.replace(/\./g, "\\.")}"`));
});
