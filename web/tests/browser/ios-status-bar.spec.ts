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

test("installed iOS keeps non-profile headers crisp but leaves the profile cover full-bleed", async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperties(navigator, {
      standalone: { configurable: true, value: true },
      userAgent: { configurable: true, value: "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148" },
    });
  });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  await expect.poll(() => page.evaluate(() =>
    document.documentElement.classList.contains("wyn-ios-standalone"),
  )).toBe(true);
  const strip = page.locator(".wyn-ios-status-fill");
  await expect(strip).toHaveCSS("display", "block");
  await expect(strip).toHaveCSS("background-color", "rgb(16, 17, 20)");
  await page.evaluate(() => {
    const header = document.createElement("header");
    header.className = "route-header";
    document.body.append(header);
    const chat = document.createElement("section");
    chat.className = "wyn-chat-inbox";
    chat.innerHTML = '<header class="flutter-chat-header"></header>';
    document.body.append(chat);
  });
  await expect(page.locator(".route-header")).toHaveCSS("backdrop-filter", "none");
  await expect(page.locator(".route-header")).toHaveCSS("background-color", "rgb(255, 255, 255)");
  await expect(page.locator(".wyn-chat-inbox .flutter-chat-header")).toHaveCSS("backdrop-filter", "none");
  await expect(page.locator(".wyn-chat-inbox .flutter-chat-header")).toHaveCSS("background-color", "rgb(255, 255, 255)");

  await page.evaluate(() => document.documentElement.classList.add("wyn-status-cover-route"));
  await expect(strip).toHaveCSS("display", "none");
  await page.evaluate(() => document.documentElement.classList.remove("wyn-status-cover-route"));
  await expect(strip).toHaveCSS("display", "block");
});

test("Profile's black-translucent cover metadata and existing cover geometry survive the status fix", () => {
  const read = (name: string) => readFileSync(path.join(process.cwd(), name), "utf8");
  const layout = read("app/layout.tsx");
  const css = read("app/profile-web-beta1.css");
  const runtime = read("components/app-navigation-runtime.tsx");
  expect(layout).toContain('statusBarStyle:"black-translucent"');
  expect(css).toContain("height: calc(clamp(150px, 38vw, 210px) + env(safe-area-inset-top, 0px))");
  expect(css).toContain("body:not(:has(.wyn-profile-beta1)) > .wyn-ios-status-fill");
  expect(css).toContain("html:not(.wyn-status-cover-route)");
  expect(runtime).toContain('classList.toggle("wyn-status-cover-route", coverRoute)');
});
