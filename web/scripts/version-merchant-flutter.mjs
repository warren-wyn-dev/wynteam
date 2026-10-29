import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const marker = "__MERCHANT_FLUTTER_ASSET_BASE__";
const mutableFiles = new Set(["index.html", "flutter_bootstrap.js", "build-version.json"]);

/** Only content-addressed payloads receive immutable browser caching. */
export function versionMerchantFlutter(outputDirectory) {
  const bootstrapPath = path.join(outputDirectory, "flutter_bootstrap.js");
  const bootstrap = readFileSync(bootstrapPath, "utf8");
  if (bootstrap.split(marker).length !== 2) throw new Error("Flutter bootstrap must contain one asset-base marker.");
  if (!existsSync(path.join(outputDirectory, "main.dart.js")) ||
      !existsSync(path.join(outputDirectory, "canvaskit", "canvaskit.js"))) {
    throw new Error("Flutter entrypoint and same-origin CanvasKit must exist before versioning.");
  }
  if (existsSync(path.join(outputDirectory, "builds"))) throw new Error("Flutter output is already versioned; rebuild it first.");

  const digest = createHash("sha256");
  function hashTree(directory, prefix = "") {
    for (const entry of readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name, "en"))) {
      if (!prefix && mutableFiles.has(entry.name)) continue;
      const relative = path.posix.join(prefix, entry.name);
      const absolute = path.join(directory, entry.name);
      if (entry.isSymbolicLink()) throw new Error("Flutter output must not contain symbolic links.");
      if (entry.isDirectory()) { hashTree(absolute, relative); continue; }
      if (!entry.isFile()) throw new Error("Flutter output must contain regular files only.");
      const content = readFileSync(absolute);
      digest.update(`${relative}\0${content.length}\0`);
      digest.update(content);
    }
  }
  hashTree(outputDirectory);
  const version = digest.digest("hex").slice(0, 20);
  const assetBase = `/merchant-flutter/builds/${version}/`;
  const versionDirectory = path.join(outputDirectory, "builds", version);
  const payload = readdirSync(outputDirectory).filter((name) => !mutableFiles.has(name));
  mkdirSync(versionDirectory, { recursive: true });
  for (const name of payload) renameSync(path.join(outputDirectory, name), path.join(versionDirectory, name));
  writeFileSync(bootstrapPath, bootstrap.replace(marker, assetBase));
  writeFileSync(path.join(outputDirectory, "build-version.json"), `${JSON.stringify({ assetBase })}\n`);
  return { version, assetBase };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const outputDirectory = process.argv[2] ?? path.resolve("public/merchant-flutter");
  const { assetBase } = versionMerchantFlutter(outputDirectory);
  console.log(`Versioned Merchant Flutter assets: ${assetBase}`);
}
