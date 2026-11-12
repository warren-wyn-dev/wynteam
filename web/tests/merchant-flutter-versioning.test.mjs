import assert from "node:assert/strict";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import ts from "typescript";
import { createRequire } from "node:module";
import { versionMerchantFlutter } from "../scripts/version-merchant-flutter.mjs";

function fixture(t, entrypoint = "compiled-app") {
  const directory = mkdtempSync(path.join(os.tmpdir(), "merchant-version-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const write = (relative, content) => {
    const target = path.join(directory, relative);
    mkdirSync(path.dirname(target), { recursive: true });
    writeFileSync(target, content);
  };
  write("index.html", "stable-entry");
  write("flutter_bootstrap.js", '_flutter.merchantAssetBase = "__MERCHANT_FLUTTER_ASSET_BASE__";_flutter.merchantCanvasKitBase = "__MERCHANT_FLUTTER_CANVASKIT_BASE__";');
  write("main.dart.js", entrypoint);
  write("canvaskit/canvaskit.js", "engine-loader");
  write("canvaskit/canvaskit.wasm", "engine-wasm");
  write("assets/images/logo.png", "logo-png");
  return { directory, write };
}

test("all compiled payload files move together, while stable bootstrap and HTML discover the build", (t) => {
  const f = fixture(t);
  const { version, assetBase, canvasKitBase } = versionMerchantFlutter(f.directory);
  assert.match(version, /^[a-f0-9]{20}$/);
  assert.equal(assetBase, `/merchant-flutter/builds/${version}/`);
  assert.match(canvasKitBase, /^\/merchant-flutter\/builds\/[a-f0-9]{20}\/canvaskit\/$/);
  assert.notEqual(canvasKitBase, `${assetBase}canvaskit/`);
  assert.equal(readFileSync(path.join(f.directory, "index.html"), "utf8"), "stable-entry");
  assert.equal(readFileSync(path.join(f.directory, "flutter_bootstrap.js"), "utf8"), `_flutter.merchantAssetBase = "${assetBase}";_flutter.merchantCanvasKitBase = "${canvasKitBase}";`);
  assert.deepEqual(JSON.parse(readFileSync(path.join(f.directory, "build-version.json"), "utf8")), { assetBase, canvasKitBase });
  for (const relative of ["main.dart.js", "assets/images/logo.png"]) {
    assert.ok(existsSync(path.join(f.directory, "builds", version, relative)));
    assert.equal(existsSync(path.join(f.directory, relative)), false);
  }
  const engine = path.join(f.directory, canvasKitBase.replace("/merchant-flutter/", ""));
  for (const file of ["canvaskit.js", "canvaskit.wasm"]) assert.ok(existsSync(path.join(engine, file)));
  assert.equal(existsSync(path.join(f.directory, "canvaskit")), false);
  assert.equal(existsSync(path.join(f.directory, "builds", version, "canvaskit")), false);
});
test("payload changes get a new cache key and identical payloads keep their key", (t) => {
  const a = fixture(t), b = fixture(t), changedApp = fixture(t, "updated-app"), changedEngine = fixture(t), changedImage = fixture(t);
  changedEngine.write("canvaskit/canvaskit.wasm", "updated-engine");
  changedImage.write("assets/images/logo.png", "updated-image");
  const first = versionMerchantFlutter(a.directory);
  const same = versionMerchantFlutter(b.directory);
  assert.equal(same.version, first.version);
  assert.equal(same.canvasKitBase, first.canvasKitBase);
  for (const changed of [changedApp, changedEngine, changedImage]) assert.notEqual(versionMerchantFlutter(changed.directory).version, first.version);
});
test("an app-only release keeps the engine cache key (Founder 2026-11-01)", (t) => {
  const before = versionMerchantFlutter(fixture(t).directory);
  const after = versionMerchantFlutter(fixture(t, "next-release").directory);
  assert.notEqual(after.version, before.version);
  assert.equal(after.canvasKitBase, before.canvasKitBase);
  const changedEngine = fixture(t);
  changedEngine.write("canvaskit/canvaskit.wasm", "updated-engine");
  assert.notEqual(versionMerchantFlutter(changedEngine.directory).canvasKitBase, before.canvasKitBase);
});
test("packaging fails closed for a missing build marker or unsafe filesystem entries", (t) => {
  const noMarker = fixture(t);
  noMarker.write("flutter_bootstrap.js", "unreviewed bootstrap");
  assert.throws(() => versionMerchantFlutter(noMarker.directory), /one asset-base marker/);
  const noEngineMarker = fixture(t);
  noEngineMarker.write("flutter_bootstrap.js", '_flutter.merchantAssetBase = "__MERCHANT_FLUTTER_ASSET_BASE__";');
  assert.throws(() => versionMerchantFlutter(noEngineMarker.directory), /one CanvasKit-base marker/);
  const symlink = fixture(t);
  symlinkSync("main.dart.js", path.join(symlink.directory, "link.js"));
  assert.throws(() => versionMerchantFlutter(symlink.directory), /symbolic links/);
});
function config(assetBase, canvasKitBase) {
  const source = readFileSync(new URL("../next.config.ts", import.meta.url), "utf8");
  const output = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, esModuleInterop: true } }).outputText;
  const exports = {};
  const require = createRequire(import.meta.url);
  new Function("exports", "process", "require", output)(exports, { env: {}, cwd: () => "/fixture" }, (name) => {
    if (name === "node:fs") return { readFileSync() {
      if (assetBase === undefined) throw new Error("No generated build");
      return JSON.stringify({ assetBase, canvasKitBase });
    } };
    assert.equal(name, "node:path");
    return require(name);
  });
  return exports.default;
}
test("only hashed payload URLs use immutable caching, preserving mutable bootstrap and existing hardening", async () => {
  const headers = await config().headers();
  const stable = headers.find((rule) => rule.source === "/merchant-flutter/:path*");
  const versioned = headers.find((rule) => rule.source === "/merchant-flutter/builds/:version([a-f0-9]{20})/:path*");
  assert.deepEqual(stable.headers, [{ key: "Cache-Control", value: "public, max-age=0, must-revalidate" }]);
  assert.deepEqual(versioned.headers, [{ key: "Cache-Control", value: "public, max-age=31536000, immutable" }]);
  assert.ok(headers.indexOf(versioned) > headers.indexOf(stable));
  assert.ok(headers.find((rule) => rule.source === "/:path*").headers.some((header) => header.key === "X-Frame-Options" && header.value === "DENY"));
});
test("fixed old-wrapper asset URLs resolve only known payloads to the current same-origin build", async () => {
  const assetBase = "/merchant-flutter/builds/0123456789abcdefabcd/";
  const rules = (await config(assetBase).rewrites()).afterFiles.filter((rule) => rule.source.startsWith("/merchant-flutter/"));
  assert.equal(rules.find((rule) => rule.source === "/merchant-flutter/main.dart.js").destination, `${assetBase}main.dart.js`);
  assert.equal(rules.find((rule) => rule.source === "/merchant-flutter/canvaskit/:path*").destination, `${assetBase}canvaskit/:path*`);
  const engine = "/merchant-flutter/builds/fedcba9876543210fedc/canvaskit/";
  const split = (await config(assetBase, engine).rewrites()).afterFiles;
  assert.equal(split.find((rule) => rule.source === "/merchant-flutter/canvaskit/:path*").destination, `${engine}:path*`);
  for (const untrusted of ["https://outside.example/", "/merchant-flutter/builds/../canvaskit/", "/merchant-flutter/canvaskit/"]) {
    const rules2 = (await config(assetBase, untrusted).rewrites()).afterFiles;
    assert.equal(rules2.find((rule) => rule.source === "/merchant-flutter/canvaskit/:path*").destination, `${assetBase}canvaskit/:path*`);
  }
  assert.equal(rules.find((rule) => rule.source === "/merchant-flutter/assets/:path*").destination, `${assetBase}assets/:path*`);
  assert.ok(rules.every((rule) => rule.destination.startsWith(assetBase)));
  assert.ok(rules.every((rule) => !/builds|bootstrap|index|build-version/.test(rule.source)));
});
test("absent or untrusted build metadata cannot create external or looping legacy rewrites", async () => {
  for (const assetBase of [undefined, "https://outside.example/", "/merchant-flutter/", "/merchant-flutter/builds/not-a-hash/", "/merchant-flutter/builds/../", 123]) {
    const rules = (await config(assetBase).rewrites()).afterFiles;
    assert.equal(rules.some((rule) => rule.source.startsWith("/merchant-flutter/")), false);
  }
});
