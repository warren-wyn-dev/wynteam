import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const merchantRoot = "public/merchant-flutter";

// Founder 2026-11-01 approved one bundled Thai text family for the Flutter
// Merchant only (startup speed). Exact assets, weights and SHA-256 are pinned;
// any other text font, or a changed file, still fails.
export const APPROVED_MERCHANT_THAI_FONTS = {
  "assets/fonts/NotoSansThai-Regular.ttf": { weight: undefined, sha256: "6c5e4ca047263ed8f07b174be2f7c396d245504ce0f77adc1d26b0978bc95426" },
  "assets/fonts/NotoSansThai-Medium.ttf": { weight: 500, sha256: "9bbdcab3b91acaa0544db897087ec92d4e2df1ccabd52d9c3f9b8bceaa9286c5" },
  "assets/fonts/NotoSansThai-SemiBold.ttf": { weight: 600, sha256: "2eb1ef5273942ee86b6547202950b3a96f8f1cb44c059616486458a203aff404" },
  "assets/fonts/NotoSansThai-Bold.ttf": { weight: 700, sha256: "fd475b89dca5b9b2ad5f294944c6c82a1641c29b0a30bc1b771227250fb826a8" },
};

function isMaterialIcons(entry) {
  return entry?.family === "MaterialIcons" && Array.isArray(entry.fonts) && entry.fonts.length === 1 &&
    entry.fonts[0]?.asset === "fonts/MaterialIcons-Regular.otf" && Object.keys(entry.fonts[0]).length === 1;
}
function isApprovedThai(entry) {
  const expected = Object.entries(APPROVED_MERCHANT_THAI_FONTS);
  return entry?.family === "NotoSansThai" && Array.isArray(entry.fonts) && entry.fonts.length === expected.length &&
    expected.every(([asset, { weight }]) => entry.fonts.some((font) => font?.asset === asset &&
      font.weight === weight && Object.keys(font).every((key) => key === "asset" || key === "weight")));
}

/** Retains the system-text-font policy; only Flutter's generated icon glyphs qualify. */
export function checkWebFontPolicy(root) {
  const errors = [];
  const reviewedIcons = new Set();
  const reviewedThai = new Map();
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
      const icons = Array.isArray(manifest) ? manifest.filter(isMaterialIcons) : [];
      const thai = Array.isArray(manifest) ? manifest.filter(isApprovedThai) : [];
      const reviewed = Array.isArray(manifest) && icons.length === 1 && thai.length <= 1 && manifest.length === icons.length + thai.length;
      if (reviewed) {
        reviewedIcons.add(path.posix.join(directory, "assets/fonts/MaterialIcons-Regular.otf"));
        if (thai.length) for (const asset of Object.keys(APPROVED_MERCHANT_THAI_FONTS)) reviewedThai.set(path.posix.join(directory, "assets", asset), APPROVED_MERCHANT_THAI_FONTS[asset].sha256);
      } else errors.push("Flutter Merchant may declare only the generated MaterialIcons family and the approved NotoSansThai text family.");
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
        const isApprovedThai = reviewedThai.has(relative) &&
          createHash("sha256").update(readFileSync(path.join(root, relative))).digest("hex") === reviewedThai.get(relative);
        if (!isGeneratedIcon && !isApprovedThai) errors.push(`Consumer web must use system text fonts: ${relative}`);
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
  else console.log("PASS web font policy (MaterialIcons glyphs and the approved Merchant NotoSansThai only)");
}
