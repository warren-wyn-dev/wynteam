import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const marker = "__MERCHANT_FLUTTER_ASSET_BASE__";
// CanvasKit comes from the Flutter SDK and rarely changes. It gets its own
// content address so a Merchant release does not re-download ~3 MB of engine
// (Founder 2026-11-01: Merchant felt slow after each update).
const canvasKitMarker = "__MERCHANT_FLUTTER_CANVASKIT_BASE__";
const mutableFiles = new Set(["index.html", "flutter_bootstrap.js", "build-version.json"]);

/** Only content-addressed payloads receive immutable browser caching. */
export function versionMerchantFlutter(outputDirectory) {
  const bootstrapPath = path.join(outputDirectory, "flutter_bootstrap.js");
  const bootstrap = readFileSync(bootstrapPath, "utf8");
  if (bootstrap.split(marker).length !== 2) throw new Error("Flutter bootstrap must contain one asset-base marker.");
  if (bootstrap.split(canvasKitMarker).length !== 2) throw new Error("Flutter bootstrap must contain one CanvasKit-base marker.");
  if (!existsSync(path.join(outputDirectory, "main.dart.js")) ||
      !existsSync(path.join(outputDirectory, "canvaskit", "canvaskit.js"))) {
    throw new Error("Flutter entrypoint and same-origin CanvasKit must exist before versioning.");
  }
  if (existsSync(path.join(outputDirectory, "builds"))) throw new Error("Flutter output is already versioned; rebuild it first.");

  function hashTree(digest, directory, prefix = "") {
    for (const entry of readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name, "en"))) {
      // The engine is already moved into builds/ under its own key.
      if (!prefix && (mutableFiles.has(entry.name) || entry.name === "builds")) continue;
      const relative = path.posix.join(prefix, entry.name);
      const absolute = path.join(directory, entry.name);
      if (entry.isSymbolicLink()) throw new Error("Flutter output must not contain symbolic links.");
      if (entry.isDirectory()) { hashTree(digest, absolute, relative); continue; }
      if (!entry.isFile()) throw new Error("Flutter output must contain regular files only.");
      const content = readFileSync(absolute);
      digest.update(`${relative}\0${content.length}\0`);
      digest.update(content);
    }
  }
  const engineDigest = createHash("sha256");
  hashTree(engineDigest, path.join(outputDirectory, "canvaskit"), "canvaskit");
  const engineVersion = engineDigest.digest("hex").slice(0, 20);
  const canvasKitBase = `/merchant-flutter/builds/${engineVersion}/canvaskit/`;
  const engineDirectory = path.join(outputDirectory, "builds", engineVersion);
  mkdirSync(engineDirectory, { recursive: true });
  renameSync(path.join(outputDirectory, "canvaskit"), path.join(engineDirectory, "canvaskit"));

  const digest = createHash("sha256");
  digest.update(`canvaskit\0${engineVersion}\0`);
  hashTree(digest, outputDirectory);
  const version = digest.digest("hex").slice(0, 20);
  if (version === engineVersion) throw new Error("Flutter app and engine payloads must not share a cache key.");
  const assetBase = `/merchant-flutter/builds/${version}/`;
  const versionDirectory = path.join(outputDirectory, "builds", version);
  const payload = readdirSync(outputDirectory).filter((name) => !mutableFiles.has(name) && name !== "builds");
  mkdirSync(versionDirectory, { recursive: true });
  for (const name of payload) renameSync(path.join(outputDirectory, name), path.join(versionDirectory, name));
  writeFileSync(bootstrapPath, bootstrap.replace(marker, assetBase).replace(canvasKitMarker, canvasKitBase));
  writeFileSync(path.join(outputDirectory, "build-version.json"), `${JSON.stringify({ assetBase, canvasKitBase })}\n`);
  return { version, assetBase, canvasKitBase };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const outputDirectory = process.argv[2] ?? path.resolve("public/merchant-flutter");
  const { assetBase } = versionMerchantFlutter(outputDirectory);
  console.log(`Versioned Merchant Flutter assets: ${assetBase}`);
}
