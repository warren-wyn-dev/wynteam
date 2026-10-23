import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const iconAsset = "public/merchant-flutter/assets/fonts/MaterialIcons-Regular.otf";
const iconManifest = "public/merchant-flutter/assets/FontManifest.json";

/** Retains the system-text-font policy; only Flutter's generated icon glyphs qualify. */
export function checkWebFontPolicy(root) {
  const errors = [];
  let reviewedIcon = false;
  const manifestPath = path.join(root, iconManifest);
  if (existsSync(manifestPath)) {
    try {
      const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
      reviewedIcon = Array.isArray(manifest) && manifest.length === 1 &&
        manifest[0]?.family === "MaterialIcons" &&
        Array.isArray(manifest[0].fonts) && manifest[0].fonts.length === 1 &&
        manifest[0].fonts[0]?.asset === "fonts/MaterialIcons-Regular.otf";
      if (!reviewedIcon) errors.push("Flutter Merchant may declare only the generated MaterialIcons family, not text fonts.");
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
        const isGeneratedIcon = relative === iconAsset && reviewedIcon &&
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
