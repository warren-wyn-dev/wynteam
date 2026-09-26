// Read-only Phase 1 production readiness checks. Safe to run from GitHub Actions.
// Never print Firebase configuration, credentials, FCM tokens or user data.
const base = new URL(process.env.WYNOS_BASE_URL || "https://wynos.online/");
if (base.protocol !== "https:") throw new Error("Production smoke target must use HTTPS");

async function checkedGet(path) {
  const url = new URL(path, base);
  if (url.origin !== base.origin) throw new Error("Asset escapes target origin: " + path);
  const response = await fetch(url, {
    redirect: "follow",
    headers: { "Cache-Control": "no-cache" },
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) throw new Error(path + " returned HTTP " + response.status);
  if (new URL(response.url).origin !== base.origin) throw new Error(path + " redirected off-site");
  return response;
}

const checks = [
  ["PWA manifest, app icons and installability", async () => {
    const manifest = await (await checkedGet("/manifest.webmanifest")).json();
    if (manifest.name !== "WYNOS" || manifest.display !== "standalone") {
      throw new Error("PWA manifest name/display mismatch");
    }
    const icons = Array.isArray(manifest.icons) ? manifest.icons : [];
    for (const size of ["192x192", "512x512"]) {
      if (!icons.some((icon) => icon.sizes?.split(/\s+/).includes(size))) {
        throw new Error("Missing manifest icon size " + size);
      }
    }
    if (!icons.some((icon) => icon.purpose?.split(/\s+/).includes("maskable"))) {
      throw new Error("Missing Android maskable icon");
    }
    for (const icon of icons) {
      const res = await checkedGet(icon.src);
      if (!res.headers.get("content-type")?.startsWith("image/")) {
        throw new Error("Icon is not an image: " + icon.src);
      }
      if ((await res.arrayBuffer()).byteLength === 0) throw new Error("Empty icon: " + icon.src);
    }
    return "standalone, 192/512px and maskable icons served";
  }],
  ["Service worker and notification click handling", async () => {
    const source = await (await checkedGet("/sw.js")).text();
    if (!source.includes('"notificationclick"') || !source.includes('"fetch"')) {
      throw new Error("Service worker does not contain required click/fetch handlers");
    }
    return "service worker served with click/fetch handlers";
  }],
  ["Web Push public configuration", async () => {
    const config = await (await checkedGet("/api/push-config")).json();
    if (config?.configured !== true) {
      throw new Error("Web Push is not configured on this deployment");
    }
    return "configured: true (configuration values intentionally omitted)";
  }],
];

let failures = 0;
for (const [label, run] of checks) {
  try {
    console.log("[PASS] " + label + ": " + await run());
  } catch (error) {
    failures++;
    console.error("[FAIL] " + label + ": " + (error instanceof Error ? error.message : "unknown error"));
  }
}
if (failures > 0) {
  console.error("Phase 1 public smoke: " + failures + " check(s) failed");
  process.exitCode = 1;
} else {
  console.log("Phase 1 public smoke: all public checks passed. Physical-device QA remains required.");
}
