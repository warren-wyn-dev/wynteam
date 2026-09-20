// WYN-181: regenerates the static iOS launch-image PNGs under
// web/public/splash/ from web/public/wynos_logo_mark.png, plus prints the
// matching `startupImage` array for web/app/layout.tsx's `metadata.appleWebApp`.
//
// Run from the web/ directory with: node tools/wyn181_generate_ios_splash_screens.mjs
// (needs `sharp`, already a dependency here — this lives under web/, not the
// repo-root tools/, specifically so plain `node` resolves it via web/node_modules).
//
// Re-run this whenever the device list needs updating (new iPhone/iPad
// screen sizes) or the logo mark changes — do not hand-edit the PNGs or the
// layout.tsx array separately, they'll drift.
import sharp from "sharp";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const WEB_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT_DIR = path.join(WEB_ROOT, "public/splash");
const LOGO = path.join(WEB_ROOT, "public/wynos_logo_mark.png");

fs.mkdirSync(OUT_DIR, { recursive: true });

// wynos_logo_mark.png is black ink on a genuinely transparent background —
// for the dark splash screens the same mark needs to be white, not a boxed
// app icon (icon-512.png has an opaque white square baked in and would show
// as an ugly white tile on a black splash).
const logoWhiteBuffer = await sharp(LOGO).negate({ alpha: false }).png().toBuffer();

// Portrait device sizes (CSS px) + device pixel ratio, covering iPhone X-and-later
// and current iPad lines. Landscape is intentionally skipped — the orientation
// a PWA install is essentially always launched in, not worth doubling the
// asset count for a case that's essentially never seen.
const devices = [
  // iPhone
  { name: "iphone-16-pro-max", w: 440, h: 956, dpr: 3 },
  { name: "iphone-16-pro", w: 402, h: 874, dpr: 3 },
  { name: "iphone-15-pro-max-14-pro-max", w: 430, h: 932, dpr: 3 },
  { name: "iphone-15-pro-14-pro", w: 393, h: 852, dpr: 3 },
  { name: "iphone-15-plus-14-plus-13-pro-max-12-pro-max", w: 428, h: 926, dpr: 3 },
  { name: "iphone-15-14-13-13-pro-12-12-pro", w: 390, h: 844, dpr: 3 },
  { name: "iphone-13-mini-12-mini-11-pro-xs-x", w: 375, h: 812, dpr: 3 },
  { name: "iphone-11-pro-max-xs-max", w: 414, h: 896, dpr: 3 },
  { name: "iphone-11-xr", w: 414, h: 896, dpr: 2 },
  { name: "iphone-8-plus-7-plus-6s-plus", w: 414, h: 736, dpr: 3 },
  { name: "iphone-8-7-6s-se3-se2", w: 375, h: 667, dpr: 2 },
  { name: "iphone-se1-5s", w: 320, h: 568, dpr: 2 },
  // iPad
  { name: "ipad-pro-12-9", w: 1024, h: 1366, dpr: 2 },
  { name: "ipad-pro-11-ipad-air-10-9", w: 834, h: 1194, dpr: 2 },
  { name: "ipad-10-2", w: 810, h: 1080, dpr: 2 },
  { name: "ipad-mini-8-3", w: 744, h: 1133, dpr: 2 },
];

const themes = [
  { key: "light", bg: { r: 255, g: 255, b: 255, alpha: 1 } },
  { key: "dark", bg: { r: 0, g: 0, b: 0, alpha: 1 } },
];

async function renderOne(pxW, pxH, bg, logoSource, outPath) {
  const logoWidth = Math.round(Math.min(pxW, pxH) * 0.42);
  const logo = await sharp(logoSource).resize(logoWidth, null, { fit: "contain" }).toBuffer();
  await sharp({ create: { width: pxW, height: pxH, channels: 4, background: bg } })
    .composite([{ input: logo, gravity: "center" }])
    .png()
    .toFile(outPath);
}

const manifest = [];

for (const device of devices) {
  const cssW = device.w;
  const cssH = device.h;
  const pxW = cssW * device.dpr;
  const pxH = cssH * device.dpr;
  for (const theme of themes) {
    const fileName = `${device.name}-portrait-${theme.key}.png`;
    const outPath = path.join(OUT_DIR, fileName);
    const logoSource = theme.key === "dark" ? logoWhiteBuffer : LOGO;
    await renderOne(pxW, pxH, theme.bg, logoSource, outPath);
    manifest.push({
      url: `/splash/${fileName}`,
      media: `screen and (device-width: ${cssW}px) and (device-height: ${cssH}px) and (-webkit-device-pixel-ratio: ${device.dpr}) and (orientation: portrait) and (prefers-color-scheme: ${theme.key})`,
    });
    process.stdout.write(".");
  }
}
console.log(`\ngenerated ${manifest.length} images in ${OUT_DIR}`);

console.log("\n--- paste into layout.tsx's APPLE_STARTUP_IMAGES array ---\n");
for (const m of manifest) {
  console.log(`    { url: ${JSON.stringify(m.url)}, media: ${JSON.stringify(m.media)} },`);
}
