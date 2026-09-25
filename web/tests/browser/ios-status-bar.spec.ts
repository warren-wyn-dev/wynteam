import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("installed iOS Home paints an opaque status-area fill without blur", async ({ page }) => {
  // In CI the browser is not really installed, so emulate iOS's alternate
  // standalone signal before the app runtime mounts.
  await page.addInitScript(() => {
    Object.defineProperty(navigator, "standalone", { configurable: true, value: true });
  });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  await expect.poll(() => page.evaluate(() =>
    document.documentElement.classList.contains("wyn-pwa-standalone"),
  )).toBe(true);

  const strip = page.locator(".wyn-ios-status-fill");
  await expect(strip).toHaveCSS("display", "block");
  await expect(strip).toHaveCSS("position", "fixed");
  await expect(strip).toHaveCSS("background-color", "rgb(16, 17, 20)");
  await expect(strip).toHaveCSS("backdrop-filter", "none");
  await expect(strip).toHaveCSS("pointer-events", "none");

  // Profile must retain the original edge-to-edge cover under the iOS
  // black-translucent status bar; it does not inherit Home's opaque fill.
  await page.evaluate(() => {
    const profile = document.createElement("section");
    profile.className = "wyn-profile-beta1";
    document.body.appendChild(profile);
  });
  await expect(strip).toHaveCSS("display", "none");
});

test("status-area workaround keeps iOS profile and other mobile layouts unchanged", () => {
  const file = (name: string) => readFileSync(path.join(process.cwd(), name), "utf8");
  const css = file("app/profile-web-beta1.css");
  const layout = file("app/layout.tsx");
  const runtime = file("components/app-navigation-runtime.tsx");

  expect(layout).toContain('className="wyn-ios-status-fill"');
  expect(layout).toContain('statusBarStyle:"black-translucent"');
  expect(css).toContain("body:not(:has(.wyn-profile-beta1)) > .wyn-ios-status-fill");
  expect(css).toContain("height: env(safe-area-inset-top, 0px)");
  expect(css).toContain(".wyn-profile-beta1 .wyn-profile-cover");
  expect(css).not.toContain("body:not(:has(.wyn-profile-beta1))::before");
  expect(runtime).toContain('classList.toggle("wyn-pwa-standalone", mode.matches || iosInstalled)');
});
