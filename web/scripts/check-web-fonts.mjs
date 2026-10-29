import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const merchantRoot = "public/merchant-flutter";

/** Retains the system-text-font policy; only Flutter's generated icon glyphs qualify. */
export function checkWebFontPolicy(root) {
  const errors = [];
  const reviewedIcons = new Set();
  const buildDirectories = [merchantRoot];
  const buildsPath = path.join(root, merchantRoot, "builds");
  if (existsSync(buildsPath)) {
    for (const entry of readdirSync(buildsPath, { withFileTypes: true })) {
      if (entry.isDirectory() && /^[a-f0-9]{20}$/.test(entry.name)) {
        buildDirectories.push(path.posix.join(merchantRoot, "builds", entry.name));
      }
    }
  }
  for (const directory of buildDirectories) {
    const manifestPath = path.join(root, directory, "assets/FontManifest.json");
    if (!existsSync(manifestPath)) continue;
    try {
      const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
      const reviewedIcon = Array.isArray(manifest) && manifest.length === 1 &&
        manifest[0]?.family === "MaterialIcons" &&
        Array.isArray(manifest[0].fonts) && manifest[0].fonts.length === 1 &&
        manifest[0].fonts[0]?.asset === "fonts/MaterialIcons-Regular.otf";
      if (reviewedIcon) reviewedIcons.add(path.posix.join(directory, "assets/fonts/MaterialIcons-Regular.otf"));
      else errors.push("Flutter Merchant may declare only the generated MaterialIcons family, not text fonts.");
    } catch { errors.push("Flutter Merchant font manifest is invalid."); }
  }
  function walk(directory) {
    const absolute = path.join(root, directory);
    if (!existsSync(absolute)) return;
    for (const entry of readdirSync(absolute, { withFileTypes: true })) {
      const relative = path.posix.join(directory, entry.name);
      if (entry.isSymbolicLink()) { errors.push(`Source font scan does not follow symbolic links: ${relative}`); continue; }
      if (entry.isDirectory()) { walk(relative); continue; }
      if (/\.(?:ttf|otf|woff2?)$/i.test(entry.name)) {
        const isGeneratedIcon = reviewedIcons.has(relative) &&
          readFileSync(path.join(root, relative)).subarray(0, 4).toString("ascii") === "OTTO";
        if (!isGeneratedIcon) errors.push(`Consumer web must use system text fonts: ${relative}`);
      }
      if (/\.css$/i.test(entry.name) && /^(?:app|components|public)\//.test(relative) &&
          /@font-face/i.test(readFileSync(path.join(root, relative), "utf8"))) {
        errors.push(`Consumer web must not self-host CSS fonts: ${relative}`);
      }
    }
  }
  for (const directory of ["app", "components", "lib", "public"]) walk(directory);
  return errors;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const errors = checkWebFontPolicy(process.cwd());
  if (errors.length) { console.error(errors.join("\n")); process.exitCode = 1; }
  else console.log("PASS web system-text-font policy (generated MaterialIcons glyphs only)");
}
