import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

// Browser QA verifies the layout + meta contract. Only a physical installed
// iPhone can confirm that native iOS stops drawing its OS-level blur. iOS may
// cache status-bar-style when the Home Screen app is installed.
test("installed iPhone uses native status bar and does not add another safe-area inset to Home", async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperties(navigator, {
      standalone: { configurable: true, value: true },
      userAgent: {
        configurable: true,
        value: "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148",
      },
    });
  });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  await expect.poll(() => page.evaluate(() =>
    document.documentElement.classList.contains("wyn-ios-pwa"),
  )).toBe(true);
  await expect(page.locator(".wyn-home")).toHaveCSS("padding-top", "0px");
  await expect(page.locator(".wyn-ios-status-fill")).toHaveCount(0);

  // The profile cover retains its existing source and ordinary cover height,
  // with buttons aligned below the native system status bar.
  await page.evaluate(() => {
    const profile = document.createElement("section");
    profile.className = "wyn-profile-beta1";
    profile.innerHTML = '<div class="wyn-profile-hero"><div class="wyn-profile-cover"></div><div class="wyn-profile-topbar"></div></div>';
    document.body.appendChild(profile);
  });
  const cover = page.locator(".wyn-profile-beta1 .wyn-profile-cover");
  const height = await cover.evaluate((el) => parseFloat(getComputedStyle(el).height));
  const expectedHeight = await page.evaluate(() => Math.min(210, Math.max(150, window.innerWidth * 0.38)));
  expect(Math.abs(height - expectedHeight)).toBeLessThan(1);
  await expect(page.locator(".wyn-profile-beta1 .wyn-profile-topbar")).toHaveCSS("top", "0px");
});

test("opaque native iOS status bar replaces the old translucent overlay without altering Android safe areas", () => {
  const file = (name: string) => readFileSync(path.join(process.cwd(), name), "utf8");
  const css = file("app/profile-web-beta1.css");
  const layout = file("app/layout.tsx");
  const runtime = file("components/app-navigation-runtime.tsx");
  const manifest = file("app/manifest.ts");

  expect(layout).toContain('statusBarStyle:"default"');
  expect(layout).not.toContain('statusBarStyle:"black-translucent"');
  expect(layout).not.toContain('className="wyn-ios-status-fill"');
  expect(css).not.toContain(".wyn-ios-status-fill");
  expect(css).toContain(":root.wyn-ios-pwa .wyn-home");
  expect(css).toContain("padding-top: 0;");
  expect(css).toContain(":root:not(.wyn-ios-pwa) .wyn-home");
  expect(css).toContain("env(safe-area-inset-top, 0px)");
  expect(css).toContain(":root:not(.wyn-ios-pwa) .wyn-profile-beta1 .wyn-profile-cover");
  expect(runtime).toContain('classList.toggle("wyn-ios-pwa", isIos && (mode.matches || standalone))');
  expect(manifest).toContain('display: "standalone"');
});
